import '../../../../core/network/api_client.dart';
import '../models/hs_vendor_status_model.dart';
import '../models/keeta_shop_model.dart';
import '../models/keeta_shop_status_model.dart';

/// Merchants API — live proxies via Al-Bayan middleware (guide sections 7–8).
class MerchantsRepository {
  MerchantsRepository(this._api);

  final ApiClient _api;

  // ── Keeta ──────────────────────────────────────────────────────────────────

  Future<List<KeetaShopModel>> fetchKeetaShops({
    required String dongleNumber,
  }) async {
    final data = await _api.get(
      '/api/merchants/keeta/shops',
      query: {
        'dongleNumber': dongleNumber,
        'allPages': 'true',
      },
    );
    final list = data['shops'] as List? ?? const [];
    return list
        .whereType<Map>()
        .map((e) => KeetaShopModel.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<KeetaShopStatusModel> fetchKeetaShopStatus({
    required String dongleNumber,
    required int shopId,
  }) async {
    final data = await _api.get(
      '/api/merchants/keeta/$shopId/status',
      query: {'dongleNumber': dongleNumber},
    );
    return KeetaShopStatusModel.fromJson(data);
  }

  Future<void> updateKeetaShopStatus({
    required String dongleNumber,
    required int shopId,
    required bool available,
  }) async {
    await _api.post(
      '/api/merchants/keeta/$shopId/status',
      data: {
        'dongleNumber': dongleNumber,
        'merchantStatus': available ? 'AVAILABLE' : 'UNAVAILABLE',
      },
    );
  }

  Future<void> updateKeetaShopHours({
    required String dongleNumber,
    required int shopId,
    required List<Map<String, dynamic>> services,
  }) async {
    await _api.post(
      '/api/merchants/keeta/$shopId/hours',
      data: {
        'dongleNumber': dongleNumber,
        'services': services,
      },
    );
  }

  // ── HungerStation ──────────────────────────────────────────────────────────

  Future<HsVendorStatusModel> fetchHsVendorStatus({
    required String dongleNumber,
    String? vendorId,
  }) async {
    final path = vendorId == null || vendorId.isEmpty
        ? '/api/merchants/hungerstation/status'
        : '/api/merchants/hungerstation/$vendorId/status';
    final data = await _api.get(path, query: {'dongleNumber': dongleNumber});
    return HsVendorStatusModel.fromJson(data);
  }

  Future<HsVendorStatusModel> updateHsVendorStatus({
    required String dongleNumber,
    required String vendorId,
    required String status,
    String? closedReason,
    DateTime? closedUntil,
  }) async {
    final body = <String, dynamic>{
      'dongleNumber': dongleNumber,
      'status': status,
      if (closedReason != null) 'closed_reason': closedReason,
      if (closedUntil != null) 'closed_until': closedUntil.toUtc().toIso8601String(),
    };
    // ApiClient only has get/post — use Dio put via post path won't work.
    // Add put to ApiClient.
    final data = await _api.put(
      '/api/merchants/hungerstation/$vendorId/status',
      data: body,
    );
    return HsVendorStatusModel.fromJson(data);
  }
}
