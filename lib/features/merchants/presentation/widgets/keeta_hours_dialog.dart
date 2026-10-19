import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/locale_context.dart';
import '../../../../core/platforms/platforms.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../orders/presentation/widgets/orders_dialog_shell.dart';

/// Edit Keeta's opening hours: the weekly schedule and special dates
/// (holidays, events) that override it. Resolves to true when saved.
Future<bool?> showKeetaHoursDialog(
  BuildContext context, {
  required int shopId,
}) {
  final apis = context.read<PlatformApis>();
  return showOrdersDialog<bool>(
    context,
    builder: (_) => _HoursDialog(shopId: shopId, apis: apis),
  );
}

String _t(BuildContext context, String en, String ar) =>
    context.isArabic ? ar : en;

const _days = KeetaWeekday.values;

String _dayName(BuildContext context, KeetaWeekday day) => switch (day) {
  KeetaWeekday.mon => _t(context, 'Monday', 'الاثنين'),
  KeetaWeekday.tue => _t(context, 'Tuesday', 'الثلاثاء'),
  KeetaWeekday.wed => _t(context, 'Wednesday', 'الأربعاء'),
  KeetaWeekday.thu => _t(context, 'Thursday', 'الخميس'),
  KeetaWeekday.fri => _t(context, 'Friday', 'الجمعة'),
  KeetaWeekday.sat => _t(context, 'Saturday', 'السبت'),
  KeetaWeekday.sun => _t(context, 'Sunday', 'الأحد'),
};

/// Seconds since midnight → "09:30" (86400 = "24:00").
String _clock(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

String _date(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// One editable day: open ranges, or closed all day.
class _DayHours {
  _DayHours(this.ranges);

  factory _DayHours.fromJson(Object? json) {
    final ranges = [
      for (final r in (json is List ? json : const []).whereType<Map>())
        KeetaTimeRange(
          (r['startTime'] as num?)?.toInt() ?? 0,
          (r['endTime'] as num?)?.toInt() ?? 0,
        ),
    ];
    return _DayHours(ranges.where((r) => !r.isClosed).toList());
  }

  /// Empty = closed all day.
  List<KeetaTimeRange> ranges;

  bool get open => ranges.isNotEmpty;

  List<KeetaTimeRange> get payload => open ? ranges : [KeetaTimeRange.closed];

  _DayHours copy() => _DayHours([...ranges]);
}

class _SpecialEntry {
  _SpecialEntry({required this.start, required this.end, required this.hours});

  DateTime start; // UTC midnight of the first day
  DateTime end; // UTC midnight of the last day
  _DayHours hours;
}

class _HoursDialog extends StatefulWidget {
  const _HoursDialog({required this.shopId, required this.apis});

  final int shopId;
  final PlatformApis apis;

  @override
  State<_HoursDialog> createState() => _HoursDialogState();
}

class _HoursDialogState extends State<_HoursDialog> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  int _tab = 0;
  final Map<KeetaWeekday, _DayHours> _week = {
    for (final d in _days) d: _DayHours([]),
  };
  final List<_SpecialEntry> _special = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final shop = widget.apis.keeta.shop;
      final results = await Future.wait([
        shop.businessHours(widget.shopId),
        shop.specialBusinessHours(widget.shopId),
      ]);
      final week = results[0] is Map ? results[0] as Map : const {};
      for (final day in _days) {
        _week[day] = _DayHours.fromJson(week[day.name]);
      }
      final special = results[1] is List ? results[1] as List : const [];
      for (final item in special.whereType<Map>()) {
        final start = (item['startDate'] as num?)?.toInt();
        final end = (item['endDate'] as num?)?.toInt();
        if (start == null || end == null) continue;
        _special.add(
          _SpecialEntry(
            start: DateTime.fromMillisecondsSinceEpoch(start, isUtc: true),
            end: DateTime.fromMillisecondsSinceEpoch(end, isUtc: true),
            hours: _DayHours.fromJson(item['businessHour']),
          ),
        );
      }
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '$e';
        });
      }
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final shop = widget.apis.keeta.shop;
      await shop.updateBusinessHours(
        shopId: widget.shopId,
        week: {for (final day in _days) day: _week[day]!.payload},
      );
      await shop.updateSpecialBusinessHours(
        shopId: widget.shopId,
        days: [
          for (final entry in _special)
            KeetaSpecialHours(
              startDate: DateTime.utc(
                entry.start.year,
                entry.start.month,
                entry.start.day,
              ),
              endDate: DateTime.utc(
                entry.end.year,
                entry.end.month,
                entry.end.day,
                23,
                59,
                59,
                999,
              ),
              hours: entry.hours.payload,
            ),
        ],
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e is ArgumentError ? '${e.message}' : '$e';
        });
      }
    }
  }

  Future<void> _addSpecial() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
      helpText: _t(
        context,
        'Pick the first and last day',
        'اختر أول يوم وآخر يوم',
      ),
    );
    if (picked == null) return;
    setState(() {
      _special.add(
        _SpecialEntry(
          start: DateTime.utc(
            picked.start.year,
            picked.start.month,
            picked.start.day,
          ),
          end: DateTime.utc(picked.end.year, picked.end.month, picked.end.day),
          hours: _DayHours([]), // closed all day by default
        ),
      );
      _special.sort((a, b) => a.start.compareTo(b.start));
    });
  }

  @override
  Widget build(BuildContext context) {
    return OrdersDialogShell(
      icon: Icons.schedule_rounded,
      title: _t(context, 'Opening hours', 'ساعات العمل'),
      subtitle: _t(
        context,
        'Weekly schedule and special dates on Keeta',
        'الجدول الأسبوعي والتواريخ الخاصة على كيتا',
      ),
      maxWidth: 760,
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: Text(context.commonStrings.cancel),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: _loading || _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check_rounded, size: 18),
          label: Text(_t(context, 'Save to Keeta', 'حفظ على كيتا')),
          style: dialogButtonStyle,
        ),
      ],
      child: _loading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: 0,
                      icon: const Icon(Icons.calendar_view_week_rounded),
                      label: Text(_t(context, 'Weekly', 'أسبوعي')),
                    ),
                    ButtonSegment(
                      value: 1,
                      icon: const Icon(Icons.event_busy_rounded),
                      label: Text(
                        '${_t(context, 'Special dates', 'تواريخ خاصة')} (${_special.length})',
                      ),
                    ),
                  ],
                  selected: {_tab},
                  onSelectionChanged: (s) => setState(() => _tab = s.first),
                ),
                const SizedBox(height: 14),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  alignment: Alignment.topCenter,
                  child: _tab == 0 ? _weekly(context) : _specials(context),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  alignment: Alignment.topCenter,
                  child: _error == null
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: AppTheme.coral,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _weekly(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final day in _days)
          _DayCard(
            title: _dayName(context, day),
            hours: _week[day]!,
            onChanged: () => setState(() {}),
            trailing: IconButton(
              tooltip: _t(context, 'Copy to every day', 'نسخ لكل الأيام'),
              icon: const Icon(Icons.copy_all_rounded, size: 18),
              onPressed: () => setState(() {
                for (final other in _days) {
                  _week[other] = _week[day]!.copy();
                }
              }),
            ),
          ),
      ],
    );
  }

  Widget _specials(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_special.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Text(
              _t(
                context,
                'No special dates. Add holidays or events that change the hours.',
                'لا توجد تواريخ خاصة. أضف عطلاً أو مناسبات تغيّر الساعات.',
              ),
              style: const TextStyle(color: AppTheme.textMuted),
            ),
          ),
        for (final entry in _special)
          _DayCard(
            title: entry.start == entry.end
                ? _date(entry.start)
                : '${_date(entry.start)} – ${_date(entry.end)}',
            hours: entry.hours,
            onChanged: () => setState(() {}),
            trailing: IconButton(
              tooltip: _t(context, 'Remove', 'حذف'),
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 18,
                color: AppTheme.coral,
              ),
              onPressed: () => setState(() => _special.remove(entry)),
            ),
          ),
        const SizedBox(height: 4),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(
            onPressed: _addSpecial,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(_t(context, 'Add dates', 'إضافة تواريخ')),
          ),
        ),
      ],
    );
  }
}

