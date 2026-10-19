import '../../data/models/order_model.dart';
import '../config/platform_board_config.dart';

/// What dragging an order card into another column means.
///
/// Nothing here decides which moves are allowed: a drop is valid only when
/// the move is one of the order's own `availableActions` (what the backend
/// says it may do now). This file only knows which column each action leads to.

/// The status an action leaves the order in.
const _resultOf = <String, String>{
  'accept': 'ORDER_ACCEPTED',
  'ready': 'ORDER_READY',
  'collect': 'ORDER_PICKED_UP',
  'dispatch': 'ORDER_DISPATCHED',
  'cancel': 'ORDER_CANCELLED',
};

/// Tried in this order when several actions lead into the same column.
/// Actions that need a form first (our own courier, refunds) are not here:
/// they stay buttons on the card.
const _dragActions = ['accept', 'ready', 'dispatch', 'collect', 'cancel'];

/// The action that moves [order] into [target], or null when that move is
/// not possible (so the column refuses the drop).
String? dragActionFor(
  OrderModel order,
  BoardColumn target,
  PlatformBoardConfig board,
) {
  // Already there.
  if (target.holds(order.status)) return null;
  for (final action in _dragActions) {
    if (!order.availableActions.contains(action)) continue;
    final result = _resultOf[action];
    if (result != null && target.holds(result)) return action;
  }
  return null;
}
