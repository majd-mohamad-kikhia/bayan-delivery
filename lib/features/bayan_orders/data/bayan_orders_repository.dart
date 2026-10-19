import 'package:sqflite_common_ffi/sqflite_ffi.dart';

enum BayanSendStatus { sent, failed }

/// What happened the last time an order was sent to Bayan.
final class BayanOrderRecord {
  const BayanOrderRecord({
    required this.platform,
    required this.orderId,
    required this.status,
    required this.attemptedAt,
    this.total,
    this.response,
    this.error,
  });

  factory BayanOrderRecord.fromRow(Map<String, Object?> row) =>
      BayanOrderRecord(
        platform: row['platform']! as String,
        orderId: row['platform_order_id']! as String,
        status: row['status'] == 'sent'
            ? BayanSendStatus.sent
            : BayanSendStatus.failed,
        total: (row['total'] as num?)?.toDouble(),
        response: row['response'] as String?,
        error: row['error'] as String?,
        attemptedAt: DateTime.parse(row['attempted_at']! as String).toLocal(),
      );

  static String keyOf(String platform, String orderId) => '$platform|$orderId';

  final String platform;
  final String orderId;
  final BayanSendStatus status;
  final double? total;

  /// The (shortened) answer Bayan gave.
  final String? response;
  final String? error;
  final DateTime attemptedAt;

  String get key => keyOf(platform, orderId);
  bool get sent => status == BayanSendStatus.sent;

  Map<String, Object?> toRow() => {
    'platform': platform,
    'platform_order_id': orderId,
    'status': sent ? 'sent' : 'failed',
    'total': total,
    'response': response,
    'error': error,
    'attempted_at': attemptedAt.toUtc().toIso8601String(),
  };
}

/// The `bayan_orders` table.
class BayanOrdersRepository {
  const BayanOrdersRepository(this._db);

  final Database _db;

  /// Everything, keyed by `platform|orderId` (read once, then kept in memory
  /// by the sender).
  Future<Map<String, BayanOrderRecord>> all() async {
    final rows = await _db.query('bayan_orders');
    return {
      for (final row in rows)
        BayanOrderRecord.fromRow(row).key: BayanOrderRecord.fromRow(row),
    };
  }

  Future<void> save(BayanOrderRecord record) => _db.insert(
    'bayan_orders',
    record.toRow(),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}
