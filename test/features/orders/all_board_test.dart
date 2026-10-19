import 'bayan_test_support.dart';
import 'dart:async';

import 'package:bayan_desktop/core/network/api_client.dart';
import 'package:bayan_desktop/core/storage/app_preferences.dart';
import 'package:bayan_desktop/features/orders/data/models/order_model.dart';
import 'package:bayan_desktop/features/orders/data/repositories/orders_repository.dart';
import 'package:bayan_desktop/features/orders/presentation/bloc/orders_bloc.dart';
import 'package:bayan_desktop/features/orders/presentation/bloc/orders_event.dart';
import 'package:bayan_desktop/features/orders/presentation/config/platform_board_config.dart';
import 'package:bayan_desktop/features/orders/presentation/pages/orders_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

OrderModel order(String platform, String id, String status, List<String> actions) => OrderModel(
      platform: platform,
      platformOrderId: id,
      dongleNumber: 'D',
      status: status,
      availableActions: actions,
      transportType: null,
      requiresUrgentAction: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      rawOrder: const {},
    );

class FakeRepository extends OrdersRepository {
  FakeRepository(this.orders) : super(ApiClient());

  final List<OrderModel> orders;
  String? lastPlatform = 'unset';

  @override
  Future<List<OrderModel>> fetchOrders({required String dongleNumber, String? platform}) async {
    lastPlatform = platform;
    return orders;
  }
}

void main() {
  test('All board merges statuses into five columns', () {
    final b = PlatformBoards.all;
    int col(String s) => b.activeColumns.indexWhere((c) => c.holds(s));
    expect(b.activeColumns, hasLength(5));
    // Ready, picked up and out for delivery are one "End process" column.
    expect(col('ORDER_READY'), col('ORDER_PICKED_UP'));
    expect(col('ORDER_PICKED_UP'), col('ORDER_DISPATCHED'));
    expect(col('REFUND_REQUESTED'), col('CANCELLATION_REQUESTED'));
    expect(col('NEW_ORDER'), isNonNegative);
    for (final s in ['NEW_ORDER', 'ORDER_ACCEPTED', 'ORDER_READY', 'ORDER_CANCELLED']) {
      expect(col(s), isNonNegative, reason: s);
    }
    expect(b.isTerminal('ORDER_DELIVERED'), isTrue);
  });

  testWidgets('All tab shows both platforms, merged columns and neutral buttons', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1700, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repo = FakeRepository([
      order('keeta', 'K1', 'NEW_ORDER', ['accept', 'cancel']),
      order('hungerstation', 'H1', 'NEW_ORDER', ['dispatch', 'cancel']),
      order('keeta', 'K2', 'ORDER_READY', ['collect', 'cancel']),
      order('hungerstation', 'H2', 'ORDER_DISPATCHED', []),
    ]);
    final bloc = OrdersBloc(repository: repo, preferences: await AppPreferences.create())
      ..add(const OrdersRequested());

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('en')],
        home: Scaffold(
          body: withBayanOrders(
            BlocProvider.value(value: bloc, child: const OrdersPage()),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(repo.lastPlatform, isNull, reason: 'All = no platform filter');
    expect(find.text('#K1'), findsOneWidget);
    expect(find.text('#H1'), findsOneWidget);
    expect(find.text('End process'), findsOneWidget);
    expect(find.text('Needs attention'), findsOneWidget);
    expect(find.text('Keeta'), findsWidgets);
    expect(find.text('HungerStation'), findsWidgets);
    // Keeta "collect" and HungerStation "dispatch" are the same button.
    expect(find.text('Dispatch'), findsNWidgets(2));
    expect(find.text('Accept'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    unawaited(bloc.close());
  });
}
