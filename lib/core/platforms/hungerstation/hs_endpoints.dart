import '../common/delivery_platform.dart';
import '../common/http_method.dart';
import '../common/platform_endpoint.dart';

/// Every HungerStation Partner API operation —
/// https://developer.hungerstation.com/api-specifications
///
/// `{chain_id}` is filled from the credentials; `{vendor_id}` from the call
/// or the default outlet. Base URL depends on `HsEnvironment`.
abstract final class HsEndpoints {
  /// Form-encoded `client_credentials` grant. Limited to 50 requests/min
  /// per client_id — tokens are cached, never fetched per call.
  static const token = _Hs(
    'auth.token',
    HttpMethod.post,
    '/v2/oauth/token',
    requiresAuth: false,
  );

  // ── Outlet ────────────────────────────────────────────────────────────────

  static const outletStatus = _Hs(
    'outlet.status',
    HttpMethod.get,
    '/v2/chains/{chain_id}/vendors/{vendor_id}/status',
    isRead: true,
  );
  static const updateOutletStatus = _Hs(
    'outlet.updateStatus',
    HttpMethod.put,
    '/v2/chains/{chain_id}/vendors/{vendor_id}/status',
  );

  // ── Catalog (write endpoints are async: they return a job_id) ─────────────

  static const products = _Hs(
    'catalog.products',
    HttpMethod.get,
    '/v2/chains/{chain_id}/vendors/{vendor_id}/catalog',
    isRead: true,
  );

  /// Price / active / quantity. Batch thousands of SKUs in one call.
  static const updateProducts = _Hs(
    'catalog.update',
    HttpMethod.put,
    '/v2/chains/{chain_id}/vendors/{vendor_id}/catalog',
    timeout: Duration(seconds: 30),
  );

  /// BETA — needs account-manager approval before production use.
  static const addProducts = _Hs(
    'catalog.add',
    HttpMethod.post,
    '/v2/chains/{chain_id}/catalog',
    timeout: Duration(seconds: 30),
  );
  static const catalogJob = _Hs(
    'catalog.job',
    HttpMethod.get,
    '/v2/chains/{chain_id}/catalog/jobs/{job_id}',
    isRead: true,
  );

  /// Result (CSV URL) is delivered to the configured webhook.
  static const exportCatalog = _Hs(
    'catalog.export',
    HttpMethod.post,
    '/v2/chains/{chain_id}/vendors/{vendor_id}/catalog/export',
  );
  static const categories = _Hs(
    'catalog.categories',
    HttpMethod.get,
    '/v2/chains/{chain_id}/vendors/{vendor_id}/categories',
    isRead: true,
  );

  // ── Promotions ────────────────────────────────────────────────────────────

  static const upsertPromotion = _Hs(
    'promotion.upsert',
    HttpMethod.put,
    '/v2/chains/{chain_id}/promotion',
  );
  static const promotionJob = _Hs(
    'promotion.job',
    HttpMethod.get,
    '/v2/chains/{chain_id}/promotion/jobs/{job_id}',
    isRead: true,
  );

  static const List<PlatformEndpoint> all = [
    token,
    outletStatus,
    updateOutletStatus,
    products,
    updateProducts,
    addProducts,
    catalogJob,
    exportCatalog,
    categories,
    upsertPromotion,
    promotionJob,
  ];
}

final class _Hs extends PlatformEndpoint {
  const _Hs(
    String id,
    HttpMethod method,
    String path, {
    super.isRead,
    super.requiresAuth,
    super.timeout,
  }) : super(
         'hungerstation.$id',
         platform: DeliveryPlatform.hungerStation,
         method: method,
         path: path,
       );
}
