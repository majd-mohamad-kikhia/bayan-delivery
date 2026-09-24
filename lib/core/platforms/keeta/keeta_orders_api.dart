import '../common/platform_endpoint.dart';
import '../common/platform_utils.dart';
import 'keeta_client.dart';
import 'keeta_endpoints.dart';
import 'keeta_response.dart';
import 'keeta_types.dart';

/// Keeta Order API. Every call is scoped by `shopId` + `orderViewId`
/// (the id inside the webhook `message`).
class KeetaOrdersApi {
  const KeetaOrdersApi(this._client);

  final KeetaClient _client;

  /// `data.orderInfo` holds the order.
  Future<Map<String, dynamic>> details({
    required int shopId,
    required int orderViewId,
  }) async =>
      (await _send(KeetaEndpoints.orderDetails, shopId, orderViewId)).dataMap;

  /// Accepts a new order — within 5 minutes of webhook 1001, or Keeta
  /// cancels it automatically.
  Future<KeetaResponse> confirm({
    required int shopId,
    required int orderViewId,
  }) => _send(KeetaEndpoints.confirmOrder, shopId, orderViewId);

  /// Food is ready (feeds Keeta's preparation-time metrics).
  Future<KeetaResponse> markReady({
    required int shopId,
    required int orderViewId,
  }) => _send(KeetaEndpoints.orderReady, shopId, orderViewId);

  /// Pickup orders only: the customer collected it. Optional — Keeta closes
  /// the order itself after a timeout.
  Future<KeetaResponse> confirmPickup({
    required int shopId,
    required int orderViewId,
  }) => _send(KeetaEndpoints.confirmPickup, shopId, orderViewId);

  /// Cancels the whole order. Money-sensitive: never retried automatically.
  Future<KeetaResponse> cancel({
    required int shopId,
    required int orderViewId,
    required KeetaCancelCode code,
    String? reason,
  }) {
    _checkReason(code.requiresReason, reason, 'cancelReason');
    return _send(KeetaEndpoints.cancelOrder, shopId, orderViewId, {
      'cancelCode': code.code,
      'cancelReason': reason,
    });
  }

  /// Approves the customer's refund request (webhook 1005). Unanswered
  /// requests go to Keeta support after 15 minutes.
  Future<KeetaResponse> agreeRefund({
    required int shopId,
    required int orderViewId,
  }) => _send(KeetaEndpoints.agreeRefund, shopId, orderViewId);

  Future<KeetaResponse> rejectRefund({
    required int shopId,
    required int orderViewId,
    required KeetaRefundRejectCode code,
    String? reason,
  }) {
    _checkReason(code.requiresReason, reason, 'rejectReason');
    return _send(KeetaEndpoints.rejectRefund, shopId, orderViewId, {
      'rejectCode': code.code,
      'rejectReason': reason,
    });
  }

  /// Step 1 of a partial refund: which items (and amounts) are refundable.
  /// With no [items], Keeta lists every refundable item with amount 0.
  Future<Map<String, dynamic>> previewPartialRefund({
    required int shopId,
    required int orderViewId,
    List<KeetaRefundItem> items = const [],
  }) async =>
      (await _send(KeetaEndpoints.previewPartialRefund, shopId, orderViewId, {
        if (items.isNotEmpty)
          'products': [for (final item in items) item.toJson()],
      })).dataMap;

  /// Step 2 of a partial refund.
  Future<KeetaResponse> applyPartialRefund({
    required int shopId,
    required int orderViewId,
    required List<KeetaRefundItem> items,
    required KeetaPartialRefundReason reason,
    String? note,
  }) {
    checkArgument(items.isNotEmpty, 'items', 'at least one item is required');
    _checkReason(reason.requiresReason, note, 'partRefundReason');
    return _send(KeetaEndpoints.applyPartialRefund, shopId, orderViewId, {
      'products': [for (final item in items) item.toJson()],
      'partRefundType': reason.code,
      'partRefundReason': note,
    });
  }

  Future<KeetaResponse> _send(
    PlatformEndpoint endpoint,
    int shopId,
    int orderViewId, [
    Map<String, Object?> extra = const {},
  ]) => _client.send(
    endpoint,
    params: {'shopId': shopId, 'orderViewId': orderViewId, ...extra},
  );

  static void _checkReason(bool required, String? text, String field) =>
      checkArgument(
        !required || (text != null && text.trim().isNotEmpty),
        field,
        'is required for the "other" reason code',
        text,
      );
}
