import '../common/platform_endpoint.dart';
import '../common/platform_utils.dart';
import 'hs_auth.dart';
import 'hs_client.dart';
import 'hs_endpoints.dart';
import 'hs_types.dart';

/// Typed access to every HungerStation Partner API operation.
///
/// `vendorId` defaults to the configured outlet (`HS_VENDOR_ID`).
///
/// ```dart
/// final hs = context.read<PlatformApis>().hungerStation;
/// await hs.updateOutletStatus(status: HsOutletStatus.closedToday, reason: HsClosedReason.tooBusyKitchen);
/// final job = await hs.updateProducts(products: [HsProductUpdate(sku: 'SKU1', active: false)]);
/// ```
class HungerStationApi {
  HungerStationApi({required this.client}) : auth = client.auth;

  final HsClient client;
  final HsAuth auth;

  static const Duration _maxPollDelay = Duration(seconds: 8);

  // ── Outlet ────────────────────────────────────────────────────────────────

  /// `{ vendor_id, status, closed_reason?, closed_until? }`.
  Future<Map<String, dynamic>> outletStatus({String? vendorId}) async => _map(
    await client.send(HsEndpoints.outletStatus, pathParams: _vendor(vendorId)),
  );

  /// [reason] is required when closing; [closedUntil] only (and always) with
  /// [HsOutletStatus.closedUntil]. `OPEN` only takes effect inside the
  /// scheduled opening hours.
  Future<Map<String, dynamic>> updateOutletStatus({
    required HsOutletStatus status,
    HsClosedReason? reason,
    DateTime? closedUntil,
    String? vendorId,
  }) async {
    checkArgument(
      status != HsOutletStatus.closed,
      'status',
      'CLOSED is read-only; use closedToday or closedUntil',
    );
    checkArgument(
      !status.isClosing || reason != null,
      'reason',
      'is required when closing the outlet',
    );
    checkArgument(
      (status == HsOutletStatus.closedUntil) == (closedUntil != null),
      'closedUntil',
      'is required with, and only with, CLOSED_UNTIL',
    );
    return _map(
      await client.send(
        HsEndpoints.updateOutletStatus,
        pathParams: _vendor(vendorId),
        params: {
          'status': status.wire,
          'closed_reason': reason?.wire,
          'closed_until': closedUntil == null ? null : _utcIso(closedUntil),
        },
      ),
    );
  }

  // ── Catalog ───────────────────────────────────────────────────────────────

  /// Search by name / SKU / barcode, filter by category and active state.
  Future<Map<String, dynamic>> products({
    String? vendorId,
    String? query,
    List<String> categoryIds = const [],
    bool? isActive,
    int? page,
    int? pageSize,
  }) async => _map(
    await client.send(
      HsEndpoints.products,
      pathParams: _vendor(vendorId),
      params: {
        'query_term': query,
        if (categoryIds.isNotEmpty) 'category_global_ids': categoryIds,
        'is_active': isActive,
        'page': page,
        'page_size': pageSize,
      },
    ),
  );

  /// Price / availability / stock. Async — returns the job; prefer one call
  /// with thousands of SKUs over many small calls.
  Future<HsJob> updateProducts({
    required List<HsProductUpdate> products,
    String? vendorId,
  }) async {
    checkArgument(products.isNotEmpty, 'products', 'must not be empty');
    for (final product in products) {
      checkArgument(
        product.hasChange,
        'products',
        '${product.sku}: needs price, active or quantity',
      );
    }
    return HsJob.fromJson(
      await client.send(
        HsEndpoints.updateProducts,
        pathParams: _vendor(vendorId),
        params: {
          'products': [for (final product in products) product.toJson()],
        },
      ),
    );
  }

  /// BETA (account-manager approval required). [vendorIds] `['*']` = every
  /// vendor of the chain. Products follow HungerStation's schema (`sku`,
  /// localized `title`/`description`, `barcodes`, `images`, `categories`, `price`).
  Future<HsJob> addProducts({
    required List<Map<String, Object?>> products,
    List<String> vendorIds = const ['*'],
  }) async {
    checkArgument(products.isNotEmpty, 'products', 'must not be empty');
    return HsJob.fromJson(
      await client.send(
        HsEndpoints.addProducts,
        params: {'vendors': vendorIds, 'products': products},
      ),
    );
  }

  Future<HsJob> catalogJob(String jobId) async => HsJob.fromJson(
    await client.send(HsEndpoints.catalogJob, pathParams: {'job_id': jobId}),
  );

  /// Polls until the job completes, fails, or [timeout] passes (then the
  /// last seen state is returned — check [HsJob.isFinished]).
  Future<HsJob> waitForCatalogJob(
    String jobId, {
    Duration timeout = const Duration(minutes: 2),
  }) => _waitFor(HsEndpoints.catalogJob, jobId, timeout);

  /// Async; the CSV download URL is delivered to the configured webhook.
  Future<Map<String, dynamic>> exportCatalog({String? vendorId}) async => _map(
    await client.send(HsEndpoints.exportCatalog, pathParams: _vendor(vendorId)),
  );

  /// `{ categories: [{ global_id, details, parent_global_id, active }] }`.
  /// [onlyLeaves] false also returns parents (linked by `parent_global_id`).
  Future<Map<String, dynamic>> categories({
    String? vendorId,
    bool onlyLeaves = true,
  }) async => _map(
    await client.send(
      HsEndpoints.categories,
      pathParams: _vendor(vendorId),
      params: {'only_leaves': onlyLeaves},
    ),
  );

  // ── Promotions ────────────────────────────────────────────────────────────

  /// `STRIKETHROUGH` / `SAME_ITEM_BUNDLE` promotions on SKUs. Async.
  Future<HsJob> upsertPromotion(Map<String, Object?> promotion) async =>
      HsJob.fromJson(
        await client.send(HsEndpoints.upsertPromotion, params: promotion),
      );

  Future<HsJob> promotionJob(String jobId) async => HsJob.fromJson(
    await client.send(HsEndpoints.promotionJob, pathParams: {'job_id': jobId}),
  );

  Future<HsJob> waitForPromotionJob(
    String jobId, {
    Duration timeout = const Duration(minutes: 2),
  }) => _waitFor(HsEndpoints.promotionJob, jobId, timeout);

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<HsJob> _waitFor(
    PlatformEndpoint endpoint,
    String jobId,
    Duration timeout,
  ) async {
    final deadline = DateTime.now().add(timeout);
    var delay = const Duration(seconds: 1);
    while (true) {
      final job = HsJob.fromJson(
        await client.send(endpoint, pathParams: {'job_id': jobId}),
      );
      if (job.isFinished || !DateTime.now().add(delay).isBefore(deadline)) {
        return job;
      }
      await Future<void>.delayed(delay);
      delay = delay * 2 > _maxPollDelay ? _maxPollDelay : delay * 2;
    }
  }

  static Map<String, String> _vendor(String? vendorId) =>
      vendorId == null || vendorId.isEmpty ? const {} : {'vendor_id': vendorId};

  static Map<String, dynamic> _map(Object? raw) =>
      raw is Map<String, dynamic> ? raw : const {};

  /// `2024-09-30T10:00:36Z` — ISO 8601 UTC without milliseconds.
  static String _utcIso(DateTime time) =>
      '${time.toUtc().toIso8601String().substring(0, 19)}Z';
}
