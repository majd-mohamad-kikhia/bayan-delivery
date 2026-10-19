import 'package:bayan_desktop/features/orders/data/models/order_model.dart';
import 'package:bayan_desktop/features/orders/presentation/bloc/orders_state.dart';
import 'package:bayan_desktop/features/orders/presentation/utils/orders_date_filter.dart';
import 'package:flutter_test/flutter_test.dart';

OrderModel _order(String id, String status, DateTime createdAt) => OrderModel(
      platform: 'keeta',
      platformOrderId: id,
      dongleNumber: 'D',
      status: status,
      availableActions: const [],
      transportType: null,
      requiresUrgentAction: false,
      createdAt: createdAt,
      updatedAt: createdAt,
      rawOrder: const {},
    );

void main() {
  final now = DateTime.now();
  final yesterday = now.subtract(const Duration(days: 1));

  test('counts the new orders of the chosen days: what sits in the first column', () {
    final state = OrdersState(orders: [
      _order('1', 'NEW_ORDER', now),
      _order('2', 'NEW_ORDER', now),
      _order('3', 'ORDER_ACCEPTED', now), // already accepted
      _order('4', 'NEW_ORDER', yesterday), // outside "today"
    ]);

    expect(state.pendingNewOrders, 2);
    expect(state.copyWith(dateFilter: const OrdersDateFilter(OrdersDatePreset.last7Days)).pendingNewOrders, 3);
  });

  test('is zero once every order is accepted, so the alert stops', () {
    final state = OrdersState(orders: [_order('1', 'ORDER_ACCEPTED', now), _order('2', 'ORDER_CANCELLED', now)]);
    expect(state.pendingNewOrders, 0);
  });

  test('the mute switch is part of the state', () {
    expect(const OrdersState().alertMuted, isFalse);
    expect(const OrdersState().copyWith(alertMuted: true).alertMuted, isTrue);
  });
}
