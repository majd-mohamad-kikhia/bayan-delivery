import '../../../../core/storage/app_preferences.dart';
import '../../../bayan_erp/data/models/erp_product_model.dart';
import '../../data/erp_product_adapter.dart';
import '../../data/platform_reconcile.dart';
import '../../data/repositories/product_publish_repository.dart';
import 'bulk_publish_cubit.dart';
import 'product_registry_cubit.dart';

/// One product the automatic add handled.
final class AutoAddEntry {
  const AutoAddEntry({
    required this.bayanNum,
    required this.name,
    required this.at,
    this.error,
    this.skipped = false,
  });

  final String bayanNum;
  final String name;
  final DateTime at;

  /// Why it did not go through (a refusal, or what is missing).
  final String? error;

  /// Left alone on purpose (no category, no price), not a platform failure.
  final bool skipped;

  bool get ok => error == null && !skipped;
}

final class AutoAddReport {
  const AutoAddReport({
    this.entries = const [],
    this.platformsUnreachable = false,
  });

  final List<AutoAddEntry> entries;

  /// A platform could not be asked what it already lists, so nothing was added
  /// (adding blind could create duplicates).
  final bool platformsUnreachable;

  List<AutoAddEntry> get added => [
    for (final e in entries)
      if (e.ok) e,
  ];
  List<AutoAddEntry> get failed => [
    for (final e in entries)
      if (e.error != null && !e.skipped) e,
  ];
}

/// Puts new Al-Bayan products on the platforms without anyone pressing the
/// button: the same add as "Add to all platforms", run in the background.
///
/// Guard rails, because this publishes to live menus:
/// - the platforms are asked what they already list first, and nothing is
///   added if one cannot be reached (no duplicates from a blind add);
/// - an item goes into the Keeta category named after its Al-Bayan group; with
///   no group it needs the fallback category saved from the manual dialog,
///   otherwise it is left alone and reported;
/// - items without a price are left alone (a platform refuses them);
/// - at most [perRun] items per run, so a big catalog trickles in;
/// - an item a platform refused is not retried for [retryAfter].
class AutoPublisher {
  AutoPublisher({
    required this.repository,
    required this.registry,
    required this.preferences,
    this.perRun = 25,
    this.retryAfter = const Duration(minutes: 30),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final ProductPublishRepository repository;
  final ProductRegistryCubit registry;
  final AppPreferences preferences;
  final int perRun;
  final Duration retryAfter;
  final DateTime Function() _clock;

  /// When each item was last refused.
  final Map<String, DateTime> _failedAt = {};

  Future<AutoAddReport> run(List<ErpProductModel> catalog) async {
    if (catalog.isEmpty) return const AutoAddReport();
    final now = _clock();

    final reconcile = await reconcilePlatformsWith(repository, registry);
    if (!reconcile.reachable) {
      return const AutoAddReport(platformsUnreachable: true);
    }

    final byId = {for (final p in catalog) p.id: p};
    final parents = {for (final p in catalog) p.parentId};
    final addOns = addOnsOf(catalog);
    bool isGroup(ErpProductModel p) =>
        p.kind != null ? p.kind == 1 : parents.contains(p.id);

    final fallback = preferences.bulkKeetaCategory.trim();
    final entries = <AutoAddEntry>[];
    final batch = <ErpProductModel>[];
    final categoryOf = <int, String>{};

    for (final p in catalog) {
      if (isGroup(p) || addOns.excluded.contains(p.id)) continue;
      if (registry.state.isOnAll(
        '${p.id}',
        ProductPublishRepository.supportedPlatforms,
      )) {
        continue;
      }

      final failedAt = _failedAt['${p.id}'];
      if (failedAt != null && now.difference(failedAt) < retryAfter) continue;

      final name = p.name.trim().isEmpty ? '#${p.id}' : p.name.trim();
      if (erpSalePrice(p) <= 0) {
        entries.add(
          AutoAddEntry(
            bayanNum: '${p.id}',
            name: name,
            at: now,
            skipped: true,
            error: 'no price in Al-Bayan',
          ),
        );
        continue;
      }
      final parent = byId[p.parentId];
      final group = parent != null && isGroup(parent) ? parent.name.trim() : '';
      if (group.isEmpty && fallback.isEmpty) {
        entries.add(
          AutoAddEntry(
            bayanNum: '${p.id}',
            name: name,
            at: now,
            skipped: true,
            error: 'no group, so no category',
          ),
        );
        continue;
      }
      categoryOf[p.id] = group;
      if (batch.length < perRun) batch.add(p);
    }
    if (batch.isEmpty) return AutoAddReport(entries: entries);

    final cubit = BulkPublishCubit(repository: repository, registry: registry);
    try {
      final models = [
        for (final p in batch)
          publishableFromErp(
            p,
            category: categoryOf[p.id] ?? '',
            addOnGroups: addOns.groups,
          ),
      ];
      await cubit.run(
        models,
        BulkDefaults(
          keetaCategory: fallback,
          hungerStationCategory: preferences.bulkHsCategory.trim(),
          barcodeFromSku: preferences.bulkBarcodeFromSku,
        ),
      );
      final failures = cubit.state.failures;
      for (var i = 0; i < batch.length; i++) {
        final p = batch[i];
        final name = p.name.trim().isEmpty ? '#${p.id}' : p.name.trim();
        // The failures name the product as the publish flow knows it.
        final mine = [
          for (final f in failures)
            if (f.productName == models[i].name) f,
        ];
        if (mine.isEmpty) {
          _failedAt.remove('${p.id}');
          entries.add(AutoAddEntry(bayanNum: '${p.id}', name: name, at: now));
        } else {
          _failedAt['${p.id}'] = now;
          entries.add(
            AutoAddEntry(
              bayanNum: '${p.id}',
              name: name,
              at: now,
              error: [
                for (final f in mine)
                  '${f.platformId}: ${f.outcome.detail ?? f.outcome.notice.name}',
              ].join(' · '),
            ),
          );
        }
      }
    } finally {
      await cubit.close();
    }
    return AutoAddReport(entries: entries);
  }
}
