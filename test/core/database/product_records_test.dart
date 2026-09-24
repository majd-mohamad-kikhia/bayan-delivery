import 'dart:io';

import 'package:bayan_desktop/core/database/app_database.dart';
import 'package:bayan_desktop/features/products/data/models/product_record.dart';
import 'package:bayan_desktop/features/products/data/repositories/product_records_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase database;
  late ProductRecordsRepository repository;

  setUp(() async {
    database = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    repository = ProductRecordsRepository(database.db);
  });

  tearDown(() => database.close());

  const bread = ProductRecord(
    bayanNum: 'BYN-BRD-001',
    name: 'Arabic Bread Pack',
    keetaNum: '9001',
  );

  test('creates the products table with the five fields', () async {
    final columns = await database.db.rawQuery('PRAGMA table_info(products)');
    expect(columns.map((c) => c['name']), [
      'bayan_num',
      'name',
      'keeta_num',
      'hunger_num',
      'careem_num',
    ]);
  });

  test('saves and reads back all five fields', () async {
    const record = ProductRecord(
      bayanNum: 'BYN-BRD-001',
      name: 'Arabic Bread Pack',
      keetaNum: '9001',
      hungerNum: 'HS-1',
      careemNum: 'CR-1',
    );
    await repository.save(record);

    expect(await repository.byBayanNum('BYN-BRD-001'), record);
    expect(await repository.count(), 1);
  });

  test('a platform number that is not given keeps its stored value', () async {
    await repository.save(bread);
    await repository.save(
      const ProductRecord(
        bayanNum: 'BYN-BRD-001',
        name: 'Arabic Bread (renamed)',
        hungerNum: 'HS-1',
      ),
    );

    expect(
      await repository.byBayanNum('BYN-BRD-001'),
      const ProductRecord(
        bayanNum: 'BYN-BRD-001',
        name: 'Arabic Bread (renamed)',
        keetaNum: '9001',
        hungerNum: 'HS-1',
      ),
    );
    expect(await repository.count(), 1);
  });

  test(
    'setPlatformNum sets and clears one number, never creates a row',
    () async {
      await repository.save(bread);

      expect(
        await repository.setPlatformNum('BYN-BRD-001', 'careem', ' CR-9 '),
        isTrue,
      );
      expect((await repository.byBayanNum('BYN-BRD-001'))!.careemNum, 'CR-9');

      expect(
        await repository.setPlatformNum('BYN-BRD-001', 'keeta', null),
        isTrue,
      );
      expect((await repository.byBayanNum('BYN-BRD-001'))!.keetaNum, isNull);

      expect(await repository.setPlatformNum('MISSING', 'keeta', '1'), isFalse);
      expect(await repository.count(), 1);
      expect(
        () => repository.setPlatformNum(
          'BYN-BRD-001',
          'x; DROP TABLE products',
          '1',
        ),
        throwsArgumentError,
      );
    },
  );

  test('blank values are stored as null and empty keys are rejected', () async {
    await repository.save(
      const ProductRecord(
        bayanNum: ' B1 ',
        name: ' Rice ',
        keetaNum: '  ',
        hungerNum: '',
      ),
    );
    expect(
      await repository.byBayanNum('B1'),
      const ProductRecord(bayanNum: 'B1', name: 'Rice'),
    );

    expect(
      () => repository.save(const ProductRecord(bayanNum: ' ', name: 'x')),
      throwsArgumentError,
    );
    expect(
      () => repository.save(const ProductRecord(bayanNum: 'B2', name: ' ')),
      throwsArgumentError,
    );
  });

  test('finds the Al-Bayan product from a platform number', () async {
    await repository.saveAll(const [
      ProductRecord(
        bayanNum: 'B1',
        name: 'Bread',
        keetaNum: '9001',
        hungerNum: 'H1',
      ),
      ProductRecord(
        bayanNum: 'B2',
        name: 'Rice',
        keetaNum: '9002',
        careemNum: 'C2',
      ),
    ]);

    expect((await repository.byPlatformNum('keeta', '9002'))!.name, 'Rice');
    expect(
      (await repository.byPlatformNum('hungerstation', 'H1'))!.name,
      'Bread',
    );
    expect((await repository.byPlatformNum('careem', 'C2'))!.bayanNum, 'B2');
    expect(await repository.byPlatformNum('keeta', '0000'), isNull);
  });

  test('a platform number cannot belong to two products', () async {
    await repository.save(bread);
    await expectLater(
      repository.save(
        const ProductRecord(bayanNum: 'B2', name: 'Other', keetaNum: '9001'),
      ),
      throwsA(isA<DatabaseException>()),
    );
    expect(await repository.count(), 1);
  });

  test('saveAll is atomic', () async {
    await expectLater(
      repository.saveAll(const [
        ProductRecord(bayanNum: 'B1', name: 'Bread', keetaNum: '1'),
        ProductRecord(bayanNum: 'B2', name: 'Rice', keetaNum: '1'),
      ]),
      throwsA(isA<DatabaseException>()),
    );
    expect(await repository.count(), 0);
  });

  test(
    'list searches name and every number, pages, and escapes wildcards',
    () async {
      await repository.saveAll(const [
        ProductRecord(bayanNum: 'BYN-2', name: 'olive oil', keetaNum: '77'),
        ProductRecord(
          bayanNum: 'BYN-1',
          name: 'Arabic Bread',
          hungerNum: 'HS-OIL',
        ),
        ProductRecord(bayanNum: 'BYN-3', name: '100% Juice', careemNum: 'CR_3'),
      ]);

      // Ordered by name, ignoring case: "100% Juice", "Arabic Bread", "olive oil".
      expect((await repository.list()).map((r) => r.bayanNum), [
        'BYN-3',
        'BYN-1',
        'BYN-2',
      ]);
      expect((await repository.list(query: 'OIL')).map((r) => r.bayanNum), [
        'BYN-1',
        'BYN-2',
      ]);
      expect((await repository.list(query: '77')).single.bayanNum, 'BYN-2');
      expect((await repository.list(query: '100%')).single.bayanNum, 'BYN-3');
      expect((await repository.list(query: '%')).single.bayanNum, 'BYN-3');
      expect((await repository.list(query: 'CR_3')).single.bayanNum, 'BYN-3');
      expect(await repository.list(query: 'C__3'), isEmpty);
      expect(
        (await repository.list(limit: 1, offset: 1)).single.bayanNum,
        'BYN-1',
      );
    },
  );

  test('delete removes a product', () async {
    await repository.save(bread);
    expect(await repository.delete('BYN-BRD-001'), isTrue);
    expect(await repository.delete('BYN-BRD-001'), isFalse);
    expect(await repository.count(), 0);
  });

  test('reverse lookups and key lookups use their indexes', () async {
    Future<String> plan(String sql, [List<Object?> args = const []]) async {
      final rows = await database.db.rawQuery('EXPLAIN QUERY PLAN $sql', args);
      return rows.map((r) => r['detail']).join(' | ');
    }

    expect(
      await plan('SELECT * FROM products WHERE keeta_num = ?', ['1']),
      contains('idx_products_keeta_num'),
    );
    expect(
      await plan('SELECT * FROM products WHERE hunger_num = ?', ['1']),
      contains('idx_products_hunger_num'),
    );
    expect(
      await plan('SELECT * FROM products WHERE careem_num = ?', ['1']),
      contains('idx_products_careem_num'),
    );
    expect(
      await plan('SELECT * FROM products WHERE bayan_num = ?', ['1']),
      contains('PRIMARY KEY'),
    );
  });

  test('data survives closing and reopening the file', () async {
    final dir = await Directory.systemTemp.createTemp('bayan_db_test');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/bayan_hub.db';

    final first = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: path,
    );
    await ProductRecordsRepository(first.db).save(bread);
    await first.close();

    final second = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: path,
    );
    addTearDown(second.close);
    expect(
      await ProductRecordsRepository(second.db).byBayanNum('BYN-BRD-001'),
      bread,
    );
    final mode = await second.db.rawQuery('PRAGMA journal_mode');
    expect(mode.single.values.single, 'wal');
  });
}
