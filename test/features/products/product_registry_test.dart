import 'dart:async';

import 'package:bayan_desktop/core/database/app_database.dart';
import 'package:bayan_desktop/features/products/data/models/listing_models.dart';
import 'package:bayan_desktop/features/products/data/models/product_model.dart';
import 'package:bayan_desktop/features/products/data/repositories/product_publish_repository.dart';
import 'package:bayan_desktop/features/products/data/repositories/product_records_repository.dart';
import 'package:bayan_desktop/features/products/data/sample_products.dart';
import 'package:bayan_desktop/features/products/presentation/cubit/bulk_publish_cubit.dart';
import 'package:bayan_desktop/features/products/presentation/cubit/product_registry_cubit.dart';
import 'package:bayan_desktop/features/products/presentation/cubit/publish_product_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'publish_product_cubit_test.dart' show ManualRepository;

/// Answers every publish immediately: [failing] platforms fail, the rest
/// succeed with a platform number.
class InstantRepository extends ManualRepository {
  InstantRepository({this.failing = const {}});

  final Set<String> failing;
  final List<(String sku, String platform)> sent = [];

  @override
  Future<PublishOutcome> publish(ListingContent content, PlatformListing listing) async {
    sent.add((content.sku, listing.platformId));
    calls.add((content, listing));
    if (failing.contains(listing.platformId)) {
      return const PublishOutcome.failed(PublishNotice.barcodeRequired);
    }
    return PublishOutcome(
      PublishPhase.published,
      PublishNotice.added,
      null,
      'p-${listing.platformId}-${content.sku}',
    );
  }
}

