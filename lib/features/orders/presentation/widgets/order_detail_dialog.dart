import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/time_ago.dart';
import '../../data/models/order_model.dart';
import '../utils/order_status_style.dart';
import 'platform_badge.dart';

void showOrderDetailDialog(BuildContext context, OrderModel order) {
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Order detail',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 260),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.93, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
    pageBuilder: (context, _, __) => _OrderDetailDialog(order: order),
  );
}

// ── Dialog shell ───────────────────────────────────────────────────────────────

class _OrderDetailDialog extends StatelessWidget {
  const _OrderDetailDialog({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
        child: Material(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DialogHeader(order: order),
              const Divider(height: 1, color: AppTheme.border),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _MetaRow(order: order),
                      if (order.customerName != null || order.customerPhone != null) ...[
                        const SizedBox(height: 20),
                        _CustomerSection(order: order),
                      ],
                      if (order.items.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _ItemsSection(items: order.items),
                      ],
                      if (order.payment != null) ...[
                        const SizedBox(height: 20),
                        _PaymentSection(payment: order.payment!),
                      ] else if (order.orderTotal != null) ...[
                        const SizedBox(height: 20),
                        _SimpleTotalSection(total: order.orderTotal!),
                      ],
                      if (order.cancellationReason != null) ...[
                        const SizedBox(height: 20),
                        _CancellationSection(reason: order.cancellationReason!),
                      ],
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────────

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final statusColor = OrderStatusStyle.color(order.status, platform: order.platform);
    final statusLabel = OrderStatusStyle.label(order.status, platform: order.platform);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
      child: Row(
        children: [
          PlatformBadge(platform: order.platform),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#${order.orderCode ?? order.platformOrderId}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, size: 18),
            style: IconButton.styleFrom(foregroundColor: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}

// ── Meta row (transport type + timestamps) ─────────────────────────────────────

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (order.transportType != null)
          _MetaChip(
            icon: Icons.local_shipping_outlined,
            label: order.transportTypeLabel,
          ),
        if (order.lastEvent != null)
          _MetaChip(
            icon: Icons.flag_outlined,
            label: order.lastEvent!,
          ),
        _MetaChip(
          icon: Icons.access_time_outlined,
          label: 'Created ${timeAgo(order.createdAt)}',
        ),
        _MetaChip(
          icon: Icons.update_outlined,
          label: 'Updated ${timeAgo(order.updatedAt)}',
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.textMuted),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

// ── Customer ───────────────────────────────────────────────────────────────────

class _CustomerSection extends StatelessWidget {
  const _CustomerSection({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    return _Section(
      icon: Icons.person_outline,
      title: 'Customer',
      child: Column(
        children: [
          if (order.customerName != null)
            _InfoRow(label: 'Name', value: order.customerName!),
          if (order.customerPhone != null) ...[
            const SizedBox(height: 6),
            _InfoRow(label: 'Phone', value: order.customerPhone!),
          ],
        ],
      ),
    );
  }
}

// ── Items ──────────────────────────────────────────────────────────────────────

class _ItemsSection extends StatelessWidget {
  const _ItemsSection({required this.items});

  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    return _Section(
      icon: Icons.receipt_long_outlined,
      title: 'Items',
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 12, color: AppTheme.border),
            _ItemRow(item: items[i]),
          ],
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final name = item['name']?.toString() ?? 'Unknown item';
    // HungerStation: pricing.quantity / unit_price / total_price
    // Keeta: qty / price
    final pricing = item['pricing'] as Map?;
    final quantity = pricing?['quantity'] as num? ?? item['qty'] as num? ?? 1;
    final unitPrice = pricing?['unit_price'] as num? ?? item['price'] as num?;
    final totalPrice = pricing?['total_price'] as num? ??
        (unitPrice != null ? unitPrice * quantity : null);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(
              '$quantity',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (unitPrice != null)
                Text(
                  'SAR ${unitPrice.toStringAsFixed(2)} each',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
            ],
          ),
        ),
        if (totalPrice != null)
          Text(
            'SAR ${totalPrice.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
      ],
    );
  }
}

// ── Payment ────────────────────────────────────────────────────────────────────

class _SimpleTotalSection extends StatelessWidget {
  const _SimpleTotalSection({required this.total});

  final double total;

  @override
  Widget build(BuildContext context) {
    return _Section(
      icon: Icons.payments_outlined,
      title: 'Payment',
      child: Row(
        children: [
          const Text(
            'Total',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
          ),
          const Spacer(),
          Text(
            'SAR ${total.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentSection extends StatelessWidget {
  const _PaymentSection({required this.payment});

  final Map<String, dynamic> payment;

  @override
  Widget build(BuildContext context) {
    final subTotal = payment['sub_total'] as num?;
    final taxes = payment['total_taxes'] as num?;
    final discount = payment['discount'] as num?;
    final deliveryFee = payment['delivery_fee'] as num?;
    final serviceFee = payment['service_fee'] as num?;
    final total = payment['order_total'] as num?;
    final type = payment['type']?.toString();

    return _Section(
      icon: Icons.payments_outlined,
      title: 'Payment${type != null ? ' · $type' : ''}',
      child: Column(
        children: [
          if (subTotal != null)
            _PayRow(label: 'Subtotal', value: subTotal),
          if (taxes != null && taxes != 0)
            _PayRow(label: 'VAT', value: taxes),
          if (discount != null && discount != 0)
            _PayRow(label: 'Discount', value: -discount, valueColor: const Color(0xFF22C55E)),
          if (deliveryFee != null && deliveryFee != 0)
            _PayRow(label: 'Delivery fee', value: deliveryFee),
          if (serviceFee != null && serviceFee != 0)
            _PayRow(label: 'Service fee', value: serviceFee),
          if (total != null) ...[
            const Divider(height: 14, color: AppTheme.border),
            _PayRow(
              label: 'Total',
              value: total,
              bold: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _PayRow extends StatelessWidget {
  const _PayRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.valueColor,
  });

  final String label;
  final num value;
  final bool bold;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: bold ? 14 : 13,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      color: valueColor ?? (bold ? AppTheme.textPrimary : AppTheme.textSecondary),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(label, style: style.copyWith(color: AppTheme.textSecondary, fontWeight: bold ? FontWeight.w600 : FontWeight.w400)),
          const Spacer(),
          Text('SAR ${value.toStringAsFixed(2)}', style: style),
        ],
      ),
    );
  }
}

// ── Cancellation ───────────────────────────────────────────────────────────────

class _CancellationSection extends StatelessWidget {
  const _CancellationSection({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    return _Section(
      icon: Icons.cancel_outlined,
      title: 'Cancellation',
      iconColor: AppTheme.coral,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.coral.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.coral.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 14, color: AppTheme.coral),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                reason,
                style: const TextStyle(fontSize: 13, color: AppTheme.coral),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared ─────────────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.child,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: iconColor ?? AppTheme.textMuted),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.textMuted,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceAlt,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border),
          ),
          child: child,
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textPrimary),
          ),
        ),
      ],
    );
  }
}
