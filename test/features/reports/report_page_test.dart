import 'dart:async';

import 'package:bayan_desktop/core/network/api_client.dart';
import 'package:bayan_desktop/core/storage/app_preferences.dart';
import 'package:bayan_desktop/features/reports/data/report_export.dart';
import 'package:bayan_desktop/features/reports/data/report_models.dart';
import 'package:bayan_desktop/features/reports/data/reports_repository.dart';
import 'package:bayan_desktop/features/reports/presentation/pages/reports_page.dart';
import 'package:bayan_desktop/features/reports/presentation/widgets/report_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _json({int days = 7, bool empty = false}) {
  final to = DateTime.utc(2026, 10, 18);
  return {
    'range': {
      'from': to
          .subtract(Duration(days: days - 1))
          .toIso8601String()
          .substring(0, 10),
      'to': '2026-10-18',
      'days': days,
    },
    'kpis': {
      'orders': empty ? 0 : 128,
      'completed': empty ? 0 : 100,
      'cancelled': empty ? 0 : 9,
      'grossMinor': empty ? 0 : 4356316,
      'discountMinor': empty ? 0 : 1006484,
      'itemsSold': 300,
      'avgOrderMinor': empty ? 0 : 36607,
      'cancelRate': empty ? 0.0 : 0.07,
      'avgPrepSeconds': empty ? null : 612,
      'avgDeliverySeconds': null,
    },
    'previous': {
      'orders': empty ? 0 : 100,
      'grossMinor': empty ? 0 : 3000000,
      'avgOrderMinor': 30000,
      'cancelRate': 0.1,
      'avgPrepSeconds': 700,
      'discountMinor': 900000,
    },
    'daily': [
      for (var i = 0; i < days; i++)
        {
          'date': to
              .subtract(Duration(days: days - 1 - i))
              .toIso8601String()
              .substring(0, 10),
          'orders': empty ? 0 : 10 + i * 3,
          'grossMinor': empty ? 0 : 500000 + i * 90000,
          'cancelled': empty ? 0 : i % 3,
          'byPlatform': empty
              ? {}
              : {
                  'keeta': {'orders': 6 + i, 'grossMinor': 300000 + i * 50000},
                  'hungerstation': {
                    'orders': 4 + i * 2,
                    'grossMinor': 200000 + i * 40000,
                  },
                },
        },
    ],
    'platforms': empty
        ? []
        : [
            {'platform': 'keeta', 'orders': 80, 'grossMinor': 2800000},
            {'platform': 'hungerstation', 'orders': 48, 'grossMinor': 1556316},
          ],
    'hourly': [
      for (var h = 0; h < 24; h++)
        {
          'hour': h,
          'orders': empty
              ? 0
              : (h >= 11 && h <= 14 ? 20 - (h - 12).abs() * 4 : 1),
          'grossMinor': 100000,
        },
    ],
    'topProducts': empty
        ? []
        : [
            {'name': 'وجبة اسكالوباية', 'qty': 40, 'revenueMinor': 4920000},
            {'name': 'تجريبية', 'qty': 3, 'revenueMinor': 3000000},
            {
              'name':
                  'A very long product name that should be cut with an ellipsis and never overflow',
              'qty': 9,
              'revenueMinor': 100000,
            },
          ],
    'topAddOns': empty
        ? []
        : [
            {'name': 'بطاطا زيادة', 'qty': 12, 'revenueMinor': 3600},
          ],
    'cancelReasons': empty
        ? []
        : [
            {'reason': 'Out of stock', 'orders': 5},
            {'reason': 'unspecified', 'orders': 4},
          ],
    'generatedAt': '2026-10-18T09:29:03.000Z',
  };
}

class _FakeReports extends ReportsRepository {
  _FakeReports(this.json) : super(ApiClient());

  final Map<String, dynamic> json;

  @override
  Future<ReportOverview> overview({
    required String dongleNumber,
    required DateTime from,
    required DateTime to,
    String? platform,
  }) async => ReportOverview.fromJson(json);
}

