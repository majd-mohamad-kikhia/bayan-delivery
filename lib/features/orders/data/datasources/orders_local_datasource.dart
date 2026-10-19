import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/order_model.dart';

/// SQLite cache of orders. Knows nothing about the network: the repository
/// decides what to write, this only stores and reads.
class OrdersLocalDatasource {
  const OrdersLocalDatasource(this._db);

  final Database _db;

  static const String _upsertSql = '''
INSERT INTO orders (
  platform, platform_order_id, dongle_number, status, last_event,
  transport_type, requires_urgent_action, available_actions, order_json,
  created_at, updated_at, synced_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
ON CONFLICT(platform, platform_order_id, dongle_number) DO UPDATE SET
  status                 = excluded.status,
  last_event             = excluded.last_event,
  transport_type         = excluded.transport_type,
  requires_urgent_action = excluded.requires_urgent_action,
  available_actions      = excluded.available_actions,
  order_json             = excluded.order_json,
  created_at             = excluded.created_at,
  updated_at             = excluded.updated_at,
  synced_at              = excluded.synced_at''';

  static List<Object?> _args(OrderModel o, DateTime now) {
    final row = o.toDb(syncedAt: now);
    return [
      row['platform'],
      row['platform_order_id'],
      row['dongle_number'],
      row['status'],
      row['last_event'],
      row['transport_type'],
      row['requires_urgent_action'],
      row['available_actions'],
      row['order_json'],
      row['created_at'],
      row['updated_at'],
      row['synced_at'],
    ];
  }

  Future<void> upsert(OrderModel order) =>
      _db.rawInsert(_upsertSql, _args(order, DateTime.now()));

  /// Upserts [orders] in one transaction. Never deletes: this database is
  /// the durable order history, and the backend (which keeps no database)
  /// may have forgotten older orders after a restart.
  Future<void> saveAll(List<OrderModel> orders) async {
    final now = DateTime.now();
    final batch = _db.batch();
    for (final o in orders) {
      batch.rawInsert(_upsertSql, _args(o, now));
    }
    await batch.commit(noResult: true);
  }

  Future<OrderModel?> find(String platform, String platformOrderId) async {
    final rows = await _db.query(
      'orders',
      where: 'platform = ? AND platform_order_id = ?',
      whereArgs: [platform, platformOrderId],
      limit: 1,
    );
    return rows.isEmpty ? null : OrderModel.fromDb(rows.first);
  }

  Future<List<OrderModel>> list({
    required String dongleNumber,
    String? platform,
  }) async {
    final rows = await _db.query(
      'orders',
      where: 'dongle_number = ?${platform == null ? '' : ' AND platform = ?'}',
      whereArgs: [dongleNumber, ?platform],
      orderBy: 'updated_at DESC',
    );
    return rows.map(OrderModel.fromDb).toList();
  }

  /// When this dongle's orders were last fetched, or null if never.
  Future<DateTime?> lastSyncedAt({required String dongleNumber}) async {
    final rows = await _db.rawQuery(
      'SELECT MAX(synced_at) AS t FROM orders WHERE dongle_number = ?',
      [dongleNumber],
    );
    final t = rows.first['t'] as String?;
    return t == null ? null : DateTime.parse(t).toLocal();
  }
}