/// A day (or date range) with an open / closed switch and its time ranges.
class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.title,
    required this.hours,
    required this.onChanged,
    required this.trailing,
  });

  final String title;
  final _DayHours hours;
  final VoidCallback onChanged;
  final Widget trailing;

  Future<void> _pick(
    BuildContext context,
    int index, {
    required bool start,
  }) async {
    final range = hours.ranges[index];
    final seconds = start ? range.startTime : range.endTime;
    final initial = TimeOfDay(
      hour: (seconds ~/ 3600) % 24,
      minute: (seconds % 3600) ~/ 60,
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    var value = picked.hour * 3600 + picked.minute * 60;
    // An end of 00:00 means midnight at the end of the day.
    if (!start && value == 0) value = 86400;
    hours.ranges[index] = start
        ? KeetaTimeRange(value, range.endTime)
        : KeetaTimeRange(range.startTime, value);
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
      decoration: BoxDecoration(
        color: hours.open ? AppTheme.surface : AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hours.open
              ? AppTheme.border
              : AppTheme.border.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
            ),
          ),
          Switch(
            value: hours.open,
            onChanged: (open) {
              hours.ranges = open ? [const KeetaTimeRange(32400, 82800)] : [];
              onChanged();
            },
          ),
          const SizedBox(width: 6),
          Expanded(
            child: hours.open
                ? Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (var i = 0; i < hours.ranges.length; i++)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton(
                                  onPressed: () =>
                                      _pick(context, i, start: true),
                                  child: Text(
                                    _clock(hours.ranges[i].startTime),
                                    textDirection: TextDirection.ltr,
                                  ),
                                ),
                                const Text('→'),
                                TextButton(
                                  onPressed: () =>
                                      _pick(context, i, start: false),
                                  child: Text(
                                    _clock(hours.ranges[i].endTime),
                                    textDirection: TextDirection.ltr,
                                  ),
                                ),
                                if (hours.ranges.length > 1)
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 16,
                                    ),
                                    onPressed: () {
                                      hours.ranges.removeAt(i);
                                      onChanged();
                                    },
                                  ),
                              ],
                            ),
                          ),
                        IconButton(
                          tooltip: _t(
                            context,
                            'Add a time range',
                            'إضافة فترة',
                          ),
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.add_circle_outline_rounded),
                          onPressed: () {
                            final last = hours.ranges.last.endTime;
                            final start = last >= 86400 ? 0 : last;
                            hours.ranges.add(
                              KeetaTimeRange(
                                start,
                                (start + 3600).clamp(0, 86400),
                              ),
                            );
                            onChanged();
                          },
                        ),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _t(context, 'Closed all day', 'مغلق طوال اليوم'),
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ),
          ),
          trailing,
        ],
      ),
    );
  }
}
