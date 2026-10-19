import '../../bayan_erp/data/models/erp_product_model.dart';
import 'models/product_model.dart';

/// The price Al-Bayan products are sold at on the platforms: price 1, or the
/// first price tier that has a value. One rule for publishing and syncing.
double erpSalePrice(ErpProductModel p) =>
    p.price1 > 0 ? p.price1 : p.primaryPrice;

/// [erpSalePrice] in minor units (SAR 12.50 → 1250).
int erpSalePriceMinor(ErpProductModel p) => (erpSalePrice(p) * 100).round();

/// ERP groups whose name says they hold extras ("إضافات", "Add-ons", "Extras").
final RegExp _addOnGroupName = RegExp(
  'إضافات|اضافات|add[- ]?ons?|extras?',
  caseSensitive: false,
);

bool isAddOnGroupName(String name) => _addOnGroupName.hasMatch(name);

/// Splits a loaded page into the add-on groups (their items are options) and
/// the ids of everything that must not be published as a product: the groups
/// themselves and their items.
({List<AddOnGroup> groups, Set<int> excluded}) addOnsOf(
  List<ErpProductModel> products,
) {
  final groups = <AddOnGroup>[];
  final excluded = <int>{};
  for (final group in products) {
    if (!isAddOnGroupName(group.name)) continue;
    final options = [
      for (final p in products)
        if (p.parentId == group.id && p.id != group.id)
          AddOnOption(sku: '${p.id}', name: p.name, price: p.primaryPrice),
    ];
    if (options.isEmpty) continue;
    groups.add(AddOnGroup(name: group.name, options: options));
    excluded
      ..add(group.id)
      ..addAll(options.map((o) => int.parse(o.sku)));
  }
  return (groups: groups, excluded: excluded);
}

final RegExp _arabic = RegExp(r'[؀-ۿ]');

/// Adapts a Bayan ERP product to the publish flow. The ERP id becomes the
/// SKU (Keeta `openItemCode`, HungerStation `sku`) so later stock and price
/// updates can find the product on each platform.
///
/// [category] is the name of the product's parent group in the ERP tree.
ProductModel publishableFromErp(
  ErpProductModel p, {
  String category = '',
  List<AddOnGroup> addOnGroups = const [],
}) {
  final nameIsArabic = _arabic.hasMatch(p.name);
  final latinShortName =
      p.shortName.isNotEmpty && !_arabic.hasMatch(p.shortName);
  return ProductModel(
    id: 'erp-${p.id}',
    sku: '${p.id}',
    name: nameIsArabic && latinShortName ? p.shortName : p.name,
    nameAr: nameIsArabic ? p.name : '',
    category: category,
    addOnGroups: addOnGroups,
    unit: '',
    salePrice: erpSalePrice(p),
    costPrice: 0,
    stockQty: p.quantity,
    isActive: true,
  );
}
