import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/erp_product_model.dart';
import '../bloc/bayan_erp_bloc.dart';
import '../bloc/bayan_erp_event.dart';
import '../bloc/bayan_erp_state.dart';
import '_erp_table_shell.dart';
import 'erp_product_card_widget.dart';
import 'erp_products_pagination_widget.dart';
import 'erp_products_table_widget.dart';
import 'erp_products_toolbar_widget.dart';

/// Products tab: toolbar (search, stock filters, view toggle) over a card grid
/// or a table of the loaded page.
class ErpProductsTabWidget extends StatefulWidget {
  const ErpProductsTabWidget({super.key, this.onAddToPlatforms});

  final ValueChanged<ErpProductModel>? onAddToPlatforms;

  @override
  State<ErpProductsTabWidget> createState() => _ErpProductsTabWidgetState();
}

class _ErpProductsTabWidgetState extends State<ErpProductsTabWidget> {
  ErpProductsViewMode _viewMode = ErpProductsViewMode.grid;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ErpProductsToolbarWidget(
          viewMode: _viewMode,
          onViewModeChanged: (mode) => setState(() => _viewMode = mode),
        ),
        Expanded(
          child: BlocBuilder<BayanErpBloc, BayanErpState>(
            buildWhen: (p, c) =>
                p.productsStatus != c.productsStatus ||
                p.products != c.products ||
                p.productsError != c.productsError ||
                p.productsQuery != c.productsQuery ||
                p.productsStockFilter != c.productsStockFilter,
            builder: (context, state) {
              final content = _ProductsContent(
                products: state.visibleProducts,
                viewMode: _viewMode,
                hasFilters: state.hasProductFilters,
                onAddToPlatforms: widget.onAddToPlatforms,
              );
              // Keep the current page on screen while the next one loads.
              if (state.productsStatus == BayanErpStatus.loading &&
                  state.products.isNotEmpty) {
                return Stack(
                  children: [
                    content,
                    const Positioned(
                      top: 0,
                      left: 24,
                      right: 24,
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                  ],
                );
              }
              return ErpTableShell(
                status: state.productsStatus,
                error: state.productsError,
                isEmpty: state.products.isEmpty && state.productsPage == 0,
                emptyLabel: 'No products found',
                child: content,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ProductsContent extends StatelessWidget {
  const _ProductsContent({
    required this.products,
    required this.viewMode,
    required this.hasFilters,
    required this.onAddToPlatforms,
  });

  final List<ErpProductModel> products;
  final ErpProductsViewMode viewMode;
  final bool hasFilters;
  final ValueChanged<ErpProductModel>? onAddToPlatforms;

  @override
  Widget build(BuildContext context) {
    if (viewMode == ErpProductsViewMode.table && products.isNotEmpty) {
      return ErpProductsTableWidget(rows: products, onAddToPlatforms: onAddToPlatforms);
    }
    return Column(
      children: [
        Expanded(
          child: products.isEmpty
              ? _NoMatchView(hasFilters: hasFilters)
              : _ProductsGrid(products: products, onAddToPlatforms: onAddToPlatforms),
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

class _ProductsGrid extends StatelessWidget {
  const _ProductsGrid({required this.products, required this.onAddToPlatforms});

  final List<ErpProductModel> products;
  final ValueChanged<ErpProductModel>? onAddToPlatforms;

  @override
  Widget build(BuildContext context) {
    final onAdd = onAddToPlatforms;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 300,
        mainAxisExtent: onAdd == null ? 280 : 330,
        mainAxisSpacing: 18,
        crossAxisSpacing: 18,
      ),
      itemCount: products.length,
      itemBuilder: (_, i) {
        final product = products[i];
        return ErpProductCardWidget(
          key: ValueKey(product.id),
          product: product,
          onAddToPlatforms: onAdd == null ? null : () => onAdd(product),
        );
      },
    );
  }
}

class _NoMatchView extends StatelessWidget {
  const _NoMatchView({required this.hasFilters});

  final bool hasFilters;

  @override
  Widget build(BuildContext context) {
    if (!hasFilters) return const _EndOfCatalogView();
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.search_off_rounded, size: 34, color: AppTheme.primary),
          ),
          const SizedBox(height: 14),
          const Text(
            'No products match your filters',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Filters apply to the current page only.',
            style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 14),
          FilledButton.tonalIcon(
            onPressed: () {
              context.read<BayanErpBloc>()
                ..add(const BayanErpProductsSearchChanged(''))
                ..add(const BayanErpProductsStockFilterChanged(null));
            },
            icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
            label: const Text('Clear filters'),
          ),
        ],
      ),
    );
  }
}

class _EndOfCatalogView extends StatelessWidget {
  const _EndOfCatalogView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 44, color: AppTheme.textMuted),
          SizedBox(height: 12),
          Text(
            'No more products',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            "You've reached the end of the catalog.",
            style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}
