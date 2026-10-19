import 'package:equatable/equatable.dart';

enum OrdersDatePreset { today, yesterday, last7Days, thisMonth, all, custom }

/// Which days of orders the board shows, by the day each order was created
/// (local time). Presets are relative to "now", so "Today" rolls over at
/// midnight without being re-selected.
final class OrdersDateFilter extends Equatable {
  const OrdersDateFilter(this.preset, {this.customStart, this.customEnd});

  static const today = OrdersDateFilter(OrdersDatePreset.today);

  factory OrdersDateFilter.custom(DateTime start, DateTime end) {
    final a = _day(start);
    final b = _day(end);
    return a.isAfter(b)
        ? OrdersDateFilter(
            OrdersDatePreset.custom,
            customStart: b,
            customEnd: a,
          )
        : OrdersDateFilter(
            OrdersDatePreset.custom,
            customStart: a,
            customEnd: b,
          );
  }

  /// Back from [toJson]; anything unreadable gives [fallback].
  factory OrdersDateFilter.fromJson(
    Object? json, {
    required OrdersDateFilter fallback,
  }) {
    if (json is! Map) return fallback;
    final preset = OrdersDatePreset.values
        .where((p) => p.name == json['preset'])
        .firstOrNull;
    if (preset == null) return fallback;
    if (preset != OrdersDatePreset.custom) return OrdersDateFilter(preset);
    final start = DateTime.tryParse('${json['start']}');
    final end = DateTime.tryParse('${json['end']}');
    return start == null || end == null
        ? fallback
        : OrdersDateFilter.custom(start, end);
  }

  Map<String, Object?> toJson() => {
    'preset': preset.name,
    if (preset == OrdersDatePreset.custom) ...{
      'start': customStart?.toIso8601String(),
      'end': customEnd?.toIso8601String(),
    },
  };

  final OrdersDatePreset preset;
  final DateTime? customStart;
  final DateTime? customEnd;

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Inclusive first and last day, or null for "all time".
  ({DateTime start, DateTime end})? range(DateTime now) {
    final today = _day(now);
    return switch (preset) {
      OrdersDatePreset.today => (start: today, end: today),
      OrdersDatePreset.yesterday => (
        start: DateTime(today.year, today.month, today.day - 1),
        end: DateTime(today.year, today.month, today.day - 1),
      ),
      OrdersDatePreset.last7Days => (
        start: DateTime(today.year, today.month, today.day - 6),
        end: today,
      ),
      OrdersDatePreset.thisMonth => (
        start: DateTime(today.year, today.month),
        end: today,
      ),
      OrdersDatePreset.all => null,
      OrdersDatePreset.custom => (
        start: customStart ?? today,
        end: customEnd ?? today,
      ),
    };
  }

  bool matches(DateTime createdAt, DateTime now) {
    final range = this.range(now);
    if (range == null) return true;
    final day = _day(createdAt.toLocal());
    return !day.isBefore(range.start) && !day.isAfter(range.end);
  }

  @override
  List<Object?> get props => [preset, customStart, customEnd];
}
