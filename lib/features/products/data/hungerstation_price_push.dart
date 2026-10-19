import '../../../core/platforms/platforms.dart';

/// Sends new prices to HungerStation (by SKU = the Al-Bayan product number) in
/// batches and waits for its catalog job. Returns the SKUs it did not accept;
/// a job that is still running after the wait counts as accepted.
Future<Set<String>> pushHungerStationPrices(
  PlatformApis apis,
  List<({String sku, double price})> updates, {
  Duration wait = const Duration(seconds: 20),
}) async {
  final failed = <String>{};
  const batchSize = 500;
  for (var i = 0; i < updates.length; i += batchSize) {
    final batch = updates.sublist(i, (i + batchSize).clamp(0, updates.length));
    try {
      final job = await apis.hungerStation.updateProducts(
        products: [
          for (final u in batch) HsProductUpdate(sku: u.sku, price: u.price),
        ],
      );
      final result = job.id.isEmpty
          ? job
          : await apis.hungerStation.waitForCatalogJob(job.id, timeout: wait);
      if (result.isFailed) {
        failed.addAll(batch.map((u) => u.sku));
      } else {
        for (final u in batch) {
          if (result.rejectionFor(u.sku) != null) failed.add(u.sku);
        }
      }
    } catch (_) {
      failed.addAll(batch.map((u) => u.sku));
    }
  }
  return failed;
}
