import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/erp_product_model.dart';
import '../utils/erp_formatters.dart';
import '../utils/erp_stock_style.dart';

class ErpProductCardWidget extends StatefulWidget {
  const ErpProductCardWidget({super.key, required this.product, this.onAddToPlatforms});

  final ErpProductModel product;
  final VoidCallback? onAddToPlatforms;

  @override
  State<ErpProductCardWidget> createState() => _ErpProductCardWidgetState();
}

class _ErpProductCardWidgetState extends State<ErpProductCardWidget> {
  bool _hovered = false;

  /// Built once per product so hover animations don't rebuild the card content.
  late Widget _content = _buildContent();

  @override
  void didUpdateWidget(ErpProductCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final actionToggled =
        (oldWidget.onAddToPlatforms == null) != (widget.onAddToPlatforms == null);
    if (oldWidget.product != widget.product || actionToggled) _content = _buildContent();
  }

  Widget _buildContent() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardHeader(product: widget.product),
          Expanded(
            child: _CardBody(
              product: widget.product,
              // Reads the current callback at tap time, since this content is cached.
              onAddToPlatforms:
                  widget.onAddToPlatforms == null ? null : () => widget.onAddToPlatforms?.call(),
            ),
          ),
        ],
      );

  void _setHovered(bool value) {
    if (_hovered != value) setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _hovered ? -4 : 0, 0),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _hovered ? AppTheme.primary.withValues(alpha: 0.35) : AppTheme.border,
          ),
          boxShadow: [
            BoxShadow(
              color: _hovered ? const Color(0x1F0F172A) : const Color(0x0A0F172A),
              blurRadius: _hovered ? 28 : 10,
              offset: Offset(0, _hovered ? 12 : 4),
            ),
          ],
        ),
        child: _content,
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.product});

  final ErpProductModel product;

  static const _gradients = [
    [Color(0xFF3D5AFE), Color(0xFF7C4DFF)],
    [Color(0xFF0EA5E9), Color(0xFF2563EB)],
    [Color(0xFF10B981), Color(0xFF0D9488)],
    [Color(0xFFF97316), Color(0xFFEF4444)],
    [Color(0xFFEC4899), Color(0xFF8B5CF6)],
    [Color(0xFF14B8A6), Color(0xFF3B82F6)],
  ];

  @override
  Widget build(BuildContext context) {
    final colors = _gradients[product.parentId.abs() % _gradients.length];
    final initial = product.name.isEmpty ? '?' : product.name.characters.first;

    return Container(
      height: 88,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Stack(
        children: [
          const Positioned(right: -24, top: -30, child: _Bubble(size: 110)),
          const Positioned(right: 50, bottom: -36, child: _Bubble(size: 70)),
          Positioned(
            left: 14,
            bottom: 14,
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '#${product.id}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Group ${product.parentId}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(top: 12, right: 12, child: _StockBadge(level: product.stockLevel)),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0x1FFFFFFF),
        ),
      );
}

class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.level});

  final ErpStockLevel level;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(level.icon, size: 12, color: level.color),
            const SizedBox(width: 4),
            Text(
              level.label,
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: level.color),
            ),
          ],
        ),
      );
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _CardBody extends StatelessWidget {
  const _CardBody({required this.product, required this.onAddToPlatforms});

  final ErpProductModel product;
  final VoidCallback? onAddToPlatforms;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            product.name,
            textDirection: TextDirection.rtl,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              height: 1.35,
            ),
          ),
          if (product.shortName.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              product.shortName,
              textDirection: TextDirection.rtl,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
            ),
          ],
          const Spacer(),
          _PriceRow(product: product),
          const SizedBox(height: 12),
          _PriceTiers(product: product),
          if (onAddToPlatforms != null) ...[
            const SizedBox(height: 12),
            _AddToPlatformsButton(onPressed: onAddToPlatforms!),
          ],
        ],
      ),
    );
  }
}

class _AddToPlatformsButton extends StatelessWidget {
  const _AddToPlatformsButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 38,
        child: FilledButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.add_business_outlined, size: 17),
          label: const Text('Add to platforms'),
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      );
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.product});

  final ErpProductModel product;

  @override
  Widget build(BuildContext context) {
    final price = product.primaryPrice;
    final level = product.stockLevel;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PRICE',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMuted,
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  price > 0 ? ErpFormatters.amount(price) : 'Not priced',
                  style: TextStyle(
                    fontSize: price > 0 ? 22 : 15,
                    fontWeight: FontWeight.w800,
                    color: price > 0 ? AppTheme.textPrimary : AppTheme.textMuted,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: level.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inventory_2_outlined, size: 13, color: level.color),
              const SizedBox(width: 5),
              Text(
                ErpFormatters.quantity(product.quantity),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: level.color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PriceTiers extends StatelessWidget {
  const _PriceTiers({required this.product});

  final ErpProductModel product;

  @override
  Widget build(BuildContext context) {
    final tiers = product.priceTiers;
    final primary = product.primaryTierIndex;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tiers.length; i++)
            Expanded(
              child: _TierCell(
                label: 'P${i + 1}',
                value: tiers[i],
                highlighted: i == primary,
              ),
            ),
        ],
      ),
    );
  }
}

class _TierCell extends StatelessWidget {
  const _TierCell({required this.label, required this.value, required this.highlighted});

  final String label;
  final double value;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final color = highlighted
        ? AppTheme.primary
        : (value > 0 ? AppTheme.textPrimary : AppTheme.textMuted);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            color: highlighted ? AppTheme.primary : AppTheme.textMuted,
          ),
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value > 0 ? ErpFormatters.amount(value) : '—',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ),
      ],
    );
  }
}
