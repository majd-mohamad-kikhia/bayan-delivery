import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/product_record.dart';

/// Local store of the five product fields (Name, BayanNum, KeetaNum,
/// HungerNum, CareemNum) in the `products` table.
///
/// - [save] merges: a platform number that isn't given keeps its stored
///   value, so recording "published to Keeta" never erases the
///   HungerStation number. Use [setPlatformNum] with null to clear one.
/// - A platform number belongs to one product; saving a number already
///   used by another product throws a [DatabaseException].
/// - Every statement is parameterized and runs in the database isolate.
class ProductRecordsRepository {
  const ProductRecordsRepository(this._db);

  final Database _db;

  static const String _upsertSql = '''
INSERT INTO products (bayan_num, name, keeta_num, hunger_num, careem_num)
VALUES (?, ?, ?, ?, ?)
ON CONFLICT(bayan_num) DO UPDATE SET
  name       = excluded.name,
  keeta_num  = COALESCE(excluded.keeta_num, keeta_num),
  hunger_num = COALESCE(excluded.hunger_num, hunger_num),
  careem_num = COALESCE(excluded.careem_num, careem_num)''';

  /// Inserts the product, or updates it if [ProductRecord.bayanNum] exists.
  Future<void> save(ProductRecord record) =>
      _db.rawInsert(_upsertSql, _upsertArgs(record));

  /// Saves many products in one transaction (one disk sync, not one per
  /// row) — for importing the Al-Bayan catalog.
  Future<void> saveAll(Iterable<ProductRecord> records) async {
    final batch = _db.batch();
    for (final record in records) {
      batch.rawInsert(_upsertSql, _upsertArgs(record));
    }
    await batch.commit(noResult: true);
  }

  /// Sets (or, with null, clears) the number on [platformId] — `keeta`,
  /// `hungerstation` or `careem`. Returns false when there is no product
  /// with [bayanNum] (nothing is created: a product needs a name).
  Future<bool> setPlatformNum(
    String bayanNum,
    String platformId,
    String? platformNum,
  ) async {
    final column = _column(platformId);
    final updated = await _db.rawUpdate(
      'UPDATE products SET $column = ? WHERE bayan_num = ?',
      [_clean(platformNum), bayanNum.trim()],
    );
    return updated > 0;
  }

  Future<ProductRecord?> byBayanNum(String bayanNum) async {
    final rows = await _db.query(
      'products',
      where: 'bayan_num = ?',
      whereArgs: [bayanNum.trim()],
      limit: 1,
    );
    return rows.isEmpty ? null : ProductRecord.fromRow(rows.single);
  }

  /// The product that has [platformNum] on [platformId] — what a webhook
  /// or order line needs to find the Al-Bayan product. Index lookup.
  Future<ProductRecord?> byPlatformNum(
    String platformId,
    String platformNum,
  ) async {
    final rows = await _db.query(
      'products',
      where: '${_column(platformId)} = ?',
      whereArgs: [platformNum.trim()],
      limit: 1,
    );
    return rows.isEmpty ? null : ProductRecord.fromRow(rows.single);
  }

  /// Products ordered by name. [query] matches anywhere in the name or in
  /// any of the four numbers. Paged: [limit] rows from [offset].
  Future<List<ProductRecord>> list({
    String? query,
    int limit = 100,
    int offset = 0,
  }) async {
    final text = query?.trim() ?? '';
    final pattern =
        '%${text.replaceAllMapped(RegExp(r'[\\%_]'), (m) => '\\${m[0]}')}%';
    final rows = await _db.query(
      'products',
      where: text.isEmpty
          ? null
          : r"name LIKE ?1 ESCAPE '\' OR bayan_num LIKE ?1 ESCAPE '\' "
                r"OR keeta_num LIKE ?1 ESCAPE '\' OR hunger_num LIKE ?1 ESCAPE '\' "
                r"OR careem_num LIKE ?1 ESCAPE '\'",
      whereArgs: text.isEmpty ? null : [pattern],
      orderBy: 'name COLLATE NOCASE, bayan_num',
      limit: limit,
      offset: offset,
    );
    return [for (final row in rows) ProductRecord.fromRow(row)];
  }

  Future<int> count() async {
    final rows = await _db.rawQuery('SELECT COUNT(*) AS n FROM products');
    return rows.single['n']! as int;
  }

  /// Returns false when there was no such product.
  Future<bool> delete(String bayanNum) async =>
      await _db.delete(
        'products',
        where: 'bayan_num = ?',
        whereArgs: [bayanNum.trim()],
      ) >
      0;

  // ── Helpers ───────────────────────────────────────────────────────────────

  static List<Object?> _upsertArgs(ProductRecord record) {
    final bayanNum = record.bayanNum.trim();
    final name = record.name.trim();
    if (bayanNum.isEmpty) {
      throw ArgumentError.value(
        record.bayanNum,
        'bayanNum',
        'must not be empty',
      );
    }
    if (name.isEmpty) {
      throw ArgumentError.value(record.name, 'name', 'must not be empty');
    }
    return [
      bayanNum,
      name,
      _clean(record.keetaNum),
      _clean(record.hungerNum),
      _clean(record.careemNum),
    ];
  }

  /// Trimmed text, or null when blank — an empty string must never be
  /// stored as a platform number.
  static String? _clean(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  /// Column for a platform id — a fixed list, never caller text, so it is
  /// safe to put in SQL.
  static String _column(String platformId) => switch (platformId) {
    'keeta' => 'keeta_num',
    'hungerstation' => 'hunger_num',
    'careem' => 'careem_num',
    _ => throw ArgumentError.value(
      platformId,
      'platformId',
      'unknown platform',
    ),
  };
}
