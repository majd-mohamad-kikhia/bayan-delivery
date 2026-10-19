import '../../bayan_erp/data/models/erp_product_model.dart';
import 'erp_product_adapter.dart';
import 'models/product_record.dart';
import 'repositories/product_records_repository.dart';
import 'repositories/product_sync_repository.dart';

/// One value sent (or attempted) to one platform.
final class SyncChange {
  const SyncChange({
    required this.bayanNum,
    required this.name,
    required this.platform,
    required this.at,
    required this.ok,
    this.oldPriceMinor,
    this.newPriceMinor,
    this.oldName,
    this.newName,
    this.error,
  });

  final String bayanNum;
  final String name;
  final String platform;
  final DateTime at;
  final bool ok;
  final int? oldPriceMinor;
  final int? newPriceMinor;
  final String? oldName;
  final String? newName;
  final String? error;

  bool get priceChanged =>
      newPriceMinor != null && newPriceMinor != oldPriceMinor;
  bool get nameChanged => newName != null && newName != oldName;
}

final class SyncReport {
  const SyncReport({
    required this.at,
    this.changes = const [],
    this.newProducts = const [],
    this.catalog = const [],
    this.baselined = 0,
    this.error,
  });

  final DateTime at;
  final List<SyncChange> changes;

  /// Al-Bayan items that are on no platform yet.
  final List<ErpProductModel> newProducts;

  /// The whole catalog this run read (names the groups, holds the add-ons).
  final List<ErpProductModel> catalog;

  /// Products seen for the first time (their current price became the baseline).
  final int baselined;

  /// The whole run failed (Al-Bayan unreachable, say).
  final String? error;

  int get sent => changes.where((c) => c.ok).length;
  int get failed => changes.where((c) => !c.ok).length;
}

/// Pushes to Keeta: by Keeta product id; returns the ids that were not accepted.
typedef KeetaPush =
    Future<Set<int>> Function(
      List<({int spuId, double? price, String? name})> changes,
    );

/// Pushes prices to HungerStation: by SKU; returns the SKUs that were not accepted.
typedef HungerStationPush =
    Future<Set<String>> Function(List<({String sku, double price})> changes);