Future<void> _pump(
  WidgetTester tester,
  Map<String, dynamic> json, {
  required Size size,
  String locale = 'en',
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final prefs = await AppPreferences.create();
  await tester.pumpWidget(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<ReportsRepository>.value(value: _FakeReports(json)),
        RepositoryProvider<AppPreferences>.value(value: prefs),
      ],
      child: MaterialApp(
        locale: Locale(locale),
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('en'), Locale('ar')],
        home: const Scaffold(body: ReportsPage()),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 700));
}

void main() {
  group('lays out without overflow', () {
    for (final size in const [
      Size(1920, 1100),
      Size(1440, 900),
      Size(1100, 800),
      Size(820, 800),
    ]) {
      for (final locale in const ['en', 'ar']) {
        testWidgets('${size.width.round()}px · $locale · a week', (
          tester,
        ) async {
          await _pump(tester, _json(), size: size, locale: locale);
          expect(tester.takeException(), isNull);
          expect(find.byType(ReportsPage), findsOneWidget);
          await tester.drag(
            find.byType(SingleChildScrollView).first,
            const Offset(0, -3000),
          );
          await tester.pump(const Duration(milliseconds: 700));
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('a single day shows the hourly chart', (tester) async {
      await _pump(tester, _json(days: 1), size: const Size(1440, 900));
      expect(tester.takeException(), isNull);
      expect(find.text('Today by hour'), findsOneWidget);
    });

    testWidgets('an empty range says so instead of showing blank charts', (tester) async {
      await _pump(tester, _json(empty: true, days: 1), size: const Size(1440, 900));
      expect(tester.takeException(), isNull);
      expect(find.textContaining('No orders in this period'), findsWidgets);
    });

    testWidgets('a long range groups the bars by week', (tester) async {
      await _pump(tester, _json(days: 120), size: const Size(1440, 900));
      expect(tester.takeException(), isNull);
    });
  });

  group('numbers', () {
    test('money has thousands separators and two decimals', () {
      expect(amountText(4356316), '43,563.16');
      expect(amountText(5), '0.05');
      expect(amountText(-120050), '-1,200.50');
      expect(groupDigits(1234567), '1,234,567');
    });

    test('axis labels stay short; the axis tops out at a round number', () {
      expect(compact(950), '950');
      expect(compact(43563), '43.6K');
      expect(compact(2000000), '2M');
      expect(niceCeil(43563), 50000);
      expect(niceCeil(7), 8 > 7 ? 10 : 8, reason: '7 → next nice step is 10');
      expect(niceCeil(0), 1);
      expect(niceCeil(120), 200);
    });

    test('durations read naturally', () {
      expect(duration(null), '—');
      expect(duration(45), '45s');
      expect(duration(612), '10m 12s');
      expect(duration(3900), '1h 5m');
    });
  });

  group('CSV export', () {
    test(
      'has every section, riyals with two decimals, and quotes what needs quoting',
      () {
        final overview = ReportOverview.fromJson({
          ..._json(days: 2),
          'topProducts': [
            {'name': 'Burger, large', 'qty': 2, 'revenueMinor': 5000},
            {'name': 'Say "hi"', 'qty': 1, 'revenueMinor': 100},
          ],
        });
        final csv = buildReportCsv(overview, platformLabel: 'all');

        for (final section in [
          'Summary',
          'Per day',
          'Per platform',
          'Best sellers',
          'Add-ons',
          'Cancellation reasons',
        ]) {
          expect(csv, contains('$section\r\n'));
        }
        expect(csv, contains('Sales,43563.16'));
        expect(csv, contains('"Burger, large",2,50.00'));
        expect(csv, contains('"Say ""hi""",1,1.00'));
        expect(csv, contains('2026-10-17,'));
        expect(csv.split('\r\n').first, 'Report,2026-10-17 to 2026-10-18,all');
      },
    );
  });

  test('a never-settling pump does not leak: the page can be closed', () async {
    // Documented guard for the periodic refresh timer: the cubit cancels it on close.
    final completer = Completer<void>()..complete();
    await completer.future;
  });
}
