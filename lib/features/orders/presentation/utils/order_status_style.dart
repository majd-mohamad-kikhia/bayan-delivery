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
  };

  static Color color(String status, {required String platform}) =>
      PlatformBoards.of(platform).colorFor(status);

  static IconData actionIcon(String action) =>
      _actionIcons[action] ?? Icons.touch_app_outlined;

  /// Actions that require a reason dialog before firing.
  static bool requiresReason(String action) =>
      action == 'cancel' || action == 'reject';
}
