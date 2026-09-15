import 'package:flutter/material.dart';

/// One kanban column on a platform board.
class BoardColumn {
  const BoardColumn({
    required this.status,
    required this.title,
    required this.color,
  });

  final String status;
  final String title;
  final Color color;
}

/// Board layout + status presentation for a single delivery platform.
///
/// Each platform owns its active columns and which statuses count as history,
/// so Keeta / HungerStation / Careem can diverge without shared assumptions.
class PlatformBoardConfig {
  const PlatformBoardConfig({
    required this.platformId,
    required this.activeColumns,
    required this.terminalStatuses,
    this.statusLabels = const {},
    this.statusColors = const {},
  });

  final String platformId;
  final List<BoardColumn> activeColumns;
  final Set<String> terminalStatuses;
  final Map<String, String> statusLabels;
  final Map<String, Color> statusColors;

  bool isTerminal(String status) => terminalStatuses.contains(status);

  String labelFor(String status) {
    for (final column in activeColumns) {
      if (column.status == status) return column.title;
    }
    return statusLabels[status] ?? status;
  }

  Color colorFor(String status) {
    for (final column in activeColumns) {
      if (column.status == status) return column.color;
    }
    return statusColors[status] ?? const Color(0xFF475569);
  }
}

/// Registry of platform boards. Add a new platform here + a tab entry.
abstract final class PlatformBoards {
  /// Keeta merchant path:
  /// NEW_ORDER → ORDER_ACCEPTED → ORDER_READY → ORDER_PICKED_UP
  /// → ORDER_DISPATCHED → ORDER_DELIVERED → ORDER_COMPLETED
  /// Cancel anytime until READY. Refund: REFUND_REQUESTED → agree/reject.
  static const keeta = PlatformBoardConfig(
    platformId: 'keeta',
    activeColumns: [
      BoardColumn(status: 'NEW_ORDER', title: 'Created', color: Color(0xFF3D5AFE)),
      BoardColumn(status: 'ORDER_ACCEPTED', title: 'Confirmed', color: Color(0xFF7C4DFF)),
      BoardColumn(
        status: 'ORDER_READY',
        title: 'Ready for Pickup',
        color: Color(0xFFFB8C00),
      ),
      BoardColumn(
        status: 'ORDER_PICKED_UP',
        title: 'Picked Up',
        color: Color(0xFF06B6D4),
      ),
      BoardColumn(
        status: 'ORDER_DISPATCHED',
        title: 'Dispatched',
        color: Color(0xFF00ACC1),
      ),
      BoardColumn(
        status: 'REFUND_REQUESTED',
        title: 'Refund Request',
        color: Color(0xFFF59E0B),
      ),
      BoardColumn(
        status: 'CANCELLATION_REQUESTED',
        title: 'Cancel Request',
        color: Color(0xFFF97316),
      ),
      BoardColumn(
        status: 'ORDER_CANCELLED',
        title: 'Cancelled',
        color: Color(0xFFFF6B6B),
      ),
    ],
    terminalStatuses: {'ORDER_DELIVERED', 'ORDER_COMPLETED'},
    statusLabels: {
      'ORDER_DELIVERED': 'Delivered',
      'ORDER_COMPLETED': 'Completed',
      'REFUND_REQUESTED': 'Refund Request',
      'CANCELLATION_REQUESTED': 'Cancel Request',
      'CREATED': 'Created',
      'CONFIRMED': 'Confirmed',
      'READY_FOR_PICKUP': 'Ready for Pickup',
      'PICKED_UP': 'Picked Up',
      'DISPATCHED': 'Dispatched',
      'DELIVERED': 'Delivered',
      'CONCLUDED': 'Completed',
      'CANCELLED': 'Cancelled',
      'USER_REFUND_REQUEST': 'Refund Request',
    },
    statusColors: {
      'ORDER_DELIVERED': Color(0xFF22C55E),
      'ORDER_COMPLETED': Color(0xFF22C55E),
      'REFUND_REQUESTED': Color(0xFFF59E0B),
      'CANCELLATION_REQUESTED': Color(0xFFF97316),
    },
  );

  /// HungerStation: VENDOR ends at Dispatched, LOGISTICS ends at Ready for pickup.
  /// No Accepted step — cancel can happen from New. Cancelled stays on the board.
  static const hungerstation = PlatformBoardConfig(
    platformId: 'hungerstation',
    activeColumns: [
      BoardColumn(status: 'NEW_ORDER', title: 'New', color: Color(0xFF3D5AFE)),
      BoardColumn(
        status: 'ORDER_READY',
        title: 'Ready for pickup',
        color: Color(0xFFFB8C00),
      ),
      BoardColumn(
        status: 'ORDER_DISPATCHED',
        title: 'Dispatched',
        color: Color(0xFF00ACC1),
      ),
      BoardColumn(
        status: 'ORDER_CANCELLED',
        title: 'Cancelled',
        color: Color(0xFFFF6B6B),
      ),
    ],
    terminalStatuses: {'ORDER_COMPLETED'},
    statusLabels: {
      'ORDER_COMPLETED': 'Completed',
      'ORDER_ACCEPTED': 'Accepted',
    },
    statusColors: {
      'ORDER_COMPLETED': Color(0xFF22C55E),
      'ORDER_ACCEPTED': Color(0xFF7C4DFF),
    },
  );

  static const careem = PlatformBoardConfig(
    platformId: 'careem',
    activeColumns: [
      BoardColumn(status: 'NEW_ORDER', title: 'New', color: Color(0xFF3D5AFE)),
      BoardColumn(status: 'ORDER_ACCEPTED', title: 'Accepted', color: Color(0xFF7C4DFF)),
      BoardColumn(status: 'ORDER_READY', title: 'Ready', color: Color(0xFFFB8C00)),
      BoardColumn(status: 'ORDER_DISPATCHED', title: 'Dispatched', color: Color(0xFF00ACC1)),
    ],
    terminalStatuses: {'ORDER_COMPLETED', 'ORDER_CANCELLED'},
    statusLabels: {
      'ORDER_COMPLETED': 'Completed',
      'ORDER_CANCELLED': 'Cancelled',
    },
    statusColors: {
      'ORDER_COMPLETED': Color(0xFF22C55E),
      'ORDER_CANCELLED': Color(0xFFFF6B6B),
    },
  );

  static PlatformBoardConfig of(String platform) {
    switch (platform) {
      case 'hungerstation':
        return hungerstation;
      case 'careem':
        return careem;
      case 'keeta':
      default:
        return keeta;
    }
  }
}
