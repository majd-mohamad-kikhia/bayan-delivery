import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/erp_product_model.dart';
import '../utils/erp_formatters.dart';
import '../utils/erp_group_style.dart';
import '../utils/erp_stock_style.dart';
import 'erp_product_details_dialog.dart';
import 'erp_products_pagination_widget.dart';

/// One node of the product tree: a real product, or a synthetic group node
/// standing in for a parent that is not on the loaded page.
class ErpProductNode {
  ErpProductNode({this.product, this.groupId});

  final ErpProductModel? product;
  final int? groupId;
  final List<ErpProductNode> children = [];

  int get key => product?.id ?? -(groupId ?? 0) - 1;

  /// Products in this subtree, itself included.
  int get count =>
      (product == null ? 0 : 1) + children.fold(0, (s, c) => s + c.count);

  /// Links each product to the product whose `id` is its `parent`. A parent
  /// missing from [products] (pages are server-side) becomes a group node.
  static List<ErpProductNode> build(List<ErpProductModel> products) {
    final byId = {for (final p in products) p.id: ErpProductNode(product: p)};
    final groups = <int, ErpProductNode>{};
    final roots = <ErpProductNode>[];

    for (final p in products) {
      final node = byId[p.id]!;
      final parent = byId[p.parentId];
      if (p.parentId != p.id &&
          parent != null &&
          !_isAncestor(byId, node, parent)) {
        parent.children.add(node);
      } else if (p.parentId == 0 || p.parentId == p.id) {
        roots.add(node);
      } else {
        groups
            .putIfAbsent(p.parentId, () => ErpProductNode(groupId: p.parentId))
            .children
            .add(node);
      }
    }
    return [...roots, ...groups.values];
  }

  /// True when [candidate] sits below [node] (linking would form a cycle).
  static bool _isAncestor(
    Map<int, ErpProductNode> byId,
    ErpProductNode node,
    ErpProductNode candidate,
  ) {
    var current = candidate.product;
    final seen = <int>{};
    while (current != null && seen.add(current.id)) {
      if (current.id == node.product!.id) return true;
      current = byId[current.parentId]?.product;
    }
    return false;
  }
}

class ErpProductsTreeWidget extends StatefulWidget {
  const ErpProductsTreeWidget({
    super.key,
    required this.products,
    this.onAddToPlatforms,
  });

  final List<ErpProductModel> products;
  final ValueChanged<ErpProductModel>? onAddToPlatforms;

  @override
  State<ErpProductsTreeWidget> createState() => _ErpProductsTreeWidgetState();
}

class _ErpProductsTreeWidgetState extends State<ErpProductsTreeWidget> {
  late List<ErpProductNode> _roots = ErpProductNode.build(widget.products);
  final Set<int> _collapsed = {};

  @override
  void didUpdateWidget(ErpProductsTreeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.products, widget.products)) {
      _roots = ErpProductNode.build(widget.products);
    }
  }

  void _toggle(int key) => setState(() {
    if (!_collapsed.remove(key)) _collapsed.add(key);
  });

  @override
  Widget build(BuildContext context) {
    final onAdd = widget.onAddToPlatforms;
    final names = {for (final p in widget.products) p.id: p.name};

    return Column(
      children: [
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(24, 12, 24, 12),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border),
            ),
            child: ListView.builder(
              itemCount: _roots.length,
              itemBuilder: (_, i) => _NodeView(
                node: _roots[i],
                depth: 0,
                collapsed: _collapsed,
                onToggle: _toggle,
                onAdd: onAdd,
                names: names,
              ),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
          child: const ErpProductsPaginationWidget(showTopBorder: false),
        ),
      ],
    );
  }
}

/// A row plus its children, which slide open / closed.
class _NodeView extends StatelessWidget {
  const _NodeView({
    required this.node,
    required this.depth,
    required this.collapsed,
    required this.onToggle,
    required this.onAdd,
    required this.names,
  });

  final ErpProductNode node;
  final int depth;
  final Set<int> collapsed;
  final ValueChanged<int> onToggle;
  final ValueChanged<ErpProductModel>? onAdd;

  /// Product id → name, to show a product's group by name.
  final Map<int, String> names;

  @override
  Widget build(BuildContext context) {
    final expanded = !collapsed.contains(node.key);
    final product = node.product;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TreeRow(
          node: node,
          depth: depth,
          expanded: expanded,
          onToggle: node.children.isEmpty ? null : () => onToggle(node.key),
          onAdd: onAdd == null || product == null
              ? null
              : () => onAdd!(product),
          onOpen: product == null
              ? null
              : () => showErpProductDetails(
                  context,
                  product,
                  groupName: names[product.parentId],
                  childCount: node.children.length,
                  onAddToPlatforms: onAdd == null
                      ? null
                      : () => onAdd!(product),
                ),
        ),
        if (node.children.isNotEmpty)
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            sizeCurve: Curves.easeInOutCubic,
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final child in node.children)
                  _NodeView(
                    node: child,
                    depth: depth + 1,
                    collapsed: collapsed,
                    onToggle: onToggle,
                    onAdd: onAdd,
                    names: names,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TreeRow extends StatelessWidget {
  const _TreeRow({
    required this.node,
    required this.depth,
    required this.expanded,
    required this.onToggle,
    required this.onAdd,
    required this.onOpen,
  });

  final ErpProductNode node;
  final int depth;
  final bool expanded;
  final VoidCallback? onToggle;
  final VoidCallback? onAdd;

  /// Opens the product's details (null for synthetic group rows).
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final product = node.product;
    final style = ErpGroupStyle.of(product?.parentId ?? node.groupId ?? 0);
    final stock = product?.stockLevel;

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: InkWell(
        // A group opens / closes; a plain item opens its details.
        onTap: onToggle ?? onOpen,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12 + depth * 24.0, 8, 12, 8),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: onToggle == null
                    ? null
                    : AnimatedRotation(
                        turns: expanded ? 0.25 : 0,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOutCubic,
                        child: const Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: AppTheme.textSecondary,
                        ),
                      ),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: style.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  product == null || node.children.isNotEmpty
                      ? Icons.folder_outlined
                      : style.icon,
                  size: 16,
                  color: style.foreground,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: product == null
                    ? Text(
                        'Group ${node.groupId} · ${node.count} products',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name.isEmpty
                                ? '#${product.id}'
                                : product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            '#${product.id}${product.shortName.isEmpty ? '' : ' · ${product.shortName}'}'
                            '${node.children.isEmpty ? '' : ' · ${node.count - 1} sub-items'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
              ),
              if (product != null) ...[
                Text(
                  ErpFormatters.amount(product.primaryPrice),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(stock!.icon, size: 14, color: stock.color),
                const SizedBox(width: 4),
                SizedBox(
                  width: 64,
                  child: Text(
                    ErpFormatters.quantity(product.quantity),
                    style: TextStyle(fontSize: 12.5, color: stock.color),
                  ),
                ),
                if (onOpen != null)
                  IconButton(
                    tooltip: 'Details',
                    icon: const Icon(Icons.info_outline_rounded, size: 20),
                    onPressed: onOpen,
                  ),
                if (onAdd != null)
                  IconButton(
                    tooltip: 'Add to platforms',
                    icon: const Icon(
                      Icons.add_circle_outline_rounded,
                      size: 20,
                    ),
                    onPressed: onAdd,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
