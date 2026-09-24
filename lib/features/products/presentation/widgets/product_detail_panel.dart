import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/product_model.dart';
import '../utils/product_formatters.dart';

class ProductDetailPanel extends StatelessWidget {
  const ProductDetailPanel({
    super.key,
    required this.product,
    required this.onClose,
    this.onAddToPlatforms,
  });

  final ProductModel product;
  final VoidCallback onClose;
  final VoidCallback? onAddToPlatforms;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      margin: const EdgeInsets.fromLTRB(0, 0, 16, 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Product details',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close, size: 18),
                  color: AppTheme.textMuted,
                  splashRadius: 18,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  product.nameAr,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 16),
                _DetailRow(
                  label: 'SKU',
                  value: product.sku,
                  onCopy: () => copyToClipboard(context, 'SKU', product.sku),
                ),
                if (product.barcode != null)
                  _DetailRow(
                    label: 'Barcode',
                    value: product.barcode!,
                    onCopy: () =>
                        copyToClipboard(context, 'Barcode', product.barcode!),
                  ),
                _DetailRow(label: 'Category', value: product.category),
                _DetailRow(label: 'Unit', value: product.unit),
                _DetailRow(
                  label: 'Sale price',
                  value: formatSar(product.salePrice),
                ),
                _DetailRow(
                  label: 'Cost price',
                  value: formatSar(product.costPrice),
                ),
                _DetailRow(
                  label: 'Tax rate',
                  value: '${product.taxRate.toStringAsFixed(0)}%',
                ),
                _DetailRow(
                  label: 'Stock',
                  value: product.stockQty % 1 == 0
                      ? product.stockQty.toInt().toString()
                      : product.stockQty.toStringAsFixed(1),
                ),
                _DetailRow(
                  label: 'Status',
                  value: product.isActive ? 'Active' : 'Inactive',
                ),
                const SizedBox(height: 20),
                if (onAddToPlatforms != null) ...[
                  FilledButton.icon(
                    onPressed: onAddToPlatforms,
                    icon: const Icon(Icons.add_to_photos_outlined, size: 16),
                    label: const Text('Add to platforms'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Edit products in Al-Bayan Accounting.',
                          ),
                        ),
                      );
                  },
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Open in Al-Bayan'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value, this.onCopy});

  final String label;
  final String value;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
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
          if (onCopy != null)
            InkWell(
              onTap: onCopy,
              borderRadius: BorderRadius.circular(4),
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(Icons.copy, size: 14, color: AppTheme.textMuted),
              ),
            ),
        ],
      ),
    );
  }
}
