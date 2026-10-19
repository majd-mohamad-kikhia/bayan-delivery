import 'package:flutter/material.dart';

/// One kanban column on a platform board.
///
/// The displayed title is resolved from [status] via `OrdersStrings.statusLabel`.
class BoardColumn {
  const BoardColumn({
    required this.status,
    required this.color,
    this.alsoStatuses = const {},
    this.titleKey,
  });

  final String status;
  final Color color;

  /// Further statuses shown in this column (the merged "All" board).
  final Set<String> alsoStatuses;

  /// Set on merged columns: title comes from `OrdersStrings.columnTitle`
  /// instead of the status label.
  final String? titleKey;

  bool holds(String s) => s == status || alsoStatuses.contains(s);
}

/// Board layout + status colors for a single delivery platform.
///
/// Each platform owns its active columns and which statuses count as history,
/// so Keeta / HungerStation can diverge without shared assumptions.
class PlatformBoardConfig {
  const PlatformBoardConfig({
    required this.platformId,
    required this.activeColumns,
    required this.terminalStatuses,
    this.statusColors = const {},
  });

  final String platformId;
  final List<BoardColumn> activeColumns;
  final Set<String> terminalStatuses;
  final Map<String, Color> statusColors;

  bool isTerminal(String status) => terminalStatuses.contains(status);

  Color colorFor(String status) {
    for (final column in activeColumns) {
      if (column.holds(status)) return column.color;
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
      BoardColumn(status: 'NEW_ORDER', color: Color(0xFF3D5AFE)),
      BoardColumn(status: 'ORDER_ACCEPTED', color: Color(0xFF7C4DFF)),
      BoardColumn(status: 'ORDER_READY', color: Color(0xFFFB8C00)),
      BoardColumn(status: 'ORDER_PICKED_UP', color: Color(0xFF06B6D4)),
      BoardColumn(status: 'ORDER_DISPATCHED', color: Color(0xFF00ACC1)),
      BoardColumn(status: 'REFUND_REQUESTED', color: Color(0xFFF59E0B)),
      BoardColumn(status: 'CANCELLATION_REQUESTED', color: Color(0xFFF97316)),
      BoardColumn(status: 'ORDER_CANCELLED', color: Color(0xFFFF6B6B)),
    ],
    terminalStatuses: {'ORDER_DELIVERED', 'ORDER_COMPLETED'},
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
      BoardColumn(status: 'NEW_ORDER', color: Color(0xFF3D5AFE)),
      BoardColumn(status: 'ORDER_READY', color: Color(0xFFFB8C00)),
      BoardColumn(status: 'ORDER_DISPATCHED', color: Color(0xFF00ACC1)),
      BoardColumn(status: 'ORDER_CANCELLED', color: Color(0xFFFF6B6B)),
    ],
    terminalStatuses: {'ORDER_COMPLETED'},
    statusColors: {
      'ORDER_COMPLETED': Color(0xFF22C55E),
      'ORDER_ACCEPTED': Color(0xFF7C4DFF),
    },
  );

  /// Every platform on one board. Statuses that mean the same thing to the
  /// staff share a column, so there are 5 instead of up to 8:
  /// New → Preparing → End process (ready / picked up / out for delivery),
  /// plus Needs attention (refund / cancellation requests) and Cancelled.
  static const all = PlatformBoardConfig(
    platformId: 'all',
    activeColumns: [
      BoardColumn(status: 'NEW_ORDER', color: Color(0xFF3D5AFE)),
      BoardColumn(
        status: 'ORDER_ACCEPTED',
        color: Color(0xFF7C4DFF),
        titleKey: 'preparing',
      ),
      BoardColumn(
        status: 'ORDER_READY',
        alsoStatuses: {'ORDER_PICKED_UP', 'ORDER_DISPATCHED'},
        color: Color(0xFFFB8C00),
        titleKey: 'endProcess',
      ),
      BoardColumn(
        status: 'REFUND_REQUESTED',
        alsoStatuses: {'CANCELLATION_REQUESTED'},
        color: Color(0xFFF59E0B),
        titleKey: 'attention',
      ),
      BoardColumn(status: 'ORDER_CANCELLED', color: Color(0xFFFF6B6B)),
    ],
    terminalStatuses: {'ORDER_DELIVERED', 'ORDER_COMPLETED'},
    statusColors: {
      'ORDER_DELIVERED': Color(0xFF22C55E),
      'ORDER_COMPLETED': Color(0xFF22C55E),
    },
  );

  static PlatformBoardConfig of(String platform) {
    switch (platform) {
      case 'all':
        return all;
      case 'hungerstation':
        return hungerstation;
      case 'keeta':
      default:
        return keeta;
    }
  }
}
