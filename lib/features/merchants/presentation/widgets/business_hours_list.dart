import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/utc_clock.dart';
import '../../data/models/keeta_shop_status_model.dart';

class BusinessHoursList extends StatelessWidget {
  const BusinessHoursList({super.key, required this.weekHours});

  final List<KeetaWeekDayHours> weekHours;

  static const _dayOrder = [
    'MONDAY',
    'TUESDAY',
    'WEDNESDAY',
    'THURSDAY',
    'FRIDAY',
    'SATURDAY',
    'SUNDAY',
  ];

  @override
  Widget build(BuildContext context) {
    if (weekHours.isEmpty) {
      return const Text(
        'No weekly hours configured',
        style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
      );
    }

    final byDay = {for (final d in weekHours) d.dayOfWeek.toUpperCase(): d};

    return Column(
      children: [
        for (final day in _dayOrder)
          if (byDay.containsKey(day))
            _DayRow(day: byDay[day]!)
          else
            _DayRow(
              day: KeetaWeekDayHours(dayOfWeek: day, timePeriods: const []),
            ),
      ],
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.day});

  final KeetaWeekDayHours day;

  @override
  Widget build(BuildContext context) {
    final label = _prettyDay(day.dayOfWeek);
    final times = day.timePeriods.isEmpty
        ? 'Closed'
        : day.timePeriods
            .map(
              (p) =>
                  '${formatUtcClockLocal(p.startTime)} – ${formatUtcClockLocal(p.endTime)}',
            )
            .join(', ');

    final isToday = DateTime.now().weekday == _weekdayIndex(day.dayOfWeek);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                color: isToday ? AppTheme.primary : AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              times,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
                color: day.timePeriods.isEmpty
                    ? AppTheme.textMuted
                    : AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _prettyDay(String raw) {
    if (raw.isEmpty) return raw;
    final lower = raw.toLowerCase();
    return '${lower[0].toUpperCase()}${lower.substring(1)}';
  }

  static int _weekdayIndex(String day) {
    switch (day.toUpperCase()) {
      case 'MONDAY':
        return DateTime.monday;
      case 'TUESDAY':
        return DateTime.tuesday;
      case 'WEDNESDAY':
        return DateTime.wednesday;
      case 'THURSDAY':
        return DateTime.thursday;
      case 'FRIDAY':
        return DateTime.friday;
      case 'SATURDAY':
        return DateTime.saturday;
      case 'SUNDAY':
        return DateTime.sunday;
      default:
        return -1;
    }
  }
}
