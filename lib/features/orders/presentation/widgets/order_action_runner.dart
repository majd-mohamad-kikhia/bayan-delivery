import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/order_model.dart';
import '../../data/repositories/orders_repository.dart';
import '../bloc/orders_bloc.dart';
import '../l10n/orders_strings.dart';
import '../utils/order_status_style.dart';
import 'cancel_reason_dialog.dart';
import 'courier_dialog.dart';
import 'partial_refund_dialog.dart';

/// Runs [action] on [order], first asking for whatever it needs: a reason
/// for cancel / reject, courier details for our own delivery, items for a
/// partial refund. Shared by the card's buttons and by drag and drop, so a
/// dragged card behaves exactly like its button.
Future<void> runOrderAction(
  BuildContext context, {
  required OrderModel order,
  required String action,
  required void Function(
    String action, {
    String? reason,
    Map<String, Object?>? payload,
  })
  onAction,
}) async {
  if (OrderStatusStyle.requiresReason(action)) {
    final isReject = action == 'reject';
    final s = context.ordersStrings;
    final reason = await showCancelReasonDialog(
      context,
      orderId: order.orderCode ?? order.platformOrderId,
      title: isReject ? s.rejectRefundTitle : s.cancelOrderTitle,
      confirmLabel: isReject ? s.rejectRefund : s.cancelOrder,
    );
    if (reason == null) return;
    onAction(action, reason: reason);
    return;
  }
  switch (action) {
    case 'selfDispatch' || 'selfDeliver' || 'courier':
      final mode = switch (action) {
        'selfDispatch' => CourierDialogMode.dispatch,
        'selfDeliver' => CourierDialogMode.deliver,
        _ => CourierDialogMode.update,
      };
      final info = await showCourierDialog(context, mode: mode);
      if (info == null) return;
      onAction(action, payload: {if (info.isNotEmpty) 'courierInfo': info});
    case 'partialRefund':
      final repository = context.read<OrdersRepository>();
      final dongle = context.read<OrdersBloc>().state.dongleNumber;
      final payload = await showPartialRefundDialog(
        context,
        lines: repository.previewPartialRefund(
          platformOrderId: order.platformOrderId,
          dongleNumber: dongle,
        ),
      );
      if (payload == null) return;
      onAction(action, payload: payload);
    default:
      onAction(action);
  }
}
