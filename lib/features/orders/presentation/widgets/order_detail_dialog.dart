import 'package:flutter/material.dart';

import '../../../../core/localization/locale_context.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/time_ago.dart';
import '../../../bayan_orders/presentation/bayan_order_bar.dart';
import '../../data/models/order_model.dart';
import '../l10n/orders_strings.dart';
import '../utils/order_status_style.dart';
import 'platform_badge.dart';

void showOrderDetailDialog(BuildContext context, OrderModel order) {
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: context.ordersStrings.orderDetail,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 260),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.93, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
    pageBuilder: (context, _, _) => _OrderDetailDialog(order: order),
  );
}

// ── Dialog shell ───────────────────────────────────────────────────────────────

class _OrderDetailDialog extends StatelessWidget {
  const _OrderDetailDialog({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    // Roomier than the board: wider, taller, and every label 15% larger.
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        textScaler: TextScaler.linear(media.textScaler.scale(1) * 1.15),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 780,
            maxHeight: media.size.height * 0.92,
          ),
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
                        if (order.customerName != null ||
                            order.customerPhone != null) ...[
                          const SizedBox(height: 20),
                          _CustomerSection(order: order),
                        ],
                        if (order.items.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          _ItemsSection(items: order.items),
                        ],
                        if (order.payment != null) ...[
                          const SizedBox(height: 20),
                          _PaymentSection(
                            payment: order.payment!,
                            promotions: order.promotions,
                          ),
                        ] else if (order.orderTotal != null) ...[
                          const SizedBox(height: 20),
                          _SimpleTotalSection(total: order.orderTotal!),
                        ],
                        if (order.cancellationReason != null) ...[
                          const SizedBox(height: 20),
                          _CancellationSection(
                            reason: order.cancellationReason!,
                          ),
                        ],
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
                BayanOrderBar(order: order),
              ],
            ),
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
    final statusColor = OrderStatusStyle.color(
      order.status,
      platform: order.platform,
    );
    final statusLabel = context.ordersStrings.statusLabel(
      order.status,
      platform: order.platform,
    );

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 12, 14),
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
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
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
            tooltip: context.commonStrings.close,
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
    final s = context.ordersStrings;
    final common = context.commonStrings;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (order.transportType != null)
          _MetaChip(
            icon: Icons.local_shipping_outlined,
            label: s.transportTypeLabel(order.transportType!),
          ),
        if (order.lastEvent != null)
          _MetaChip(icon: Icons.flag_outlined, label: order.lastEvent!),
        _MetaChip(
          icon: Icons.access_time_outlined,
          label: s.createdAgo(timeAgo(order.createdAt, common)),
        ),
        _MetaChip(
          icon: Icons.update_outlined,
          label: s.updatedAgo(timeAgo(order.updatedAt, common)),
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
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
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
    final s = context.ordersStrings;
    return _Section(
      icon: Icons.person_outline,
      title: s.customer,
      child: Column(
        children: [
          if (order.customerName != null)
            _InfoRow(label: s.name, value: order.customerName!),
          if (order.customerPhone != null) ...[
            const SizedBox(height: 6),
            _InfoRow(
              label: s.phone,
              value: order.customerPhone!,
              forceLtr: true,
            ),
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
    final common = context.commonStrings;
    var addOnCount = 0;
    var addOnSum = 0.0;
    for (final item in items) {
      for (final a in _addOnsOf(item)) {
        addOnCount += a.quantity;
        addOnSum += a.unitPrice * a.quantity;
      }
    }
    return _Section(
      icon: Icons.receipt_long_outlined,
      title: context.ordersStrings.items,
      child: Column(
        children: [
          if (addOnCount > 0) ...[
            _AddOnsSummary(count: addOnCount, total: common.money(addOnSum)),
            const SizedBox(height: 10),
          ],
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 16, color: AppTheme.border),
            _ItemRow(item: items[i]),
          ],
        ],
      ),
    );
  }
}

const _addOnAccent = Color(0xFF7C4DFF);

/// "3 add-ons · +10.00" — how much of the order is extras, at a glance.
class _AddOnsSummary extends StatelessWidget {
  const _AddOnsSummary({required this.count, required this.total});

  final int count;
  final String total;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _addOnAccent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_circle_rounded, size: 14, color: _addOnAccent),
            const SizedBox(width: 6),
            Text(
              '${context.ordersStrings.addOns} · $count  ·  +$total',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _addOnAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final s = context.ordersStrings;
    final common = context.commonStrings;
    final name = item['name']?.toString() ?? s.unknownItem;
    // HungerStation: pricing.quantity / unit_price / total_price
    // Keeta: qty / price
    final pricing = item['pricing'] as Map?;
    final quantity = pricing?['quantity'] as num? ?? item['qty'] as num? ?? 1;
    final unitPrice = pricing?['unit_price'] as num? ?? item['price'] as num?;
    final addOns = _addOnsOf(item);
    final addOnsTotal = addOns.fold<double>(
      0,
      (sum, a) => sum + a.unitPrice * a.quantity,
    );
    final baseTotal = unitPrice != null
        ? unitPrice.toDouble() * quantity
        : null;
    // HungerStation reports the line total itself; Keeta's is base + extras.
    final lineTotal =
        (pricing?['total_price'] as num?)?.toDouble() ??
        (baseTotal != null ? baseTotal + addOnsTotal : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
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
                      s.eachPrice(common.money(unitPrice.toDouble())),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            if (lineTotal != null)
              Text(
                common.money(lineTotal),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
          ],
        ),
        if (addOns.isNotEmpty)
          _AddOnsPanel(
            addOns: addOns,
            itemTotal: baseTotal,
            addOnsTotal: addOnsTotal,
          ),
      ],
    );
  }
}

