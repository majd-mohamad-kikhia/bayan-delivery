import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// What was last sent to one platform for one product.
final class SyncedValues {
  const SyncedValues({required this.priceMinor, required this.name});

  final int priceMinor;
  final String name;
}

/// The `product_sync` table: the price and name last accepted by each
/// platform, per Al-Bayan product.
class ProductSyncRepository {
  const ProductSyncRepository(this._db);

  final Database _db;

  static String _key(String bayanNum, String platform) => '$platform|$bayanNum';

  /// Everything, keyed by `platform|bayanNum` (see [lookup]).
  Future<Map<String, SyncedValues>> all() async {
    final rows = await _db.query('product_sync');
    return {
      for (final row in rows)
        _key(
          row['bayan_num']! as String,
          row['platform']! as String,
        ): SyncedValues(
          priceMinor: row['price_minor']! as int,
          name: row['name']! as String,
        ),
    };
  }

  static SyncedValues? lookup(
    Map<String, SyncedValues> all,
    String bayanNum,
    String platform,
  ) => all[_key(bayanNum, platform)];

  /// Records [values] as sent. [replace] false keeps a row that already
  /// exists (a baseline never overrides what a real push recorded).
  Future<void> save(
    Iterable<({String bayanNum, String platform, SyncedValues values})>
    entries, {
    bool replace = true,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final batch = _db.batch();
    for (final e in entries) {
      batch.insert(
        'product_sync',
        {
          'bayan_num': e.bayanNum,
          'platform': e.platform,
          'price_minor': e.values.priceMinor,
          'name': e.values.name,
          'synced_at': now,
        },
        conflictAlgorithm: replace
            ? ConflictAlgorithm.replace
            : ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Forget a platform's record, e.g. when the product is no longer there.
  Future<void> clear(String bayanNum, String platform) => _db.delete(
    'product_sync',
    where: 'bayan_num = ? AND platform = ?',
    whereArgs: [bayanNum, platform],
  );
}
