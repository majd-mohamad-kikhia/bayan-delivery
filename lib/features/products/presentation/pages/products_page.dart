import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/product_model.dart';
import '../../data/sample_products.dart';
import '../widgets/product_detail_panel.dart';
import '../widgets/products_header.dart';
import '../widgets/products_table.dart';
import '../widgets/products_toolbar.dart';
import 'publish_product_page.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final _searchController = TextEditingController();
  String _query = '';
  String _category = 'All';
  String _status = 'All';
  ProductModel? _selected;
  ProductModel? _publishing;

  /// Each product with its lowercase search text, built once — a keystroke
  /// is then one `contains` per product instead of four `toLowerCase`s.
  static final List<(ProductModel, String)> _searchIndex = [
    for (final p in sampleProducts)
      (p, '${p.name}\n${p.nameAr}\n${p.sku}\n${p.barcode ?? ''}'.toLowerCase()),
  ];

  static final List<String> _categories = [
    'All',
    ...({for (final p in sampleProducts) p.category}.toList()..sort()),
  ];

  /// Filter result, recomputed only when a filter changes — not on row
  /// selection or opening the publish screen.
  List<ProductModel> _filtered = const [];
  (String, String, String)? _filterKey;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ProductModel> get _visibleProducts {
    final key = (_query, _category, _status);
    if (key == _filterKey) return _filtered;
    _filterKey = key;

    final q = _query.toLowerCase();
    return _filtered = [
      for (final (p, text) in _searchIndex)
        if ((_category == 'All' || p.category == _category) &&
            (_status != 'Active' || p.isActive) &&
            (_status != 'Inactive' || !p.isActive) &&
            (q.isEmpty || text.contains(q)))
          p,
    ];
  }

  void _openPublish(ProductModel product) {
    setState(() => _publishing = product);
  }

  void _closePublish() {
    setState(() => _publishing = null);
  }

  @override
  Widget build(BuildContext context) {
    final publishing = _publishing;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: publishing != null
          ? PublishProductPage(
              key: ValueKey('publish-${publishing.id}'),
              product: publishing,
              onClose: _closePublish,
            )
          : KeyedSubtree(
              key: const ValueKey('list'),
              child: _ProductsListView(
                searchController: _searchController,
                categories: _categories,
                selectedCategory: _category,
                selectedStatus: _status,
                products: _visibleProducts,
                selected: _selected,
                onSearchChanged: (value) =>
                    setState(() => _query = value.trim()),
                onCategoryChanged: (value) => setState(() => _category = value),
                onStatusChanged: (value) => setState(() => _status = value),
                onSelect: (product) => setState(() => _selected = product),
                onCloseDetail: () => setState(() => _selected = null),
                onAddToPlatforms: _openPublish,
              ),
            ),
    );
  }
}

class _ProductsListView extends StatelessWidget {
  const _ProductsListView({
    required this.searchController,
    required this.categories,
    required this.selectedCategory,
    required this.selectedStatus,
    required this.products,
    required this.selected,
    required this.onSearchChanged,
    required this.onCategoryChanged,
    required this.onStatusChanged,
    required this.onSelect,
    required this.onCloseDetail,
    required this.onAddToPlatforms,
  });

  final TextEditingController searchController;
  final List<String> categories;
  final String selectedCategory;
  final String selectedStatus;
  final List<ProductModel> products;
  final ProductModel? selected;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<ProductModel> onSelect;
  final VoidCallback onCloseDetail;
  final ValueChanged<ProductModel> onAddToPlatforms;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ProductsHeader(),
        const _IntegrationBanner(),
        ProductsToolbar(
          searchController: searchController,
          categories: categories,
          selectedCategory: selectedCategory,
          selectedStatus: selectedStatus,
          resultCount: products.length,
          onSearchChanged: onSearchChanged,
          onCategoryChanged: onCategoryChanged,
          onStatusChanged: onStatusChanged,
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ProductsTable(
                  products: products,
                  selectedId: selected?.id,
                  onSelect: onSelect,
                ),
              ),
              if (selected != null)
                ProductDetailPanel(
                  product: selected!,
                  onClose: onCloseDetail,
                  onAddToPlatforms: () => onAddToPlatforms(selected!),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IntegrationBanner extends StatelessWidget {
  const _IntegrationBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFC7D2FE)),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.account_balance_outlined,
            size: 16,
            color: AppTheme.primary,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Al-Bayan catalog — select a product, then add it to Keeta or HungerStation.',
              style: TextStyle(
                color: Color(0xFF3730A3),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
