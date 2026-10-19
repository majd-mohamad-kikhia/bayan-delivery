import 'package:bayan_desktop/features/orders/presentation/utils/orders_date_filter.dart';
import 'package:bayan_desktop/features/reports/data/report_models.dart';
import 'package:bayan_desktop/features/reports/presentation/cubit/reports_cubit.dart';
import 'package:bayan_desktop/core/network/api_client.dart';
import 'package:bayan_desktop/core/storage/app_preferences.dart';
import 'package:bayan_desktop/features/reports/data/reports_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('parses the backend overview, zeros and missing values included', () {
    final overview = ReportOverview.fromJson({
      'range': {'from': '2026-10-13', 'to': '2026-10-14', 'days': 2},
      'kpis': {
        'orders': 30,
        'completed': 20,
        'cancelled': 3,
        'grossMinor': 223915,
        'discountMinor': 53185,
        'itemsSold': 148,
        'avgOrderMinor': 8293,
        'cancelRate': 0.1,
        'avgPrepSeconds': 640,
        'avgDeliverySeconds': null,
      },
      'previous': {},
      'daily': [
        {
          'date': '2026-10-13',
          'orders': 0,
          'grossMinor': 0,
          'cancelled': 0,
          'byPlatform': {},
        },
        {
          'date': '2026-10-14',
          'orders': 30,
          'grossMinor': 223915,
          'cancelled': 3,
          'byPlatform': {
            'keeta': {'orders': 19, 'grossMinor': 141772},
            'hungerstation': {'orders': 11, 'grossMinor': 82143},
          },
        },
      ],
      'platforms': [
        {'platform': 'keeta', 'orders': 19, 'grossMinor': 141772},
      ],
      'hourly': [
        {'hour': 12, 'orders': 5, 'grossMinor': 40000},
      ],
      'topProducts': [
        {'name': 'Chicken Kabsa', 'qty': 13, 'revenueMinor': 36800},
      ],
      'topAddOns': <Object>[],
      'cancelReasons': [
        {'reason': 'unspecified', 'orders': 3},
      ],
    });

    expect(overview.kpis.orders, 30);
    expect(overview.kpis.avgDeliverySeconds, isNull);
    expect(
      overview.previous.orders,
      0,
      reason: 'an empty previous period is all zeros',
    );
    expect(overview.daily, hasLength(2));
    expect(overview.daily.last.byPlatform['hungerstation'], 11);
    expect(overview.topProducts.single.revenueMinor, 36800);
    expect(overview.hourly.single.hour, 12);
  });

  test(
    'the range follows the chosen filter; "all time" is capped at a year',
    () {
      final now = DateTime(2026, 10, 14, 15, 30);

      final week = ReportsCubit.rangeOf(
        const OrdersDateFilter(OrdersDatePreset.last7Days),
        now,
      );
      expect(week.from, DateTime(2026, 10, 8));
      expect(week.to, DateTime(2026, 10, 14));

      final all = ReportsCubit.rangeOf(
        const OrdersDateFilter(OrdersDatePreset.all),
        now,
      );
      expect(all.to, DateTime(2026, 10, 14));
      expect(all.to.difference(all.from).inDays, 364);
    },
  );

  group('remembers the last choice', () {
    test('a date filter survives a JSON round trip, custom range included', () {
      final custom = OrdersDateFilter.custom(
        DateTime(2026, 10, 1),
        DateTime(2026, 10, 9),
      );
      for (final filter in [
        const OrdersDateFilter(OrdersDatePreset.today),
        custom,
      ]) {
        final back = OrdersDateFilter.fromJson(
          filter.toJson(),
          fallback: ReportsCubit.defaultFilter,
        );
        expect(back, filter);
      }
      expect(
        OrdersDateFilter.fromJson({
          'preset': 'nonsense',
        }, fallback: ReportsCubit.defaultFilter),
        ReportsCubit.defaultFilter,
      );
      expect(
        OrdersDateFilter.fromJson(null, fallback: ReportsCubit.defaultFilter),
        ReportsCubit.defaultFilter,
      );
    });

    test(
      'a new Reports page starts with what was tapped last, defaulting to 7 days',
      () async {
        SharedPreferences.setMockInitialValues({});
        final preferences = await AppPreferences.create();
        final repository = ReportsRepository(ApiClient());

        final first = ReportsCubit(repository, 'D', preferences);
        expect(first.state.filter, ReportsCubit.defaultFilter);
        expect(first.state.platform, 'all');

        // Leaving the page = closing the cubit; the choice was already saved.
        await first.setFilter(const OrdersDateFilter(OrdersDatePreset.today));
        await first.setPlatform('keeta');
        await first.close();

        final second = ReportsCubit(repository, 'D', preferences);
        addTearDown(second.close);
        expect(second.state.filter.preset, OrdersDatePreset.today);
        expect(second.state.platform, 'keeta');
      },
    );
  });
}
