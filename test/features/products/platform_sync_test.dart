import 'package:bayan_desktop/core/database/app_database.dart';
import 'package:bayan_desktop/features/bayan_erp/data/models/erp_product_model.dart';
import 'package:bayan_desktop/features/products/data/models/product_record.dart';
import 'package:bayan_desktop/features/products/data/platform_sync_service.dart';
import 'package:bayan_desktop/features/products/data/repositories/product_records_repository.dart';
import 'package:bayan_desktop/features/products/data/repositories/product_sync_repository.dart';
import 'package:bayan_desktop/features/products/presentation/cubit/product_registry_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

ErpProductModel _erp(int id, String name, double price, {int parent = 0, int kind = 0}) => ErpProductModel(
      id: id,
      name: name,
      shortName: '',
      quantity: 1,
      price1: price,
      price2: 0,
      price3: 0,
      price4: 0,
      price5: 0,
      currency: 0,
      parentId: parent,
      kind: kind,
    );

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase database;
  late ProductRecordsRepository records;
  late ProductSyncRepository sync;
  late List<ErpProductModel> catalog;
  late List<({int spuId, double? price, String? name})> keetaCalls;
  late List<({String sku, double price})> hsCalls;
  Set<int> keetaFails = {};
  Set<String> hsFails = {};
  Object? catalogError;

  PlatformSyncService service() => PlatformSyncService(
        loadCatalog: () async {
          if (catalogError != null) throw catalogError!;
          return catalog;
        },
        records: records,
        state: sync,
        pushKeeta: (changes) async {
          keetaCalls.addAll(changes);
          return keetaFails;
        },
        pushHungerStation: (changes) async {
          hsCalls.addAll(changes);
          return hsFails;
        },
      );

  setUp(() async {
    database = await AppDatabase.open(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    records = ProductRecordsRepository(database.db);
    sync = ProductSyncRepository(database.db);
    catalog = [
      _erp(1, 'Group', 0, kind: 1),
      _erp(2, 'Burger', 25, parent: 1),
      _erp(3, 'Fries', 10, parent: 1),
      _erp(4, 'Brand new item', 8, parent: 1),
    ];
    keetaCalls = [];
    hsCalls = [];
    keetaFails = {};
    hsFails = {};
    catalogError = null;
    await records.saveAll(const [
      ProductRecord(bayanNum: '2', name: 'Burger', keetaNum: '9002', hungerNum: '2'),
      ProductRecord(bayanNum: '3', name: 'Fries', keetaNum: '9003'),
    ]);
  });

  tearDown(() => database.close());

  test('the first run only records a baseline: nothing is sent for what was never compared', () async {
    final report = await service().run();

    expect(report.baselined, 3, reason: 'burger on both platforms + fries on Keeta');
    expect(report.changes, isEmpty);
    expect(keetaCalls, isEmpty);
    expect(hsCalls, isEmpty);
  });

  test('a price changed in Al-Bayan is sent to both platforms, once', () async {
    await service().run(); // baseline
    catalog = [catalog[0], _erp(2, 'Burger', 27.5, parent: 1), catalog[2], catalog[3]];

    final report = await service().run();

    expect(report.sent, 2);
    expect(keetaCalls.single.spuId, 9002);
    expect(keetaCalls.single.price, 27.5);
    expect(keetaCalls.single.name, isNull, reason: 'the name did not change');
    expect(hsCalls.single.sku, '2');
    expect(hsCalls.single.price, 27.5);
    expect(report.changes.first.oldPriceMinor, 2500);
    expect(report.changes.first.newPriceMinor, 2750);

    keetaCalls.clear();
    hsCalls.clear();
    final again = await service().run();
    expect(again.changes, isEmpty, reason: 'accepted changes are remembered');
    expect(keetaCalls, isEmpty);
    expect(hsCalls, isEmpty);
  });

  test('a platform that refused is retried next time; the other is not resent', () async {
    await service().run();
    catalog = [catalog[0], _erp(2, 'Burger', 30, parent: 1), catalog[2], catalog[3]];
    keetaFails = {9002};

    final first = await service().run();
    expect(first.sent, 1);
    expect(first.failed, 1);
    expect(first.changes.firstWhere((c) => !c.ok).platform, 'keeta');

    keetaCalls.clear();
    hsCalls.clear();
    keetaFails = {};
    final retry = await service().run();
    expect(keetaCalls.single.price, 30, reason: 'Keeta gets it now');
    expect(hsCalls, isEmpty, reason: 'HungerStation already has it');
    expect(retry.sent, 1);
  });

  test('a platform that throws fails its changes without losing the other platform', () async {
    await service().run();
    catalog = [catalog[0], _erp(2, 'Burger', 31, parent: 1), catalog[2], catalog[3]];
    final broken = PlatformSyncService(
      loadCatalog: () async => catalog,
      records: records,
      state: sync,
      pushKeeta: (_) async => throw StateError('Keeta is down'),
      pushHungerStation: (changes) async => {},
    );

    final report = await broken.run();
    expect(report.changes.firstWhere((c) => c.platform == 'keeta').ok, isFalse);
    expect(report.changes.firstWhere((c) => c.platform == 'keeta').error, contains('Keeta is down'));
    expect(report.changes.firstWhere((c) => c.platform == 'hungerstation').ok, isTrue);
  });

  test('a rename goes to Keeta; HungerStation cannot rename, so nothing is sent there', () async {
    await service().run();
    catalog = [catalog[0], _erp(2, 'Beef Burger', 25, parent: 1), catalog[2], catalog[3]];

    final report = await service().run();

    expect(keetaCalls.single.name, 'Beef Burger');
    expect(keetaCalls.single.price, isNull);
    expect(hsCalls, isEmpty);
    expect(report.changes.single.nameChanged, isTrue);

    keetaCalls.clear();
    expect((await service().run()).changes, isEmpty, reason: 'and not again next time');
  });

  test('items on no platform are reported as new; groups and add-ons are not', () async {
    catalog = [
      ...catalog,
      _erp(10, 'إضافات', 0, kind: 1),
      _erp(11, 'بطاطا زيادة', 3, parent: 10),
    ];
    final report = await service().run();
    expect([for (final p in report.newProducts) p.name], ['Brand new item']);
    expect(report.catalog, hasLength(6), reason: 'the whole catalog travels with it, to name groups later');
  });

  test('an unreadable or empty Al-Bayan changes nothing and is not mistaken for deletions', () async {
    await service().run();
    catalogError = StateError('Bayan unreachable');
    final failed = await service().run();
    expect(failed.error, contains('Bayan unreachable'));
    expect(failed.changes, isEmpty);

    catalogError = null;
    catalog = [];
    final empty = await service().run();
    expect(empty.error, isNull);
    expect(empty.changes, isEmpty);
    expect(keetaCalls, isEmpty);
  });

  test('publishing records the price sent, so a change right after is caught', () async {
    final registry = ProductRegistryCubit(records, sync);
    addTearDown(registry.close);
    await registry.markPublished(
      bayanNum: '4',
      name: 'Brand new item',
      platformId: 'keeta',
      platformNum: '9004',
      priceMinor: 800,
    );

    // Al-Bayan's price moves before the first sync ever runs.
    catalog = [catalog[0], catalog[1], catalog[2], _erp(4, 'Brand new item', 9, parent: 1)];
    final report = await service().run();

    expect(keetaCalls.where((c) => c.spuId == 9004).single.price, 9);
    expect(report.changes.where((c) => c.bayanNum == '4').single.oldPriceMinor, 800);
  });
}
