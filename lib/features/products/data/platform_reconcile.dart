import '../presentation/cubit/product_registry_cubit.dart';
import 'repositories/product_publish_repository.dart';

/// What the platforms say they list, applied to the local registry: products
/// they list are marked as there; products recorded as there but no longer
/// listed are marked as not there. A platform that cannot be reached changes
/// nothing for itself (its answer is unknown), and `reachable` is then false.
Future<({bool reachable, int matched, int removed, List<String> failed})>
reconcilePlatformsWith(
  ProductPublishRepository repository,
  ProductRegistryCubit registry,
) async {
  // Each platform is asked independently: one being down doesn't lose
  // what the other said.
  final results = await Future.wait([
    for (final platform in ProductPublishRepository.supportedPlatforms)
      repository
          .catalog(platform)
          .then<(String, List<CatalogEntry>?, Object?)>(
            (e) => (platform, e, null),
          )
          .catchError((Object e) => (platform, null, e)),
  ]);

  final marks = <RegistryMark>[];
  final failed = <String>[];
  // Per platform that answered: the Al-Bayan numbers it really lists.
  final listed = <String, Set<String>>{};
  for (final (platform, entries, error) in results) {
    if (entries == null) {
      failed.add('$platform ($error)');
      continue;
    }
    listed[platform] = {};
    for (final entry in entries) {
      // Al-Bayan product ids are numbers; skip anything else on the platform.
      if (int.tryParse(entry.sku) == null) continue;
      listed[platform]!.add(entry.sku);
      marks.add(
        RegistryMark(
          entry.sku,
          entry.name ?? entry.sku,
          platform,
          entry.platformNum ?? entry.sku,
        ),
      );
    }
  }
  await registry.markAll(marks);
  // A platform that answered is the truth: anything we recorded as being
  // there that it does not list is no longer there.
  var removed = 0;
  for (final entry in listed.entries) {
    removed += await registry.forgetUnlisted(entry.key, entry.value);
  }
  return (
    reachable: failed.isEmpty,
    matched: marks.length,
    removed: removed,
    failed: failed,
  );
}
