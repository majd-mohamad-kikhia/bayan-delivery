import 'package:bayan_desktop/core/database/app_database.dart';
import 'package:bayan_desktop/core/storage/app_preferences.dart';
import 'package:bayan_desktop/features/bayan_erp/data/models/erp_product_model.dart';
import 'package:bayan_desktop/features/products/data/repositories/product_publish_repository.dart';
import 'package:bayan_desktop/features/products/data/repositories/product_records_repository.dart';
import 'package:bayan_desktop/features/products/data/repositories/product_sync_repository.dart';
import 'package:bayan_desktop/features/products/presentation/cubit/auto_publisher.dart';
import 'package:bayan_desktop/features/products/presentation/cubit/product_registry_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'product_registry_test.dart' show InstantRepository;

/// Instant publishing, plus a scripted answer to "what do you already list?".
class _Repo extends InstantRepository {
  _Repo({super.failing});

  final Map<String, List<CatalogEntry>> listed = {};
  final Set<String> unreachable = {};

  @override
  Future<List<CatalogEntry>> catalog(String platformId) async {
    if (unreachable.contains(platformId)) {
      throw StateError('$platformId is down');
    }
    return listed[platformId] ?? const [];
  }
}

ErpProductModel _erp(
  int id,
  String name,
  double price, {
  int parent = 0,
  int kind = 0,
}) => ErpProductModel(
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
  late ProductRegistryCubit registry;
  late ProductSyncRepository sync;
  late _Repo repo;
  late AppPreferences prefs;
  var now = DateTime(2026, 10, 18, 12);

  AutoPublisher publisher({int perRun = 25}) => AutoPublisher(
    repository: repo,
    registry: registry,
    preferences: prefs,
    perRun: perRun,
    clock: () => now,
  );

  final catalog = [
    _erp(1, 'Burgers', 0, kind: 1),
    _erp(2, 'Beef Burger', 25, parent: 1),
    _erp(3, 'Chicken Burger', 22, parent: 1),
    _erp(10, 'إضافات', 0, kind: 1),
    _erp(11, 'بطاطا زيادة', 3, parent: 10),
  ];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await AppPreferences.create();
    database = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    sync = ProductSyncRepository(database.db);
    registry = ProductRegistryCubit(
      ProductRecordsRepository(database.db),
      sync,
    );
    await registry.load();
    repo = _Repo();
    now = DateTime(2026, 10, 18, 12);
  });

  tearDown(() async {
    await registry.close();
    await database.close();
  });

  test(
    'a new product goes to every platform, in the category of its group, with its price remembered',
    () async {
      final report = await publisher().run(catalog);

      expect(
        [for (final e in report.added) e.name],
        ['Beef Burger', 'Chicken Burger'],
      );
      expect(repo.sent.where((s) => s.$1 == '2').map((s) => s.$2).toSet(), {
        'keeta',
        'hungerstation',
      });
      // The Keeta listing is in the group's category; the add-on group came along.
      final keeta = repo.calls.firstWhere(
        (c) => c.$1.sku == '2' && c.$2.platformId == 'keeta',
      );
      expect(keeta.$2.category, 'Burgers');
      expect(
        registry.state.isOnAll(
          '2',
          ProductPublishRepository.supportedPlatforms,
        ),
        isTrue,
      );
      expect(
        ProductSyncRepository.lookup(
          await sync.all(),
          '2',
          'keeta',
        )?.priceMinor,
        2500,
      );
      // Groups and add-on items are not products.
      expect(
        repo.sent.any((s) => s.$1 == '1' || s.$1 == '10' || s.$1 == '11'),
        isFalse,
      );
    },
  );

  test(
    'nothing is added blind: if a platform cannot say what it lists, nothing is sent',
    () async {
      repo.unreachable.add('hungerstation');

      final report = await publisher().run(catalog);

      expect(report.platformsUnreachable, isTrue);
      expect(report.entries, isEmpty);
      expect(repo.sent, isEmpty);
    },
  );

  test(
    'products already on a platform are left alone; only the missing platform is filled',
    () async {
      repo.listed['keeta'] = [
        const CatalogEntry(sku: '2', name: 'Beef Burger', platformNum: '9002'),
      ];

      await publisher().run(catalog);

      final forBeef = repo.sent
          .where((s) => s.$1 == '2')
          .map((s) => s.$2)
          .toList();
      expect(forBeef, ['hungerstation'], reason: 'it is already on Keeta');
      expect(repo.sent.where((s) => s.$1 == '3'), hasLength(2));
    },
  );

  test(
    'a product with no price, or no group and no fallback category, is skipped and said so',
    () async {
      final report = await publisher().run([
        ...catalog,
        _erp(20, 'Free sample', 0, parent: 1),
        _erp(21, 'Loose item', 9),
      ]);

      final skipped = {
        for (final e in report.entries.where((e) => e.skipped)) e.name: e.error,
      };
      expect(skipped['Free sample'], contains('price'));
      expect(skipped['Loose item'], contains('category'));
      expect(repo.sent.any((s) => s.$1 == '20' || s.$1 == '21'), isFalse);
    },
  );

  test(
    'the fallback category saved from the manual dialog lets a group-less product through',
    () async {
      await prefs.setBulkDefaults(
        keetaCategory: 'General',
        hsCategory: '',
        barcodeFromSku: true,
      );

      final report = await publisher().run([
        ...catalog,
        _erp(21, 'Loose item', 9),
      ]);

      expect(report.added.map((e) => e.name), contains('Loose item'));
      final listing = repo.calls.firstWhere(
        (c) => c.$1.sku == '21' && c.$2.platformId == 'keeta',
      );
      expect(listing.$2.category, 'General');
    },
  );

  test(
    'a refusal is reported, and not retried every run: only after the wait',
    () async {
      repo = _Repo(failing: {'hungerstation'});

      final first = await publisher().run([catalog[0], catalog[1]]);
      expect(first.failed.single.name, 'Beef Burger');
      expect(first.failed.single.error, contains('hungerstation'));

      // The same publisher, a few minutes later: it does not hammer the platform.
      final publisherWithMemory = publisher();
      await publisherWithMemory.run([catalog[0], catalog[1]]);
      repo.sent.clear();
      now = now.add(const Duration(minutes: 5));
      final soon = await publisherWithMemory.run([catalog[0], catalog[1]]);
      expect(soon.entries, isEmpty);
      expect(repo.sent, isEmpty);

      now = now.add(const Duration(minutes: 40));
      await publisherWithMemory.run([catalog[0], catalog[1]]);
      expect(repo.sent, isNotEmpty, reason: 'long enough: it tries again');
    },
  );

  test('a big catalog trickles in: at most perRun products per run', () async {
    final many = [
      catalog[0],
      for (var i = 100; i < 108; i++) _erp(i, 'Item $i', 5, parent: 1),
    ];
    final report = await publisher(perRun: 3).run(many);
    expect(report.added, hasLength(3));

    final next = await publisher(perRun: 3).run(many);
    expect(
      next.added,
      hasLength(3),
      reason: 'the next run takes the next three',
    );
  });
}
