import 'package:flutter/material.dart';

import '../../../../core/utils/time_ago.dart';
import '../../data/models/order_model.dart';
import '../utils/order_status_style.dart';
import 'cancel_reason_dialog.dart';
import 'order_detail_dialog.dart';
import 'platform_badge.dart';

class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
    required this.isActionPending,
    required this.onAction,
  });

  final OrderModel order;
  final bool isActionPending;
  final void Function(String action, {String? reason}) onAction;

  Future<void> _handleAction(BuildContext context, String action) async {
    if (OrderStatusStyle.requiresReason(action)) {
      final isReject = action == 'reject';
      final reason = await showCancelReasonDialog(
        context,
        orderId: order.orderCode ?? order.platformOrderId,
        title: isReject ? 'Reject Refund?' : 'Cancel Order?',
        confirmLabel: isReject ? 'Reject Refund' : 'Cancel Order',
      );
      if (reason == null) return;
      onAction(action, reason: reason);
      return;
    }
    onAction(action);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showOrderDetailDialog(context, order),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: order.requiresUrgentAction
                ? const Color(0xFFFF6B6B)
                : const Color(0xFFE2E8F0),
            width: order.requiresUrgentAction ? 1.5 : 1,
          ),
          boxShadow: const [
            BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: _CardBody(order: order),
            ),
            if (order.availableActions.isNotEmpty) ...[
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              if (isActionPending)
                const _PendingIndicator()
              else
                _ActionsRow(
                  platform: order.platform,
                  actions: order.availableActions,
                  onAction: (action) => _handleAction(context, action),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Card body ──────────────────────────────────────────────────────────────────

class _CardBody extends StatelessWidget {
  const _CardBody({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row 1: platform badge + urgent flag + time
        Row(
          children: [
            PlatformBadge(platform: order.platform),
            const Spacer(),
            if (order.requiresUrgentAction) ...[
              const Icon(Icons.priority_high, size: 13, color: Color(0xFFFF6B6B)),
              const SizedBox(width: 3),
            ],
            Text(
              timeAgo(order.updatedAt),
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Row 2: order # + amount
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '#${order.orderCode ?? order.platformOrderId}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const Spacer(),
            if (order.orderTotal != null)
              Text(
                'SAR ${order.orderTotal!.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
          ],
        ),
        // Row 3: customer + item count
        if (order.customerName != null || order.itemCount != null) ...[
          const SizedBox(height: 3),
          Row(
            children: [
              if (order.customerName != null)
                Expanded(
                  child: Text(
                    order.customerName!,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (order.itemCount != null)
                Text(
                  '${order.itemCount} item${order.itemCount == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
            ],
          ),
        ],
        // Cancellation reason
        if (order.cancellationReason != null) ...[
          const SizedBox(height: 4),
          Text(
            'Reason: ${order.cancellationReason}',
            style: const TextStyle(fontSize: 12, color: Color(0xFFFF6B6B)),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

// ── Actions ────────────────────────────────────────────────────────────────────

class _PendingIndicator extends StatelessWidget {
  const _PendingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _ActionsRow extends StatelessWidget {
  const _ActionsRow({
    required this.platform,
    required this.actions,
    required this.onAction,
  });

  final String platform;
  final List<String> actions;
  final void Function(String action) onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          for (int i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: _ActionButton(
                platform: platform,
                action: actions[i],
                onTap: () => onAction(actions[i]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.platform,
    required this.action,
    required this.onTap,
  });

  final String platform;
  final String action;
  final VoidCallback onTap;

  static const _destructive = {'cancel', 'reject'};

  @override
  Widget build(BuildContext context) {
    final isDestructive = _destructive.contains(action);
    final color = isDestructive ? const Color(0xFFFF6B6B) : const Color(0xFF3D5AFE);
    final bg = isDestructive ? const Color(0xFFFFF1F1) : const Color(0xFFF0F3FF);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(OrderStatusStyle.actionIcon(action), size: 13, color: color),
            const SizedBox(width: 5),
            Text(
              OrderStatusStyle.actionLabel(action, platform: platform),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
