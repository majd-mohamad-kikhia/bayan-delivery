import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/erp_product_model.dart';
import '../utils/erp_formatters.dart';
import '../utils/erp_group_style.dart';
import '../utils/erp_stock_style.dart';
import 'erp_products_pagination_widget.dart';

class ErpProductsTableWidget extends StatefulWidget {
  const ErpProductsTableWidget({super.key, required this.rows, this.onAddToPlatforms});

  final List<ErpProductModel> rows;
  final ValueChanged<ErpProductModel>? onAddToPlatforms;

  @override
  State<ErpProductsTableWidget> createState() => _ErpProductsTableWidgetState();
}

class _ErpProductsTableWidgetState extends State<ErpProductsTableWidget> {
  final Set<int> _selected = {};

  @override
  void didUpdateWidget(ErpProductsTableWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.rows, widget.rows)) {
      final ids = {for (final p in widget.rows) p.id};
      _selected.retainWhere(ids.contains);
    }
  }

  bool? get _headerValue {
    if (_selected.isEmpty) return false;
    return _selected.length == widget.rows.length ? true : null;
  }

  void _toggle(int id) => setState(() {
        if (!_selected.remove(id)) _selected.add(id);
      });

  void _toggleAll() => setState(() {
        if (_selected.length == widget.rows.length) {
          _selected.clear();
        } else {
          _selected.addAll(widget.rows.map((p) => p.id));
        }
      });

  @override
  Widget build(BuildContext context) {
    final rows = widget.rows;
    final onAdd = widget.onAddToPlatforms;
    final minWidth = _Cols.minTableWidth + (onAdd == null ? 0 : _Cols.actions);

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
        boxShadow: const [
          BoxShadow(color: Color(0x0A0F172A), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: math.max(constraints.maxWidth, minWidth),
                  child: Column(
                    children: [
                      _HeaderRow(
                        selection: _headerValue,
                        onSelectAll: _toggleAll,
                        showActions: onAdd != null,
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemExtent: _Cols.rowHeight,
                          itemCount: rows.length,
                          itemBuilder: (_, i) {
                            final product = rows[i];
                            return _ProductRow(
                              key: ValueKey(product.id),
                              product: product,
                              selected: _selected.contains(product.id),
                              onToggle: () => _toggle(product.id),
                              onAddToPlatforms: onAdd == null ? null : () => onAdd(product),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const ErpProductsPaginationWidget(),
        ],
      ),
    );
  }
}

// ─── Layout ───────────────────────────────────────────────────────────────────

abstract final class _Cols {
  static const double rowHeight = 64;
  static const double headerHeight = 52;
  static const double hPad = 12;

  static const double check = 48;
  static const double id = 84;
  static const double productMin = 260;
  static const double shortName = 110;
  static const double stock = 116;
  static const double price = 104;
  static const double currency = 100;
  static const double group = 104;
  static const double actions = 176;

  static const double minTableWidth =
      hPad * 2 + check + id + productMin + shortName + stock + price * 5 + currency + group;

  static const priceHeaders = [
    ('PRICE 1', 'RETAIL'),
    ('PRICE 2', 'WHOLESALE'),
    ('PRICE 3', null),
    ('PRICE 4', 'SPECIAL'),
    ('PRICE 5', null),
  ];

  static const int highlightedTier = 3;

  static const Color headerBand = Color(0x143D5AFE);
  static const Color rowBand = Color(0x0B3D5AFE);
  static const Color rowDivider = Color(0xFFF1F5F9);
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.width,
    required this.child,
    this.alignment = Alignment.centerLeft,
    this.color,
  });

  final double width;
  final Widget child;
  final Alignment alignment;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        color: color,
        alignment: alignment,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: child,
      );
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.selection,
    required this.onSelectAll,
    required this.showActions,
  });

  final bool? selection;
  final VoidCallback onSelectAll;
  final bool showActions;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _Cols.headerHeight,
      padding: const EdgeInsets.symmetric(horizontal: _Cols.hPad),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Cell(
            width: _Cols.check,
            alignment: Alignment.center,
            child: _TableCheckbox(value: selection, onChanged: onSelectAll),
          ),
          const _Cell(width: _Cols.id, child: _HeaderText('ID')),
          const Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _HeaderText('PRODUCT / ARABIC NAME'),
              ),
            ),
          ),
          const _Cell(width: _Cols.shortName, child: _HeaderText('SHORT\nNAME')),
          const _Cell(
            width: _Cols.stock,
            alignment: Alignment.center,
            child: _HeaderText('STOCK\nQTY', align: TextAlign.center),
          ),
          for (var i = 0; i < _Cols.priceHeaders.length; i++)
            _Cell(
              width: _Cols.price,
              alignment: Alignment.centerRight,
              color: i == _Cols.highlightedTier ? _Cols.headerBand : null,
              child: _HeaderText(
                _Cols.priceHeaders[i].$2 == null
                    ? _Cols.priceHeaders[i].$1
                    : '${_Cols.priceHeaders[i].$1}\n(${_Cols.priceHeaders[i].$2})',
                align: TextAlign.right,
                emphasized: i == _Cols.highlightedTier,
              ),
            ),
          const _Cell(
            width: _Cols.currency,
            alignment: Alignment.center,
            child: _HeaderText('CURRENCY', align: TextAlign.center),
          ),
          const _Cell(width: _Cols.group, child: _HeaderText('GROUP')),
          if (showActions)
            const _Cell(
              width: _Cols.actions,
              alignment: Alignment.center,
              child: _HeaderText('ACTIONS', align: TextAlign.center),
            ),
        ],
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  const _HeaderText(this.text, {this.align = TextAlign.left, this.emphasized = false});

  final String text;
  final TextAlign align;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Text(
        text,
        textAlign: align,
        maxLines: 2,
        style: TextStyle(
          fontSize: 11,
          height: 1.35,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w700,
          color: emphasized ? AppTheme.textPrimary : AppTheme.textSecondary,
        ),
      );
}

