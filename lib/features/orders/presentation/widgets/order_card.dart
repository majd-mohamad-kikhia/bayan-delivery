import 'package:flutter/material.dart';

import '../../../../core/localization/locale_context.dart';
import '../../../../core/theme/platform_colors.dart';
import '../../../../core/utils/time_ago.dart';
import '../../data/models/order_model.dart';
import '../l10n/orders_strings.dart';
import '../utils/order_status_style.dart';
import 'order_action_runner.dart';
import 'order_detail_dialog.dart';
import 'platform_badge.dart';

class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
    required this.isActionPending,
    required this.onAction,
    this.neutralLabels = false,
  });

  final OrderModel order;
  final bool isActionPending;

  /// Merged "All" board: one wording for steps that differ per platform
  /// (Confirm/Accept, Hand over/Dispatch).
  final bool neutralLabels;
  final void Function(
    String action, {
    String? reason,
    Map<String, Object?>? payload,
  })
  onAction;

  Future<void> _handleAction(BuildContext context, String action) =>
      runOrderAction(context, order: order, action: action, onAction: onAction);

  @override
  Widget build(BuildContext context) {
    final platformColor = PlatformColors.of(order.platform);
    return RepaintBoundary(
      child: GestureDetector(
        onTap: () => showOrderDetailDialog(context, order),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            children: [
              _buildCard(context),
              // Platform colour stripe: tells Keeta / HungerStation apart at a glance.
              Positioned.fill(
                right: null,
                child: SizedBox(
                  width: 5,
                  child: ColoredBox(color: platformColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    return Container(
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
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
            child: _CardBody(order: order),
          ),
          if (order.availableActions.isNotEmpty) ...[
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            if (isActionPending)
              const _PendingIndicator()
            else
              _ActionsRow(
                platform: neutralLabels ? 'all' : order.platform,
                actions: order.availableActions,
                onAction: (action) => _handleAction(context, action),
              ),
          ],
        ],
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
    final s = context.ordersStrings;
    final common = context.commonStrings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row 1: platform badge + urgent flag + time
        Row(
          children: [
            Flexible(child: PlatformBadge(platform: order.platform)),
            if (order.isSelfDelivery) ...[
              const SizedBox(width: 6),
              const _SelfDeliveryChip(),
            ],
            const Spacer(),
            if (order.requiresUrgentAction) ...[
              const Icon(
                Icons.priority_high,
                size: 13,
                color: Color(0xFFFF6B6B),
              ),
              const SizedBox(width: 3),
            ],
            Text(
              timeAgo(order.updatedAt, common),
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
            Flexible(
              child: Text(
                '#${order.orderCode ?? order.platformOrderId}',
                textDirection: TextDirection.ltr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (order.orderTotal != null)
              Text(
                common.money(order.orderTotal!),
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
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (order.itemCount != null)
                Text(
                  s.itemCount(order.itemCount!),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF94A3B8),
                  ),
                ),
            ],
          ),
        ],
        // Discount the customer got
        if (order.discountTotal > 0) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.sell_outlined,
                size: 12,
                color: Color(0xFF16A34A),
              ),
              const SizedBox(width: 4),
              Text(
                '${s.discount} −${common.money(order.discountTotal)}',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF16A34A),
                ),
              ),
            ],
          ),
        ],
        // Cancellation reason
        if (order.cancellationReason != null) ...[
          const SizedBox(height: 4),
          Text(
            s.reason(order.cancellationReason!),
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

class _SelfDeliveryChip extends StatelessWidget {
  const _SelfDeliveryChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF7C4DFF).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.two_wheeler_rounded,
            size: 12,
            color: Color(0xFF7C4DFF),
          ),
          const SizedBox(width: 3),
          Text(
            context.ordersStrings.selfDeliveryBadge,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF7C4DFF),
            ),
          ),
        ],
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
    final s = context.ordersStrings;
    final primary = [
      for (final a in actions)
        if (!OrderStatusStyle.isSecondary(a)) a,
    ];
    final secondary = [
      for (final a in actions)
        if (OrderStatusStyle.isSecondary(a)) a,
    ];
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (primary.isNotEmpty)
            Row(
              children: [
                for (int i = 0; i < primary.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: _ActionButton(
                      action: primary[i],
                      label: s.actionLabel(primary[i], platform: platform),
                      neutral: platform == 'all',
                      onTap: () => onAction(primary[i]),
                    ),
                  ),
                ],
              ],
            ),
          if (secondary.isNotEmpty) ...[
            if (primary.isNotEmpty) const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final action in secondary)
                  _SecondaryAction(
                    icon: OrderStatusStyle.actionIcon(action),
                    label: s.actionLabel(action, platform: platform),
                    onTap: () => onAction(action),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SecondaryAction extends StatelessWidget {
  const _SecondaryAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: const Color(0xFF64748B)),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.action,
    required this.label,
    required this.onTap,
    this.neutral = false,
  });

  final String action;
  final String label;
  final bool neutral;
  final VoidCallback onTap;

  static const _destructive = {'cancel', 'reject'};

  @override
  Widget build(BuildContext context) {
    final isDestructive = _destructive.contains(action);
    final color = isDestructive
        ? const Color(0xFFFF6B6B)
        : const Color(0xFF3D5AFE);
    final bg = isDestructive
        ? const Color(0xFFFFF1F1)
        : const Color(0xFFF0F3FF);

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
            Icon(
              OrderStatusStyle.actionIcon(
                neutral && action == 'collect' ? 'dispatch' : action,
              ),
              size: 13,
              color: color,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