/// The extras on one line, indented under it: a connector rail, each add-on
/// with its quantity and price, and the item / add-ons split of the line.
class _AddOnsPanel extends StatelessWidget {
  const _AddOnsPanel({
    required this.addOns,
    required this.itemTotal,
    required this.addOnsTotal,
  });

  final List<({String name, int quantity, double unitPrice})> addOns;
  final double? itemTotal;
  final double addOnsTotal;

  @override
  Widget build(BuildContext context) {
    final common = context.commonStrings;
    final s = context.ordersStrings;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 8),
          child: child,
        ),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 12, top: 8),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Connector rail from the item down to its add-ons.
              Container(
                width: 2,
                margin: const EdgeInsetsDirectional.only(end: 10),
                decoration: BoxDecoration(
                  color: _addOnAccent.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: _addOnAccent.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _addOnAccent.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.add_circle_outline_rounded,
                            size: 13,
                            color: _addOnAccent,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            s.addOns,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: _addOnAccent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (final a in addOns)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.5),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: _addOnAccent.withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Text(
                                  '${a.quantity}×',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _addOnAccent,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  a.name,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                              Text(
                                a.unitPrice > 0
                                    ? '+${common.money(a.unitPrice * a.quantity)}'
                                    : '—',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (itemTotal != null && addOnsTotal > 0) ...[
                        const SizedBox(height: 6),
                        Divider(
                          height: 1,
                          color: _addOnAccent.withValues(alpha: 0.18),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              '${s.itemSubtotal} ${common.money(itemTotal!)}  +  '
                              '${s.addOns} ${common.money(addOnsTotal)}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
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

/// Add-ons the customer picked on a line: Keeta `addOns`, HungerStation `options`.
List<({String name, int quantity, double unitPrice})> _addOnsOf(
  Map<String, dynamic> item,
) {
  final raw = item['addOns'] ?? item['options'];
  if (raw is! List) return const [];
  return [
    for (final entry in raw.whereType<Map>())
      if (entry['name']?.toString().trim().isNotEmpty ?? false)
        (
          name: entry['name'].toString().trim(),
          quantity: ((entry['qty'] ?? entry['quantity']) as num?)?.toInt() ?? 1,
          unitPrice:
              ((entry['price'] ?? entry['unit_price']) as num?)?.toDouble() ??
              0,
        ),
  ];
}

// ── Payment ────────────────────────────────────────────────────────────────────

class _SimpleTotalSection extends StatelessWidget {
  const _SimpleTotalSection({required this.total});

  final double total;

  @override
  Widget build(BuildContext context) {
    final s = context.ordersStrings;
    return _Section(
      icon: Icons.payments_outlined,
      title: s.payment,
      child: Row(
        children: [
          Text(
            s.total,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            context.commonStrings.money(total),
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
  const _PaymentSection({required this.payment, this.promotions = const []});

  final Map<String, dynamic> payment;
  final List<({String name, double amount})> promotions;

  @override
  Widget build(BuildContext context) {
    final subTotal = payment['sub_total'] as num?;
    final taxes = payment['total_taxes'] as num?;
    final discount = payment['discount'] as num?;
    final deliveryFee = payment['delivery_fee'] as num?;
    final serviceFee = payment['service_fee'] as num?;
    final total = payment['order_total'] as num?;
    final type = payment['type']?.toString();
    final s = context.ordersStrings;

    return _Section(
      icon: Icons.payments_outlined,
      title: type != null ? '${s.payment} · $type' : s.payment,
      child: Column(
        children: [
          if (subTotal != null) _PayRow(label: s.subtotal, value: subTotal),
          if (taxes != null && taxes != 0) _PayRow(label: s.vat, value: taxes),
          if (discount != null && discount != 0)
            _PayRow(
              label: s.discount,
              value: -discount.abs(),
              valueColor: const Color(0xFF22C55E),
            ),
          for (final promotion in promotions)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 12),
              child: _PayRow(
                label: promotion.name,
                value: -promotion.amount,
                muted: true,
                valueColor: const Color(0xFF22C55E),
              ),
            ),
          if (deliveryFee != null && deliveryFee != 0)
            _PayRow(label: s.deliveryFee, value: deliveryFee),
          if (serviceFee != null && serviceFee != 0)
            _PayRow(label: s.serviceFee, value: serviceFee),
          if (total != null) ...[
            const Divider(height: 14, color: AppTheme.border),
            _PayRow(label: s.total, value: total, bold: true),
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
    this.muted = false,
    this.valueColor,
  });

  final String label;
  final num value;
  final bool bold;

  /// A detail line under another row: smaller, lighter.
  final bool muted;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: bold ? 14 : (muted ? 12 : 13),
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      color:
          valueColor ?? (bold ? AppTheme.textPrimary : AppTheme.textSecondary),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: style.copyWith(
                color: muted ? AppTheme.textMuted : AppTheme.textSecondary,
                fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(context.commonStrings.money(value.toDouble()), style: style),
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
      title: context.ordersStrings.cancellation,
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
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.textMuted,
                // Letter spacing breaks Arabic letter joining.
                letterSpacing: context.isArabic ? 0 : 0.5,
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
  const _InfoRow({
    required this.label,
    required this.value,
    this.forceLtr = false,
  });

  final String label;
  final String value;

  /// Keeps values like phone numbers LTR while staying start-aligned in RTL.
  final bool forceLtr;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      value,
      textDirection: forceLtr ? TextDirection.ltr : null,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppTheme.textPrimary,
      ),
    );
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
        ),
        Expanded(
          child: forceLtr
              ? Align(alignment: AlignmentDirectional.centerStart, child: text)
              : text,
        ),
      ],
    );
  }
}
