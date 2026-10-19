import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The app's local SQLite database (`bayan_hub.db`, in the app-support
/// folder — inside the sandbox container on macOS).
///
/// - `sqflite_common_ffi` runs every query in a background isolate, so
///   database work never blocks the UI thread.
/// - WAL journaling: reads don't wait for writes, and each write is one
///   sequential append instead of a rollback-journal round-trip.
///
/// Add a table by bumping [version], adding its statements to [_onCreate]
/// (new installs) and a step to [_onUpgrade] (existing installs).
class AppDatabase {
  const AppDatabase._(this.db);

  static const String fileName = 'bayan_hub.db';
  static const int version = 6;

  final Database db;

  /// Opens (creating it on first launch) the database file.
  ///
  /// [factory] and [path] exist for tests: pass `databaseFactoryFfi` and
  /// `inMemoryDatabasePath` for an isolated in-memory database.
  static Future<AppDatabase> open({
    DatabaseFactory? factory,
    String? path,
  }) async {
    if (factory == null) sqfliteFfiInit();
    final dbFactory = factory ?? databaseFactoryFfi;
    final dbPath =
        path ?? p.join((await getApplicationSupportDirectory()).path, fileName);

    final db = await dbFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: version,
        onConfigure: _onConfigure,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
    return AppDatabase._(db);
  }

  Future<void> close() => db.close();

  static Future<void> _onConfigure(Database db) async {
    // PRAGMAs that report a value must go through rawQuery.
    await db.rawQuery('PRAGMA journal_mode = WAL');
    await db.execute('PRAGMA synchronous = NORMAL');
    await db.execute('PRAGMA foreign_keys = ON');
  }

  static Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();
    for (final statement in [
      ...productRecordsSchema,
      ...ordersSchema,
      ...productSyncSchema,
      ...bayanOrdersSchema,
    ]) {
      batch.execute(statement);
    }
    await batch.commit(noResult: true);
  }

  static Future<void> _onUpgrade(Database db, int from, int to) async {
    // One `if (from < N)` block per version, so an old install upgrades
    // step by step.
    if (from < 2) {
      for (final statement in ordersSchema) {
        await db.execute(statement);
      }
    }
    if (from < 3) {
      for (final statement in productSyncSchema) {
        await db.execute(statement);
      }
    }
    if (from < 5) {
      for (final statement in bayanOrdersSchema) {
        await db.execute(statement);
      }
    }
    if (from < 6) {
      // Timed offers were removed from the app.
      await db.execute('DROP TABLE IF EXISTS product_offers');
    }
  }

  /// Local copy of the orders list. The middleware is the source of truth:
  /// rows are always upserted from its responses, never edited locally.
  /// Only the columns we filter or sort on are separate; the rest of the
  /// platform payload stays in `order_json`.
  static const List<String> ordersSchema = [
    '''
CREATE TABLE orders (
  platform               TEXT    NOT NULL,
  platform_order_id      TEXT    NOT NULL,
  dongle_number          TEXT    NOT NULL,
  status                 TEXT    NOT NULL,
  last_event             TEXT,
  transport_type         TEXT,
  requires_urgent_action INTEGER NOT NULL DEFAULT 0,
  available_actions      TEXT    NOT NULL,
  order_json             TEXT    NOT NULL,
  created_at             TEXT    NOT NULL,
  updated_at             TEXT    NOT NULL,
  synced_at              TEXT    NOT NULL,
  PRIMARY KEY (platform, platform_order_id, dongle_number)
) WITHOUT ROWID''',
    'CREATE INDEX idx_orders_list ON orders(dongle_number, platform, updated_at DESC)',
    'CREATE INDEX idx_orders_urgent ON orders(dongle_number, requires_urgent_action)',
  ];

  /// Orders sent to Bayan as invoices: one row per platform order, so an order
  /// is never sent twice (a failed attempt keeps its error and may be retried).
  static const List<String> bayanOrdersSchema = [
    '''
CREATE TABLE bayan_orders (
  platform          TEXT NOT NULL,
  platform_order_id TEXT NOT NULL,
  status            TEXT NOT NULL,
  total             REAL,
  response          TEXT,
  error             TEXT,
  attempted_at      TEXT NOT NULL,
  PRIMARY KEY (platform, platform_order_id)
) WITHOUT ROWID''',
  ];

  /// What was last sent to each platform for a product: the price (minor
  /// units) and the name. The sync compares Al-Bayan's current values with
  /// these to find what changed, and updates a row only when that platform
  /// accepted the change, so a platform that was down is retried next time.
  static const List<String> productSyncSchema = [
    '''
CREATE TABLE product_sync (
  bayan_num   TEXT    NOT NULL,
  platform    TEXT    NOT NULL,
  price_minor INTEGER NOT NULL,
  name        TEXT    NOT NULL,
  synced_at   TEXT    NOT NULL,
  PRIMARY KEY (bayan_num, platform)
) WITHOUT ROWID''',
  ];

  /// Table for the five product fields: Name, BayanNum, KeetaNum,
  /// HungerNum, CareemNum.
  ///
  /// - `bayan_num` is the primary key (WITHOUT ROWID: the table *is* its
  ///   index, no second lookup);
  /// - a platform number can belong to only one product, and each has an
  ///   index for the reverse lookup a webhook needs ("which Bayan product
  ///   is Keeta item 9001?"). The indexes are partial — products not on a
  ///   platform cost nothing there.
  static const List<String> productRecordsSchema = [
    '''
CREATE TABLE products (
  bayan_num  TEXT NOT NULL PRIMARY KEY,
  name       TEXT NOT NULL,
  keeta_num  TEXT,
  hunger_num TEXT,
  careem_num TEXT
) WITHOUT ROWID''',
    'CREATE UNIQUE INDEX idx_products_keeta_num ON products(keeta_num) WHERE keeta_num IS NOT NULL',
    'CREATE UNIQUE INDEX idx_products_hunger_num ON products(hunger_num) WHERE hunger_num IS NOT NULL',
    'CREATE UNIQUE INDEX idx_products_careem_num ON products(careem_num) WHERE careem_num IS NOT NULL',
    'CREATE INDEX idx_products_name ON products(name COLLATE NOCASE)',
  ];
}
