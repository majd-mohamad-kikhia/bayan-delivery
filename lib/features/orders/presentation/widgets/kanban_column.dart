import 'package:flutter/material.dart';

import '../../data/models/order_model.dart';
import 'order_card.dart';

class KanbanColumn extends StatelessWidget {
  const KanbanColumn({
    super.key,
    required this.title,
    required this.accentColor,
    required this.orders,
    required this.isActionPending,
    required this.onAction,
  });

  final String title;
  final Color accentColor;
  final List<OrderModel> orders;
  final bool Function(OrderModel order) isActionPending;
  final void Function(OrderModel order, String action, {String? reason}) onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ColumnHeader(title: title, accentColor: accentColor, count: orders.length),
          Expanded(
            child: orders.isEmpty
                ? const _EmptyColumn()
                : ListView.separated(
                    padding: const EdgeInsets.all(10),
                    itemCount: orders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      return OrderCard(
                        key: ValueKey('${order.platform}:${order.platformOrderId}'),
                        order: order,
                        isActionPending: isActionPending(order),
                        onAction: (action, {reason}) =>
                            onAction(order, action, reason: reason),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader({
    required this.title,
    required this.accentColor,
    required this.count,
  });

  final String title;
  final Color accentColor;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyColumn extends StatelessWidget {
  const _EmptyColumn();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 28, color: Colors.grey.shade300),
          const SizedBox(height: 6),
          Text(
            'No orders',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