ProductModel product(String sku, {double price = 10}) => ProductModel(
  id: 'erp-$sku',
  sku: sku,
  name: 'Product $sku',
  nameAr: '',
  category: '',
  unit: '',
  salePrice: price,
  costPrice: 0,
  stockQty: 5,
  isActive: true,
);

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase database;
  late ProductRecordsRepository records;
  late ProductRegistryCubit registry;

  setUp(() async {
    database = await AppDatabase.open(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    records = ProductRecordsRepository(database.db);
    registry = ProductRegistryCubit(records);
    await registry.load();
  });

  tearDown(() async {
    await registry.close();
    await database.close();
  });

  group('registry', () {
    test('remembers a published product and survives a reload', () async {
      await registry.markPublished(
        bayanNum: '7',
        name: 'Bread',
        platformId: 'keeta',
        platformNum: '9001',
      );
      expect(registry.state.isRegistered('7', 'keeta'), isTrue);
      expect(registry.state.isRegistered('7', 'hungerstation'), isFalse);

      final reloaded = ProductRegistryCubit(records);
      await reloaded.load();
      expect(reloaded.state.recordOf('7')!.keetaNum, '9001');
      await reloaded.close();
    });

    test('a second platform merges instead of replacing the first', () async {
      await registry.markAll(const [
        RegistryMark('7', 'Bread', 'keeta', '9001'),
        RegistryMark('7', 'Bread', 'hungerstation', '7'),
      ]);
      final r = registry.state.recordOf('7')!;
      expect((r.keetaNum, r.hungerNum), ('9001', '7'));
      expect(registry.state.isOnAll('7', ['keeta', 'hungerstation']), isTrue);
    });

    test('a sync with only the number does not erase a real name', () async {
      await registry.markPublished(
        bayanNum: '7',
        name: 'Arabic Bread',
        platformId: 'keeta',
        platformNum: '1',
      );
      await registry.markAll(const [RegistryMark('7', '7', 'hungerstation', '7')]);
      expect(registry.state.recordOf('7')!.name, 'Arabic Bread');
    });
  });

  group('publishing one product', () {
    test('registers only the platforms that went live', () async {
      final repository = ManualRepository();
      final cubit = PublishProductCubit(
        product: sampleProducts.first,
        repository: repository,
        registry: registry,
      )..selectAllPlatforms();
      final done = cubit.submit();
      await Future<void>.delayed(Duration.zero);
      repository.answer(
        'keeta',
        const PublishOutcome(PublishPhase.published, PublishNotice.added, null, '555'),
      );
      repository.answer('hungerstation', const PublishOutcome.failed(PublishNotice.rejected));
      await done;
      await Future<void>.delayed(const Duration(milliseconds: 50)); // the registry write is async

      final sku = sampleProducts.first.sku;
      expect(registry.state.recordOf(sku)!.keetaNum, '555');
      expect(registry.state.isRegistered(sku, 'hungerstation'), isFalse);
      await cubit.close();
    });
  });

  group('bulk add', () {
    const defaults = BulkDefaults(keetaCategory: 'Grocery');

    test('adds what is missing, skips what is there, reports failures', () async {
      await registry.markAll(const [
        RegistryMark('1', 'Product 1', 'keeta', 'k1'),
        RegistryMark('1', 'Product 1', 'hungerstation', 'h1'),
        RegistryMark('2', 'Product 2', 'keeta', 'k2'),
      ]);
      final repository = InstantRepository(failing: {'hungerstation'});
      final cubit = BulkPublishCubit(repository: repository, registry: registry);

      await cubit.run([product('1'), product('2'), product('3')], defaults);

      // 1 is on every platform; 2 only needs HungerStation; 3 needs both.
      expect(repository.sent.toSet(), {
        ('2', 'hungerstation'),
        ('3', 'keeta'),
        ('3', 'hungerstation'),
      });
      expect(cubit.state.status, BulkStatus.done);
      expect((cubit.state.total, cubit.state.done, cubit.state.skipped), (2, 2, 1));
      expect(cubit.state.added, 1); // only 3 on Keeta
      expect(cubit.state.failures, hasLength(2));
      expect(registry.state.isRegistered('3', 'keeta'), isTrue);
      expect(registry.state.isRegistered('3', 'hungerstation'), isFalse);
      await cubit.close();
    });

    test('sends the chosen category and the product number as barcode', () async {
      final repository = InstantRepository();
      final cubit = BulkPublishCubit(repository: repository, registry: registry);
      await cubit.run([product('42')], defaults);

      final keeta = repository.calls.firstWhere((c) => c.$2.platformId == 'keeta');
      expect(keeta.$2.category, 'Grocery');
      expect(keeta.$1.barcode, '42');
      await cubit.close();
    });

    test('stop prevents the products that have not started', () async {
      final repository = InstantRepository();
      final cubit = BulkPublishCubit(
        repository: repository,
        registry: registry,
        concurrency: 1,
      );
      final run = cubit.run([for (var i = 1; i <= 5; i++) product('$i')], defaults);
      cubit.cancel();
      await run;
      expect(cubit.state.done, lessThan(5));
      await cubit.close();
    });
  });

  group('platform catalog parsing', () {
    test('Keeta: finds every openItemCode however deeply nested', () {
      final entries = ProductPublishRepository.parseKeetaCatalog({
        'list': [
          {
            'id': 111,
            'name': 'Bread',
            'openItemCode': '7',
            'skuList': [
              {'id': 999, 'openItemCode': '7', 'price': 5},
            ],
          },
          {
            'id': 222,
            'openItemCode': '8',
            'skuList': [<String, Object>{}],
          },
          {'id': 333, 'name': 'No code'},
        ],
      });
      expect(entries.map((e) => e.sku).toSet(), {'7', '8'});
      expect(entries.firstWhere((e) => e.sku == '7').platformNum, '111');
      expect(entries.firstWhere((e) => e.sku == '7').name, 'Bread');
    });

    test('HungerStation: reads sku and a localized title', () {
      final entries = ProductPublishRepository.parseHsCatalog({
        'products': [
          {'sku': '7', 'title': {'en_SA': 'Bread'}},
          {'sku': ' 8 ', 'title': 'Milk'},
          {'title': 'no sku'},
        ],
      });
      expect(entries.map((e) => (e.sku, e.name)), [('7', 'Bread'), ('8', 'Milk')]);
    });

    test('unknown shapes give an empty list, not an error', () {
      expect(ProductPublishRepository.parseKeetaCatalog(null), isEmpty);
      expect(ProductPublishRepository.parseHsCatalog('nope'), isEmpty);
    });
  });
}
