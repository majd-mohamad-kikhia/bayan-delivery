import '../../../../core/network/api_client.dart';
import '../datasources/orders_local_datasource.dart';
import '../models/order_model.dart';

/// One order line as the platform reports it for a partial refund.
class RefundableLine {
  const RefundableLine({
    required this.orderProductId,
    required this.name,
    required this.count,
    required this.refunded,
    required this.unitPrice,
  });

  final int orderProductId;
  final String name;

  /// Pieces bought.
  final int count;

  /// Pieces already refunded.
  final int refunded;
  final double unitPrice;

  int get refundable => (count - refunded).clamp(0, count);
}

class OrdersRepository {
  OrdersRepository(this._apiClient, [this._local]);

  final ApiClient _apiClient;

  /// Null = no on-device cache (tests).
  final OrdersLocalDatasource? _local;

  /// What is stored on this device — for instant display before (or without)
  /// the network.
  Future<List<OrderModel>> cachedOrders({
    required String dongleNumber,
    String? platform,
  }) =>
      _local?.list(dongleNumber: dongleNumber, platform: platform) ??
      Future.value(const []);

  Future<DateTime?> cachedSyncedAt({required String dongleNumber}) =>
      _local?.lastSyncedAt(dongleNumber: dongleNumber) ?? Future.value();

  Future<List<OrderModel>> fetchOrders({
    required String dongleNumber,
    String? platform,
  }) async {
    final data = await _apiClient.get(
      '/api/orders',
      query: {'dongleNumber': dongleNumber, 'platform': ?platform},
    );
    final list = (data['orders'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    final orders = list.map(OrderModel.fromJson).toList();
    await _local?.saveAll(orders);
    return orders;
  }

  /// Which lines of a Keeta order can still be refunded.
  Future<List<RefundableLine>> previewPartialRefund({
    required String platformOrderId,
    required String dongleNumber,
  }) async {
    final data = await _apiClient.post(
      '/api/orders/keeta/$platformOrderId/refund/preview',
      data: {'dongleNumber': dongleNumber},
    );
    final products = data['products'];
    return [
      for (final p in (products is List ? products : const []).whereType<Map>())
        if (p['id'] is num)
          RefundableLine(
            orderProductId: (p['id'] as num).toInt(),
            name: '${p['name'] ?? ''}',
            count: (p['count'] as num?)?.toInt() ?? 1,
            refunded: (p['refundedCount'] as num?)?.toInt() ?? 0,
            unitPrice: double.tryParse('${p['price']}') ?? 0,
          ),
    ];
  }

  Future<OrderModel> performAction({
    required String platform,
    required String platformOrderId,
    required String action,
    required String dongleNumber,
    String? reason,
    Map<String, Object?>? payload,
  }) async {
    // The backend keeps no database; hand it the state we have on disk so an
    // action still works after the backend restarted.
    final known = await _local?.find(platform, platformOrderId);
    final data = await _apiClient.post(
      '/api/orders/$platform/$platformOrderId/actions/$action',
      data: {
        'dongleNumber': dongleNumber,
        if (known != null) 'status': known.status,
        if (known?.transportType != null) 'transportType': known!.transportType,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
        'payload': ?payload,
      },
    );
    final order = OrderModel.fromJson(
      (data['order'] as Map).cast<String, dynamic>(),
    );
    await _local?.upsert(order);
    return order;
  }
}
