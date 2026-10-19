import 'package:bayan_desktop/core/database/app_database.dart';
import 'package:bayan_desktop/features/orders/data/datasources/orders_local_datasource.dart';
import 'package:bayan_desktop/features/orders/data/models/order_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

OrderModel order(
  String id, {
  String platform = 'keeta',
  String status = 'NEW_ORDER',
}) => OrderModel(
  platform: platform,
  platformOrderId: id,
  dongleNumber: 'D1',
  status: status,
  availableActions: const ['accept', 'cancel'],
  transportType: null,
  requiresUrgentAction: true,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1, 0, 5),
  rawOrder: const {
    'total': 12.5,
    'customer': {'name': 'Ali'},
  },
);

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase database;
  late OrdersLocalDatasource local;

  setUp(() async {
    database = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    local = OrdersLocalDatasource(database.db);
  });
  tearDown(() => database.close());

  test('round-trips an order', () async {
    await local.upsert(order('1'));
    final got = (await local.list(dongleNumber: 'D1')).single;
    expect(got, order('1'));
    expect(got.customerName, 'Ali');
  });

  test('upsert updates instead of duplicating', () async {
    await local.upsert(order('1'));
    await local.upsert(order('1', status: 'ORDER_ACCEPTED'));
    final all = await local.list(dongleNumber: 'D1');
    expect(all, hasLength(1));
    expect(all.single.status, 'ORDER_ACCEPTED');
  });

  test('saveAll keeps older orders the server no longer returns', () async {
    await local.saveAll([
      order('1'),
      order('2'),
      order('h1', platform: 'hungerstation'),
    ]);
    await local.saveAll([order('2', status: 'ORDER_ACCEPTED')]);
    final all = await local.list(dongleNumber: 'D1');
    expect(all.map((o) => o.platformOrderId).toSet(), {'1', '2', 'h1'});
    expect((await local.find('keeta', '2'))!.status, 'ORDER_ACCEPTED');
    expect(await local.find('keeta', 'nope'), isNull);
  });
}
