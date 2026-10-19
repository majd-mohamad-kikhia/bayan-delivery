import 'package:bayan_desktop/core/database/app_database.dart';
import 'package:bayan_desktop/core/storage/app_preferences.dart';
import 'package:bayan_desktop/features/bayan_erp/data/models/erp_product_model.dart';
import 'package:bayan_desktop/features/products/data/models/listing_models.dart';
import 'package:bayan_desktop/features/products/data/platform_sync_service.dart';
import 'package:bayan_desktop/features/products/data/repositories/product_publish_repository.dart';
import 'package:bayan_desktop/features/products/data/repositories/product_records_repository.dart';
import 'package:bayan_desktop/features/products/data/repositories/product_sync_repository.dart';
import 'package:bayan_desktop/features/products/presentation/cubit/auto_publisher.dart';
import 'package:bayan_desktop/features/products/presentation/cubit/platform_sync_cubit.dart';
import 'package:bayan_desktop/features/products/presentation/cubit/product_registry_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'product_registry_test.dart' show InstantRepository;

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
  late InstantRepository repo;
  late AppPreferences prefs;
  late PlatformSyncCubit cubit;
  var autoSaved = <bool>[];

  final catalog = [
    _erp(1, 'Burgers', 0, kind: 1),
    _erp(2, 'Beef Burger', 25, parent: 1),
  ];

  PlatformSyncCubit build({bool autoAdd = true}) {
    final records = ProductRecordsRepository(database.db);
    final sync = ProductSyncRepository(database.db);
    return PlatformSyncCubit(
      PlatformSyncService(
        loadCatalog: () async => catalog,
        records: records,
        state: sync,
        pushKeeta: (_) async => {},
        pushHungerStation: (_) async => {},
      ),
      autoPublisher: AutoPublisher(
        repository: _Empty(repo),
        registry: registry,
        preferences: prefs,
      ),
      autoAdd: autoAdd,
      onAutoAddChanged: autoSaved.add,
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await AppPreferences.create();
    database = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    registry = ProductRegistryCubit(
      ProductRecordsRepository(database.db),
      ProductSyncRepository(database.db),
    );
    await registry.load();
    repo = InstantRepository();
    autoSaved = [];
  });

  tearDown(() async {
    await cubit.close();
    await registry.close();
    await database.close();
  });

  test(
    'with automatic add on, a sync run puts the new product on the platforms; nothing is left waiting',
    () async {
      cubit = build();
      await cubit.runNow();

      expect(cubit.state.lastAdded, 1);
      expect(
        cubit.state.newProducts,
        isEmpty,
        reason: 'it was added, so it is no longer new',
      );
      expect(cubit.state.autoLog.single.name, 'Beef Burger');
      expect(repo.sent.map((s) => s.$2).toSet(), {'keeta', 'hungerstation'});
    },
  );

  test(
    'with it off, the product waits (and stays listed as new) until the button is used',
    () async {
      cubit = build(autoAdd: false);
      await cubit.runNow();

      expect(cubit.state.lastAdded, 0);
      expect(cubit.state.newProducts.single.name, 'Beef Burger');
      expect(repo.sent, isEmpty);
    },
  );

  test('switching it on is remembered and runs a sync at once', () async {
    cubit = build(autoAdd: false);
    await cubit.runNow();

    cubit.setAutoAdd(true);
    expect(autoSaved, [true]);
    expect(cubit.state.autoAdd, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(repo.sent, isNotEmpty);
  });
}

/// The test repository, answering "what do you list?" with nothing.
class _Empty extends InstantRepository {
  _Empty(this.inner);

  final InstantRepository inner;

  @override
  Future<List<CatalogEntry>> catalog(String platformId) async => const [];

  @override
  Future<PublishOutcome> publish(
    ListingContent content,
    PlatformListing listing,
  ) => inner.publish(content, listing);
}
