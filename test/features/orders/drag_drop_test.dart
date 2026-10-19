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
import 'package:bayan_desktop/features/orders/presentation/utils/order_drag_rules.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

OrderModel _order(
  String platform,
  String id,
  String status,
  List<String> actions,
) => OrderModel(
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

class _Repo extends OrdersRepository {
  _Repo(this.orders) : super(ApiClient());

  final List<OrderModel> orders;
  final List<String> actions = [];

  @override
  Future<List<OrderModel>> fetchOrders({
    required String dongleNumber,
    String? platform,
  }) async => orders;

  @override
  Future<OrderModel> performAction({
    required String platform,
    required String platformOrderId,
    required String action,
    required String dongleNumber,
    String? reason,
    Map<String, Object?>? payload,
  }) async {
    actions.add('$platform:$platformOrderId:$action');
    return orders.firstWhere((o) => o.platformOrderId == platformOrderId);
  }
}

BoardColumn _column(PlatformBoardConfig board, String status) =>
    board.activeColumns.firstWhere((c) => c.holds(status));

void main() {
  group('which column a card may be dropped into', () {
    final keeta = PlatformBoards.keeta;

    test('only to the stage its own actions lead to', () {
      final fresh = _order('keeta', '1', 'NEW_ORDER', ['accept', 'cancel']);
      expect(
        dragActionFor(fresh, _column(keeta, 'ORDER_ACCEPTED'), keeta),
        'accept',
      );
      expect(
        dragActionFor(fresh, _column(keeta, 'ORDER_CANCELLED'), keeta),
        'cancel',
      );
      expect(
        dragActionFor(fresh, _column(keeta, 'ORDER_READY'), keeta),
        isNull,
        reason: 'cannot skip a stage',
      );
      expect(
        dragActionFor(fresh, _column(keeta, 'NEW_ORDER'), keeta),
        isNull,
        reason: 'already there',
      );

      final preparing = _order('keeta', '2', 'ORDER_ACCEPTED', [
        'ready',
        'cancel',
      ]);
      expect(
        dragActionFor(preparing, _column(keeta, 'ORDER_READY'), keeta),
        'ready',
      );
      expect(
        dragActionFor(preparing, _column(keeta, 'NEW_ORDER'), keeta),
        isNull,
        reason: 'no going back',
      );
    });

    test('an order with no actions cannot be moved at all', () {
      final done = _order('keeta', '3', 'ORDER_DISPATCHED', const []);
      for (final column in keeta.activeColumns) {
        expect(dragActionFor(done, column, keeta), isNull);
      }
    });

    test('buttons that need a form stay buttons', () {
      final dispatched = _order('keeta', '4', 'ORDER_READY', [
        'collect',
        'selfDispatch',
        'partialRefund',
        'cancel',
      ]);
      // Both collect and selfDispatch lead to "dispatched"; dragging uses the plain one.
      expect(
        dragActionFor(dispatched, _column(keeta, 'ORDER_PICKED_UP'), keeta),
        'collect',
      );
    });

    test(
      'HungerStation: logistics goes to ready, own delivery to dispatched',
      () {
        final hs = PlatformBoards.hungerstation;
        final logistics = _order('hungerstation', '5', 'NEW_ORDER', [
          'ready',
          'cancel',
        ]);
        final vendor = _order('hungerstation', '6', 'NEW_ORDER', [
          'dispatch',
          'cancel',
        ]);
        expect(
          dragActionFor(logistics, _column(hs, 'ORDER_READY'), hs),
          'ready',
        );
        expect(
          dragActionFor(logistics, _column(hs, 'ORDER_DISPATCHED'), hs),
          isNull,
        );
        expect(
          dragActionFor(vendor, _column(hs, 'ORDER_DISPATCHED'), hs),
          'dispatch',
        );
      },
    );

    test('the merged board: both platforms land in the shared columns', () {
      final all = PlatformBoards.all;
      final keetaReady = _order('keeta', '7', 'ORDER_READY', [
        'collect',
        'cancel',
      ]);
      final hsVendor = _order('hungerstation', '8', 'NEW_ORDER', [
        'dispatch',
        'cancel',
      ]);
      final endProcess = _column(all, 'ORDER_READY');
      expect(
        dragActionFor(keetaReady, endProcess, all),
        isNull,
        reason: 'already in End process',
      );
      expect(dragActionFor(hsVendor, endProcess, all), 'dispatch');
      expect(
        dragActionFor(hsVendor, _column(all, 'ORDER_ACCEPTED'), all),
        isNull,
      );
    });
  });

  testWidgets('dragging a card into the next column sends that action', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(2400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repo = _Repo([
      _order('keeta', 'K1', 'NEW_ORDER', ['accept', 'cancel']),
    ]);
    final bloc = OrdersBloc(
      repository: repo,
      preferences: await AppPreferences.create(),
    )..add(const OrdersRequested());
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
    expect(find.text('#K1'), findsOneWidget);

    // The card's centre → the middle of the "Preparing" column (second column).
    final card = tester.getCenter(find.text('#K1'));
    final target = Offset(card.dx + 360, card.dy + 40);
    final gesture = await tester.startGesture(card);
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveTo(target, timeStamp: const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.textContaining('Drop to'),
      findsWidgets,
      reason: 'the column that takes it says so',
    );
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repo.actions, ['keeta:K1:accept']);

    await tester.pumpWidget(const SizedBox());
    unawaited(bloc.close());
  });

  testWidgets('a column that cannot take the card refuses the drop', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(2400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repo = _Repo([
      _order('keeta', 'K2', 'NEW_ORDER', ['accept', 'cancel']),
    ]);
    final bloc = OrdersBloc(
      repository: repo,
      preferences: await AppPreferences.create(),
    )..add(const OrdersRequested());
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

    // Straight to the third column (End process): not a move this order may make.
    final card = tester.getCenter(find.text('#K2'));
    final gesture = await tester.startGesture(card);
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveTo(
      Offset(card.dx + 720, card.dy + 40),
      timeStamp: const Duration(milliseconds: 100),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repo.actions, isEmpty);

    await tester.pumpWidget(const SizedBox());
    unawaited(bloc.close());
  });
}
