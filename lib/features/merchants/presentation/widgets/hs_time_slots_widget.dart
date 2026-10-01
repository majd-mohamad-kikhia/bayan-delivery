import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../l10n/merchants_strings.dart';
import 'hs_dialog_widget.dart';

/// Six-hour part of the day; [block] is `hour ~/ 6`.
enum _DayPeriod {
  morning(1, Icons.wb_twilight_rounded),
  afternoon(2, Icons.wb_sunny_outlined),
  evening(3, Icons.nights_stay_outlined),
  night(0, Icons.bedtime_outlined);

  const _DayPeriod(this.block, this.icon);

  final int block;
  final IconData icon;

  int get startHour => block * 6;

  static _DayPeriod of(TimeOfDay time) =>
      values.firstWhere((p) => p.block == time.hour ~/ 6);

  String label(MerchantsStrings s) => switch (this) {
        morning => s.periodMorning,
        afternoon => s.periodAfternoon,
        evening => s.periodEvening,
        night => s.periodNight,
      };
}

/// Time-of-day picker: period tabs over a grid of [slotMinutes] slots.
/// Slots already in the past on [date] are disabled.
class HsTimeSlotsWidget extends StatefulWidget {
  const HsTimeSlotsWidget({
    super.key,
    required this.date,
    required this.selected,
    required this.onSelected,
  });

  static const int slotMinutes = 30;

  final DateTime date;
  final TimeOfDay selected;
  final ValueChanged<TimeOfDay> onSelected;

  @override
  State<HsTimeSlotsWidget> createState() => _HsTimeSlotsWidgetState();
}

class _HsTimeSlotsWidgetState extends State<HsTimeSlotsWidget> {
  static const double _spacing = 8;
  static const double _fourColumnBreakpoint = 320;

  late _DayPeriod _period = _DayPeriod.of(widget.selected);

  @override
  void didUpdateWidget(HsTimeSlotsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      _period = _DayPeriod.of(widget.selected);
    }
  }

  List<TimeOfDay> get _slots => [
        for (var m = 0; m < 6 * 60; m += HsTimeSlotsWidget.slotMinutes)
          TimeOfDay(hour: _period.startHour + m ~/ 60, minute: m % 60),
      ];

  bool _isPast(TimeOfDay t, DateTime now) {
    final d = widget.date;
    return !DateTime(d.year, d.month, d.day, t.hour, t.minute).isAfter(now);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.merchantsStrings;
    final loc = MaterialLocalizations.of(context);
    final use24h = MediaQuery.alwaysUse24HourFormatOf(context);
    final now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: _spacing,
          runSpacing: _spacing,
          children: [
            for (final period in _DayPeriod.values)
              HsPillButtonWidget(
                label: period.label(s),
                icon: period.icon,
                selected: period == _period,
                onTap: () {
                  if (period != _period) setState(() => _period = period);
                },
              ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= _fourColumnBreakpoint ? 4 : 3;
            final width = (constraints.maxWidth - _spacing * (columns - 1)) / columns;
            return Wrap(
              spacing: _spacing,
              runSpacing: _spacing,
              children: [
                for (final slot in _slots)
                  SizedBox(
                    width: width,
                    child: HsPillButtonWidget(
                      label: loc.formatTimeOfDay(slot, alwaysUse24HourFormat: use24h),
                      selected: slot == widget.selected,
                      enabled: !_isPast(slot, now),
                      centered: true,
                      onTap: () => widget.onSelected(slot),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Rounded selectable pill used for presets, day periods and time slots.
class HsPillButtonWidget extends StatelessWidget {
  const HsPillButtonWidget({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.enabled = true,
    this.centered = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final bool enabled;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(10);
    final foreground = selected
        ? Colors.white
        : enabled
            ? AppTheme.textPrimary
            : AppTheme.textMuted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: radius,
        hoverColor: hsOrange.withValues(alpha: 0.06),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? hsOrange
                : enabled
                    ? AppTheme.surfaceAlt
                    : AppTheme.background,
            borderRadius: radius,
            border: Border.all(color: selected ? hsOrange : AppTheme.border),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: hsOrange.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: centered ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: selected ? Colors.white : hsOrange),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: foreground,
                    decoration: enabled ? null : TextDecoration.lineThrough,
                    decorationColor: AppTheme.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
