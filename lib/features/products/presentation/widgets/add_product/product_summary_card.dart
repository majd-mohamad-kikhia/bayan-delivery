import 'package:flutter/material.dart';

import '../../../../../core/localization/locale_context.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../data/models/product_model.dart';
import '../../l10n/products_strings.dart';

/// Read-only Al-Bayan product summary shown while publishing to platforms.
class ProductSummaryCard extends StatelessWidget {
  const ProductSummaryCard({super.key, required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    final s = context.productsStrings;
    final common = context.commonStrings;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.account_balance_outlined,
                  size: 18,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.alBayanProduct,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      s.alBayanProductSubtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  product.nameAr,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppTheme.textSecondary,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Chip(label: product.sku, icon: Icons.qr_code_2_outlined),
                    _Chip(label: product.category),
                    _Chip(label: product.unit),
                    _Chip(
                      label: product.isActive ? common.active : common.inactive,
                      tone: product.isActive
                          ? const Color(0xFF166534)
                          : const Color(0xFF991B1B),
                      background: product.isActive
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFFEE2E2),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _InfoRow(label: s.salePrice, value: common.money(product.salePrice)),
          _InfoRow(label: s.costPrice, value: common.money(product.costPrice)),
          _InfoRow(
            label: s.tax,
            value: '${product.taxRate.toStringAsFixed(0)}%',
          ),
          _InfoRow(
            label: s.stock,
            value: product.stockQty % 1 == 0
                ? product.stockQty.toInt().toString()
                : product.stockQty.toStringAsFixed(1),
          ),
          if (product.barcode != null)
            _InfoRow(label: s.barcode, value: product.barcode!),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 14,
                  color: Color(0xFF3730A3),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.ownershipNote,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF3730A3),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    this.icon,
    this.tone = AppTheme.textSecondary,
    this.background = AppTheme.surface,
  });

  final String label;
  final IconData? icon;
  final Color tone;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: tone),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: tone,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
