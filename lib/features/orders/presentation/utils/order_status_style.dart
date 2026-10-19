import 'package:flutter/material.dart';

import '../config/platform_board_config.dart';

/// Status colors and action icons. Labels live in `OrdersStrings`.
class OrderStatusStyle {
  const OrderStatusStyle._();

  static const Map<String, IconData> _actionIcons = {
    'accept': Icons.check_circle_outline,
    'ready': Icons.inventory_2_outlined,
    'collect': Icons.handshake_outlined,
    'dispatch': Icons.delivery_dining_outlined,
    'cancel': Icons.cancel_outlined,
    'agree': Icons.thumb_up_outlined,
    'reject': Icons.thumb_down_outlined,
    'selfDispatch': Icons.two_wheeler_rounded,
    'selfDeliver': Icons.task_alt_rounded,
    'courier': Icons.badge_outlined,
    'partialRefund': Icons.payments_outlined,
  };

  static const Map<String, IconData> _columnIcons = {
    'NEW_ORDER': Icons.notifications_none_rounded,
    'ORDER_ACCEPTED': Icons.soup_kitchen_outlined,
    'ORDER_READY': Icons.inventory_2_outlined,
    'ORDER_PICKED_UP': Icons.delivery_dining_outlined,
    'ORDER_DISPATCHED': Icons.delivery_dining_outlined,
    'REFUND_REQUESTED': Icons.task_alt_rounded,
    'CANCELLATION_REQUESTED': Icons.task_alt_rounded,
    'ORDER_CANCELLED': Icons.block_rounded,
  };

  /// Illustration for a column's empty state.
  static IconData columnIcon(String status) =>
      _columnIcons[status] ?? Icons.inbox_outlined;

  static Color color(String status, {required String platform}) =>
      PlatformBoards.of(platform).colorFor(status);

  static IconData actionIcon(String action) =>
      _actionIcons[action] ?? Icons.touch_app_outlined;

  /// Actions that require a reason dialog before firing.
  /// Secondary actions: smaller, in their own row under the main buttons.
  static bool isSecondary(String action) =>
      action == 'courier' || action == 'partialRefund';

  static bool requiresReason(String action) =>
      action == 'cancel' || action == 'reject';
}
