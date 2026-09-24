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
  static const int version = 1;

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
    for (final statement in productRecordsSchema) {
      batch.execute(statement);
    }
    await batch.commit(noResult: true);
  }

  static Future<void> _onUpgrade(Database db, int from, int to) async {
    // Version 1 is the first schema. Future migrations go here, one
    // `if (from < N)` block each, so an old install upgrades step by step.
  }

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
