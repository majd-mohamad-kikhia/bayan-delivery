import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../l10n/merchants_strings.dart';
import 'hs_dialog_widget.dart';
import 'hs_time_slots_widget.dart';

/// Asks when a closed HungerStation outlet should reopen. Resolves to the
/// chosen local date-time, or null when dismissed.
Future<DateTime?> showHsCloseUntilPicker(
  BuildContext context, {
  required String reasonLabel,
}) {
  return showHsDialog<DateTime>(
    context,
    barrierLabel: context.merchantsStrings.closeUntilTitle,
    builder: (_) => _CloseUntilDialog(reasonLabel: reasonLabel),
  );
}

class _Preset {
  const _Preset(this.label, this.value);

  final String label;
  final DateTime value;
}

class _CloseUntilDialog extends StatefulWidget {
  const _CloseUntilDialog({required this.reasonLabel});

  final String reasonLabel;

  @override
  State<_CloseUntilDialog> createState() => _CloseUntilDialogState();
}

class _CloseUntilDialogState extends State<_CloseUntilDialog> {
  static const int _maxDaysAhead = 30;
  static const double _wideBreakpoint = 700;
  static const double _calendarWidth = 340;

  late final DateTime _today;
  late DateTime _date;
  late TimeOfDay _time;
  int? _activePreset;

  /// CalendarDatePicker ignores later `initialDate` changes, so a preset that
  /// moves the date rebuilds it under a new key.
  int _calendarVersion = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateUtils.dateOnly(now);
    final initial = _roundUpToSlot(now.add(const Duration(hours: 2)));
    _date = DateUtils.dateOnly(initial);
    _time = TimeOfDay.fromDateTime(initial);
  }

  static DateTime _roundUpToSlot(DateTime t) {
    final step = HsTimeSlotsWidget.slotMinutes;
    final extra = (step - t.minute % step) % step;
    return DateTime(t.year, t.month, t.day, t.hour, t.minute + extra);
  }

  DateTime get _selected =>
      DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);

  bool get _isValid => _selected.isAfter(DateTime.now());

  List<_Preset> _presets(MerchantsStrings s) {
    final now = DateTime.now();
    final base = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    final tomorrow = _today.add(const Duration(days: 1));
    return [
      _Preset(s.inMinutes(30), base.add(const Duration(minutes: 30))),
      _Preset(s.inHours(1), base.add(const Duration(hours: 1))),
      _Preset(s.inHours(2), base.add(const Duration(hours: 2))),
      _Preset(s.inHours(4), base.add(const Duration(hours: 4))),
      _Preset(s.tomorrowMorning, DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9)),
    ];
  }

  void _applyPreset(int index, DateTime value) {
    final date = DateUtils.dateOnly(value);
    setState(() {
      if (!DateUtils.isSameDay(date, _date)) _calendarVersion++;
      _date = date;
      _time = TimeOfDay.fromDateTime(value);
      _activePreset = index;
    });
  }

  void _onDateChanged(DateTime date) {
    if (DateUtils.isSameDay(date, _date)) return;
    setState(() {
      _date = date;
      _activePreset = null;
    });
  }

  void _onTimeSelected(TimeOfDay time) {
    if (time == _time && _activePreset == null) return;
    setState(() {
      _time = time;
      _activePreset = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.merchantsStrings;
    return HsDialogFrameWidget(
      maxWidth: 780,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HsDialogHeaderWidget(
            icon: Icons.event_available_outlined,
            title: s.closeUntilTitle,
            subtitle: s.closeUntilSubtitle,
            badge: widget.reasonLabel,
          ),
          const Divider(height: 1, color: AppTheme.border),
          Flexible(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: constraints.maxWidth >= _wideBreakpoint
                    ? _wideBody(context)
                    : _narrowBody(context),
              ),
            ),
          ),
          _SummaryBar(selected: _selected, isValid: _isValid),
          HsDialogFooterWidget(
            confirmLabel: s.confirmClosure,
            confirmIcon: Icons.lock_clock_outlined,
            onConfirm: _isValid ? () => Navigator.of(context).pop(_selected) : null,
          ),
        ],
      ),
    );
  }

  Widget _wideBody(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: _calendarWidth,
          decoration: const BoxDecoration(
            border: BorderDirectional(end: BorderSide(color: AppTheme.border)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: _calendar(context),
        ),
        Expanded(child: _timePanel(context)),
      ],
    );
  }

  Widget _narrowBody(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _calendarWidth),
            child: _calendar(context),
          ),
        ),
        const Divider(height: 1, color: AppTheme.border),
        _timePanel(context),
      ],
    );
  }

  Widget _calendar(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(
          primary: hsOrange,
          onPrimary: Colors.white,
        ),
      ),
      child: CalendarDatePicker(
        key: ValueKey(_calendarVersion),
        initialDate: _date,
        firstDate: _today,
        lastDate: _today.add(const Duration(days: _maxDaysAhead)),
        onDateChanged: _onDateChanged,
      ),
    );
  }

  Widget _timePanel(BuildContext context) {
    final s = context.merchantsStrings;
    final presets = _presets(s);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionLabel(icon: Icons.bolt_rounded, text: s.quickPicks),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < presets.length; i++)
                HsPillButtonWidget(
                  label: presets[i].label,
                  selected: _activePreset == i,
                  onTap: () => _applyPreset(i, presets[i].value),
                ),
            ],
          ),
          const SizedBox(height: 20),
          _SectionLabel(icon: Icons.schedule_rounded, text: s.pickTime),
          const SizedBox(height: 10),
          HsTimeSlotsWidget(
            date: _date,
            selected: _time,
            onSelected: _onTimeSelected,
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppTheme.textMuted),
        const SizedBox(width: 6),
        Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppTheme.textMuted,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.selected, required this.isValid});

  final DateTime selected;
  final bool isValid;

  @override
  Widget build(BuildContext context) {
    final s = context.merchantsStrings;
    final loc = MaterialLocalizations.of(context);
    final date = loc.formatMediumDate(selected);
    final time = loc.formatTimeOfDay(
      TimeOfDay.fromDateTime(selected),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final color = isValid ? hsOrange : AppTheme.coral;

    final remaining = selected.difference(DateTime.now());
    final totalMinutes = (remaining.inSeconds / 60).ceil();
    final detail = isValid
        ? s.reopensIn(totalMinutes ~/ 1440, (totalMinutes % 1440) ~/ 60, totalMinutes % 60)
        : s.pickFutureTime;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.lock_clock_outlined : Icons.error_outline_rounded,
            color: color,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.reopensAt(date, time),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(detail, style: TextStyle(fontSize: 12, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
