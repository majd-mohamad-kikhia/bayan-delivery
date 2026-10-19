import 'package:bayan_desktop/features/orders/presentation/utils/orders_date_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 10, 15, 30);

  test('today is the default and only matches today', () {
    expect(OrdersDateFilter.today.matches(DateTime(2026, 10, 10, 0, 5), now), isTrue);
    expect(OrdersDateFilter.today.matches(DateTime(2026, 10, 10, 23, 59), now), isTrue);
    expect(OrdersDateFilter.today.matches(DateTime(2026, 10, 9, 23, 59), now), isFalse);
    expect(OrdersDateFilter.today.matches(DateTime(2026, 10, 11), now), isFalse);
  });

  test('yesterday, last 7 days and this month', () {
    const yesterday = OrdersDateFilter(OrdersDatePreset.yesterday);
    expect(yesterday.matches(DateTime(2026, 10, 9, 12), now), isTrue);
    expect(yesterday.matches(DateTime(2026, 10, 10, 12), now), isFalse);

    const week = OrdersDateFilter(OrdersDatePreset.last7Days);
    expect(week.matches(DateTime(2026, 10, 4), now), isTrue);
    expect(week.matches(DateTime(2026, 10, 3), now), isFalse);

    const month = OrdersDateFilter(OrdersDatePreset.thisMonth);
    expect(month.matches(DateTime(2026, 10, 1), now), isTrue);
    expect(month.matches(DateTime(2026, 9, 30), now), isFalse);
  });

  test('all matches everything; custom is inclusive and order-agnostic', () {
    expect(const OrdersDateFilter(OrdersDatePreset.all).matches(DateTime(2020), now), isTrue);

    final custom = OrdersDateFilter.custom(DateTime(2026, 10, 8, 18), DateTime(2026, 10, 5));
    expect(custom.matches(DateTime(2026, 10, 5, 0, 1), now), isTrue);
    expect(custom.matches(DateTime(2026, 10, 8, 23, 59), now), isTrue);
    expect(custom.matches(DateTime(2026, 10, 9), now), isFalse);
  });
}
