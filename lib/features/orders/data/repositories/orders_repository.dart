import '../../../../core/network/api_client.dart';
import '../models/order_model.dart';

class OrdersRepository {
  OrdersRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<OrderModel>> fetchOrders({
    required String dongleNumber,
    String? platform,
  }) async {
    final data = await _apiClient.get(
      '/api/orders',
      query: {
        'dongleNumber': dongleNumber,
        if (platform != null) 'platform': platform,
      },
    );
    final list = (data['orders'] as List? ?? const []).cast<Map<String, dynamic>>();
    return list.map(OrderModel.fromJson).toList();
  }

  Future<OrderModel> performAction({
    required String platform,
    required String platformOrderId,
    required String action,
    required String dongleNumber,
    String? reason,
  }) async {
    final data = await _apiClient.post(
      '/api/orders/$platform/$platformOrderId/actions/$action',
      data: {
        'dongleNumber': dongleNumber,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );
    return OrderModel.fromJson((data['order'] as Map).cast<String, dynamic>());
  }
}
