import 'package:flutter/material.dart';

import '../../../../core/localization/locale_context.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../orders/presentation/widgets/orders_dialog_shell.dart';
import '../../data/models/erp_product_model.dart';
import '../utils/erp_formatters.dart';
import '../utils/erp_group_style.dart';
import '../utils/erp_stock_style.dart';
import 'erp_registration_widgets.dart';

/// Everything Al-Bayan knows about one product: ids, group, stock, the five
/// price tiers, and which platforms it is on. [onAddToPlatforms] adds the
/// "Add to platforms" button.
Future<void> showErpProductDetails(
  BuildContext context,
  ErpProductModel product, {
  String? groupName,
  int childCount = 0,
  VoidCallback? onAddToPlatforms,
}) {
  return showOrdersDialog<void>(
    context,
    builder: (_) => _ErpProductDetails(
      product: product,
      groupName: groupName,
      childCount: childCount,
      onAddToPlatforms: onAddToPlatforms,
    ),
  );
}

String _t(BuildContext context, String en, String ar) =>
    context.isArabic ? ar : en;

class _ErpProductDetails extends StatelessWidget {
  const _ErpProductDetails({
    required this.product,
    required this.groupName,
    required this.childCount,
    required this.onAddToPlatforms,
  });

  final ErpProductModel product;
  final String? groupName;
  final int childCount;
  final VoidCallback? onAddToPlatforms;

  @override
  Widget build(BuildContext context) {
    final stock = product.stockLevel;
    final style = ErpGroupStyle.of(product.parentId);
    final isGroup = product.kind == 1 || childCount > 0;
    final tiers = product.priceTiers;
    final primary = product.primaryTierIndex;

    return OrdersDialogShell(
      icon: isGroup ? Icons.folder_rounded : style.icon,
      title: product.name.isEmpty ? '#${product.id}' : product.name,
      subtitle: [
        '#${product.id}',
        if (product.shortName.isNotEmpty) product.shortName,
      ].join(' · '),
      maxWidth: 600,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_t(context, 'Close', 'إغلاق')),
        ),
        if (onAddToPlatforms != null && !isGroup) ...[
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              onAddToPlatforms!();
            },
            icon: const Icon(Icons.add_business_outlined, size: 18),
            label: Text(_t(context, 'Add to platforms', 'إضافة إلى المنصات')),
            style: dialogButtonStyle,
          ),
        ],
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Fact(
                icon: Icons.folder_open_rounded,
                label: _t(context, 'Group', 'المجموعة'),
                value: product.parentId == 0
                    ? _t(context, 'None (top level)', 'لا يوجد (مستوى أعلى)')
                    : (groupName ?? '#${product.parentId}'),
              ),
              _Fact(
                icon: isGroup
                    ? Icons.account_tree_outlined
                    : Icons.inventory_2_outlined,
                label: _t(context, 'Type', 'النوع'),
                value: isGroup
                    ? _t(
                        context,
                        'Group · $childCount items',
                        'مجموعة · $childCount صنف',
                      )
                    : _t(context, 'Item', 'صنف'),
              ),
              if (!isGroup)
                _Fact(
                  icon: stock.icon,
                  color: stock.color,
                  label: _t(context, 'Stock', 'المخزون'),
                  value:
                      '${ErpFormatters.quantity(product.quantity)} · ${stock.label}',
                ),
              _Fact(
                icon: Icons.currency_exchange_rounded,
                label: _t(context, 'Currency code', 'رمز العملة'),
                value: '${product.currency}',
              ),
            ],
          ),
          if (!isGroup) ...[
            const SizedBox(height: 18),
            Text(
              _t(context, 'Prices', 'الأسعار'),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.border),
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < tiers.length; i++)
                    Container(
                      color: i == primary
                          ? AppTheme.primary.withValues(alpha: 0.08)
                          : (i.isEven ? AppTheme.surface : AppTheme.surfaceAlt),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      child: Row(
                        children: [
                          Text(
                            _t(context, 'Price ${i + 1}', 'السعر ${i + 1}'),
                            style: TextStyle(
                              fontWeight: i == primary
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          if (i == primary) ...[
                            const SizedBox(width: 8),
                            Text(
                              _t(
                                context,
                                'used on platforms',
                                'المستخدم على المنصات',
                              ),
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppTheme.primary,
                              ),
                            ),
                          ],
                          const Spacer(),
                          Text(
                            tiers[i] > 0 ? ErpFormatters.amount(tiers[i]) : '—',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: tiers[i] > 0
                                  ? AppTheme.textPrimary
                                  : AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _t(context, 'On platforms', 'على المنصات'),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            const SizedBox(height: 8),
            ErpRegistrationBadges(productId: product.id),
          ],
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppTheme.primary;
    return Container(
      constraints: const BoxConstraints(minWidth: 170),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: tint),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppTheme.textMuted,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