// ─── Row ──────────────────────────────────────────────────────────────────────

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    super.key,
    required this.product,
    required this.selected,
    required this.onToggle,
    required this.onAddToPlatforms,
  });

  final ErpProductModel product;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback? onAddToPlatforms;

  @override
  Widget build(BuildContext context) {
    final tiers = product.priceTiers;

    return Material(
      color: selected ? const Color(0x0A3D5AFE) : AppTheme.surface,
      child: InkWell(
        onTap: onToggle,
        hoverColor: AppTheme.surfaceAlt,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: _Cols.hPad),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _Cols.rowDivider)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Cell(
                width: _Cols.check,
                alignment: Alignment.center,
                child: _TableCheckbox(value: selected, onChanged: onToggle),
              ),
              _Cell(
                width: _Cols.id,
                child: Text('#${product.id.toString().padLeft(4, '0')}', style: _idStyle),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: _ProductNameCell(product: product),
                ),
              ),
              _Cell(
                width: _Cols.shortName,
                child: product.shortName.isEmpty
                    ? const _Dash()
                    : Text(
                        product.shortName,
                        textDirection: TextDirection.rtl,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                      ),
              ),
              _Cell(
                width: _Cols.stock,
                alignment: Alignment.center,
                child: _StockPill(product: product),
              ),
              for (var i = 0; i < tiers.length; i++)
                _Cell(
                  width: _Cols.price,
                  alignment: Alignment.centerRight,
                  color: i == _Cols.highlightedTier ? _Cols.rowBand : null,
                  child: _PriceText(tiers[i], highlighted: i == _Cols.highlightedTier),
                ),
              _Cell(
                width: _Cols.currency,
                alignment: Alignment.center,
                child: _CurrencyBadge(currency: product.currency),
              ),
              _Cell(width: _Cols.group, child: _GroupBadge(groupId: product.parentId)),
              if (onAddToPlatforms != null)
                _Cell(
                  width: _Cols.actions,
                  alignment: Alignment.center,
                  child: _AddToPlatformsButton(onPressed: onAddToPlatforms!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

const _idStyle = TextStyle(
  fontFamily: 'monospace',
  fontSize: 12,
  fontWeight: FontWeight.w500,
  color: Color(0xFF64748B),
);

class _Dash extends StatelessWidget {
  const _Dash();

  @override
  Widget build(BuildContext context) =>
      const Text('—', style: TextStyle(color: AppTheme.textMuted));
}

class _TableCheckbox extends StatelessWidget {
  const _TableCheckbox({required this.value, required this.onChanged});

  final bool? value;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Checkbox(
        value: value,
        tristate: value == null,
        onChanged: (_) => onChanged(),
        activeColor: AppTheme.primary,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      );
}

class _ProductNameCell extends StatelessWidget {
  const _ProductNameCell({required this.product});

  final ErpProductModel product;

  @override
  Widget build(BuildContext context) {
    final style = ErpGroupStyle.of(product.parentId);
    final subtitle = [
      'Group ${product.parentId}',
      if (product.shortName.isNotEmpty) product.shortName,
    ].join(' • ');

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: style.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: style.foreground.withValues(alpha: 0.15)),
          ),
          child: Icon(style.icon, size: 18, color: style.foreground),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                textDirection: TextDirection.rtl,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StockPill extends StatelessWidget {
  const _StockPill({required this.product});

  final ErpProductModel product;

  @override
  Widget build(BuildContext context) {
    final color = product.stockLevel.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '${ErpFormatters.quantity(product.quantity)} Units',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceText extends StatelessWidget {
  const _PriceText(this.price, {required this.highlighted});

  final double price;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    if (price <= 0) return const _Dash();
    return Text(
      ErpFormatters.amount(price),
      style: TextStyle(
        fontSize: 13,
        fontWeight: highlighted ? FontWeight.w700 : FontWeight.w500,
        color: highlighted ? AppTheme.primary : AppTheme.textPrimary,
      ),
    );
  }
}

class _CurrencyBadge extends StatelessWidget {
  const _CurrencyBadge({required this.currency});

  final int currency;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppTheme.surfaceAlt,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.border),
        ),
        child: Text(
          currency == 0 ? 'Default' : 'Code $currency',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
      );
}

class _AddToPlatformsButton extends StatelessWidget {
  const _AddToPlatformsButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: 'Publish to Keeta / HungerStation',
        child: Material(
          color: const Color(0x143D5AFE),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_business_outlined, size: 15, color: AppTheme.primary),
                  SizedBox(width: 6),
                  Text(
                    'Add to platforms',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _GroupBadge extends StatelessWidget {
  const _GroupBadge({required this.groupId});

  final int groupId;

  @override
  Widget build(BuildContext context) {
    final style = ErpGroupStyle.of(groupId);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: style.foreground.withValues(alpha: 0.2)),
      ),
      child: Text(
        'Group $groupId',
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: style.foreground,
        ),
      ),
    );
  }
}