/// Keeps the platforms in step with Al-Bayan.
///
/// Each run reads the Al-Bayan catalog and, for every product that is on a
/// platform, compares its price (and name, on Keeta) with what was last sent
/// there. A difference is pushed; success is remembered so it is not sent
/// again, failure is retried on the next run. A product seen for the first
/// time only gets a baseline: nothing is sent for something never compared.
///
/// Items that are on no platform yet are reported, never added on their own:
/// putting a product on a menu needs a category and a decision.
class PlatformSyncService {
  PlatformSyncService({
    required this.loadCatalog,
    required this.records,
    required this.state,
    required this.pushKeeta,
    required this.pushHungerStation,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Future<List<ErpProductModel>> Function() loadCatalog;
  final ProductRecordsRepository records;
  final ProductSyncRepository state;
  final KeetaPush pushKeeta;
  final HungerStationPush pushHungerStation;

  final DateTime Function() _clock;

  Future<SyncReport> run() async {
    final started = _clock();
    final List<ErpProductModel> catalog;
    try {
      catalog = await loadCatalog();
    } catch (e) {
      return SyncReport(at: started, error: '$e');
    }
    // An empty catalog is never read as "everything was deleted".
    if (catalog.isEmpty) return SyncReport(at: started);

    final erp = {for (final p in catalog) '${p.id}': p};
    final recordMap = await records.all();
    final known = await state.all();

    final baselines =
        <({String bayanNum, String platform, SyncedValues values})>[];
    final keetaWork =
        <
          ({ProductRecord record, ErpProductModel product, SyncedValues prior})
        >[];
    final hsWork =
        <
          ({ProductRecord record, ErpProductModel product, SyncedValues prior})
        >[];
    final nameOnly =
        <({String bayanNum, String platform, SyncedValues values})>[];

    for (final record in recordMap.values) {
      final product = erp[record.bayanNum];
      if (product == null) continue;
      final current = SyncedValues(
        priceMinor: erpSalePriceMinor(product),
        name: product.name.trim(),
      );
      for (final (platform, number, work) in [
        ('keeta', record.keetaNum, keetaWork),
        ('hungerstation', record.hungerNum, hsWork),
      ]) {
        if (number == null) continue;
        final prior = ProductSyncRepository.lookup(
          known,
          record.bayanNum,
          platform,
        );
        if (prior == null) {
          baselines.add((
            bayanNum: record.bayanNum,
            platform: platform,
            values: current,
          ));
          continue;
        }
        final priceChanged = prior.priceMinor != current.priceMinor;
        final nameChanged =
            current.name.isNotEmpty && prior.name != current.name;
        if (platform == 'keeta'
            ? (priceChanged || nameChanged)
            : priceChanged) {
          work.add((record: record, product: product, prior: prior));
        } else if (nameChanged) {
          // HungerStation cannot rename through this API: note it, send nothing.
          nameOnly.add((
            bayanNum: record.bayanNum,
            platform: platform,
            values: current,
          ));
        }
      }
    }
    if (baselines.isNotEmpty) await state.save(baselines, replace: false);
    if (nameOnly.isNotEmpty) await state.save(nameOnly);

    final changes = <SyncChange>[];
    changes.addAll(await _pushKeeta(keetaWork));
    changes.addAll(await _pushHs(hsWork));

    return SyncReport(
      at: started,
      changes: changes,
      newProducts: _newProducts(catalog, recordMap),
      catalog: catalog,
      baselined: baselines.length,
    );
  }

  Future<List<SyncChange>> _pushKeeta(
    List<({ProductRecord record, ErpProductModel product, SyncedValues prior})>
    work,
  ) async {
    if (work.isEmpty) return const [];
    final now = _clock();
    final updates = <({int spuId, double? price, String? name})>[];
    final byId =
        <
          int,
          ({ProductRecord record, ErpProductModel product, SyncedValues prior})
        >{};
    final changes = <SyncChange>[];

    for (final w in work) {
      final spuId = int.tryParse(w.record.keetaNum ?? '');
      final current = SyncedValues(
        priceMinor: erpSalePriceMinor(w.product),
        name: w.product.name.trim(),
      );
      if (spuId == null) {
        changes.add(
          _change(
            w,
            'keeta',
            current,
            now,
            ok: false,
            error: 'Keeta number is not a product id',
          ),
        );
        continue;
      }
      updates.add((
        spuId: spuId,
        price: w.prior.priceMinor != current.priceMinor
            ? current.priceMinor / 100
            : null,
        name: current.name.isNotEmpty && w.prior.name != current.name
            ? current.name
            : null,
      ));
      byId[spuId] = w;
    }

    Set<int> failed;
    String? error;
    try {
      failed = await pushKeeta(updates);
    } catch (e) {
      failed = byId.keys.toSet();
      error = '$e';
    }

    final accepted =
        <({String bayanNum, String platform, SyncedValues values})>[];
    for (final entry in byId.entries) {
      final w = entry.value;
      final current = SyncedValues(
        priceMinor: erpSalePriceMinor(w.product),
        name: w.product.name.trim(),
      );
      final ok = !failed.contains(entry.key);
      changes.add(
        _change(
          w,
          'keeta',
          current,
          now,
          ok: ok,
          error: ok ? null : (error ?? 'Keeta did not accept the change'),
        ),
      );
      if (ok) {
        accepted.add((
          bayanNum: w.record.bayanNum,
          platform: 'keeta',
          values: current,
        ));
      }
    }
    if (accepted.isNotEmpty) await state.save(accepted);
    return changes;
  }

  Future<List<SyncChange>> _pushHs(
    List<({ProductRecord record, ErpProductModel product, SyncedValues prior})>
    work,
  ) async {
    if (work.isEmpty) return const [];
    final now = _clock();
    final updates = [
      for (final w in work)
        (sku: w.record.bayanNum, price: erpSalePriceMinor(w.product) / 100),
    ];

    Set<String> failed;
    String? error;
    try {
      failed = await pushHungerStation(updates);
    } catch (e) {
      failed = {for (final u in updates) u.sku};
      error = '$e';
    }

    final changes = <SyncChange>[];
    final accepted =
        <({String bayanNum, String platform, SyncedValues values})>[];
    for (final w in work) {
      final current = SyncedValues(
        priceMinor: erpSalePriceMinor(w.product),
        name: w.product.name.trim(),
      );
      final ok = !failed.contains(w.record.bayanNum);
      changes.add(
        _change(
          w,
          'hungerstation',
          current,
          now,
          ok: ok,
          error: ok
              ? null
              : (error ?? 'HungerStation did not accept the change'),
        ),
      );
      if (ok) {
        accepted.add((
          bayanNum: w.record.bayanNum,
          platform: 'hungerstation',
          values: current,
        ));
      }
    }
    if (accepted.isNotEmpty) await state.save(accepted);
    return changes;
  }

  SyncChange _change(
    ({ProductRecord record, ErpProductModel product, SyncedValues prior}) w,
    String platform,
    SyncedValues current,
    DateTime at, {
    required bool ok,
    String? error,
  }) => SyncChange(
    bayanNum: w.record.bayanNum,
    name: w.product.name.trim().isEmpty ? w.record.name : w.product.name.trim(),
    platform: platform,
    at: at,
    ok: ok,
    oldPriceMinor: w.prior.priceMinor,
    newPriceMinor: current.priceMinor,
    oldName: w.prior.name,
    newName: current.name,
    error: error,
  );

  /// Items (not groups, not add-ons) that are on no platform yet.
  static List<ErpProductModel> _newProducts(
    List<ErpProductModel> catalog,
    Map<String, ProductRecord> recordMap,
  ) {
    final parents = {for (final p in catalog) p.parentId};
    final excluded = addOnsOf(catalog).excluded;
    bool isGroup(ErpProductModel p) =>
        p.kind != null ? p.kind == 1 : parents.contains(p.id);
    return [
      for (final p in catalog)
        if (!isGroup(p) &&
            !excluded.contains(p.id) &&
            !_onAPlatform(recordMap['${p.id}']))
          p,
    ];
  }

  static bool _onAPlatform(ProductRecord? r) =>
      r != null &&
      (r.keetaNum != null || r.hungerNum != null || r.careemNum != null);
}
