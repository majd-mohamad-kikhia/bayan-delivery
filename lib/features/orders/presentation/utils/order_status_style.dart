import 'package:flutter/material.dart';

import '../config/platform_board_config.dart';

/// Action labels/icons. Status labels/colors live on each [PlatformBoardConfig].
class OrderStatusStyle {
  const OrderStatusStyle._();

  static const Map<String, String> _actionLabels = {
    'accept': 'Accept',
    'ready': 'Mark ready',
    'collect': 'Handoff',
    'dispatch': 'Dispatch',
    'cancel': 'Cancel',
    'agree': 'Agree refund',
    'reject': 'Reject refund',
  };

  static const Map<String, IconData> _actionIcons = {
    'accept': Icons.check_circle_outline,
    'ready': Icons.inventory_2_outlined,
    'collect': Icons.handshake_outlined,
    'dispatch': Icons.delivery_dining_outlined,
    'cancel': Icons.cancel_outlined,
    'agree': Icons.thumb_up_outlined,
    'reject': Icons.thumb_down_outlined,
  };

  static String label(String status, {required String platform}) =>
      PlatformBoards.of(platform).labelFor(status);

  static Color color(String status, {required String platform}) =>
      PlatformBoards.of(platform).colorFor(status);

  static String actionLabel(String action, {String? platform}) {
    if (platform == 'keeta' && action == 'accept') return 'Confirm';
    return _actionLabels[action] ?? action;
  }

  static IconData actionIcon(String action) =>
      _actionIcons[action] ?? Icons.touch_app_outlined;

  /// Actions that require a reason dialog before firing.
  static bool requiresReason(String action) =>
      action == 'cancel' || action == 'reject';
}
