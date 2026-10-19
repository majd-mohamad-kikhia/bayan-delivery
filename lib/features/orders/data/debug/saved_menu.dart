import '../../../bayan_erp/data/models/erp_product_model.dart';
import '../../../bayan_erp/data/repositories/bayan_erp_repository.dart';
import '../../../products/data/erp_product_adapter.dart';
import '../../../products/data/models/product_record.dart';

/// The menu a mock order is made from: the products the user saved by adding
/// them to a platform (the ones kept in the local products table), priced from
/// Al-Bayan, plus the add-ons from Al-Bayan's "إضافات" group.
///
/// Shape the mock order servers expect: `{ products: [{sku, name, price}],
/// addOns: [...] }`, prices in minor units.
Future<Map<String, Object?>> savedMenuForMockOrders({
  required Iterable<ProductRecord> saved,
  required BayanErpRepository erp,
}) async {
  final onAPlatform = [
    for (final record in saved)
      if (record.keetaNum != null ||
          record.hungerNum != null ||
          record.careemNum != null)
        record,
  ];
  if (onAPlatform.isEmpty) {
    throw StateError(
      'No saved products yet. Add some to the platforms from Bayan ERP first.',
    );
  }

  final catalog = await _loadCatalog(erp);
  final priceById = {for (final p in catalog) '${p.id}': erpSalePrice(p)};

  final products = <Map<String, Object?>>[
    for (final record in onAPlatform)
      if ((priceById[record.bayanNum] ?? 0) > 0)
        {
          'sku': record.bayanNum,
          'name': record.name,
          'price': (priceById[record.bayanNum]! * 100).round(),
        },
  ];
  if (products.isEmpty) {
    throw StateError('The saved products have no price in Bayan ERP.');
  }

  return {
    'products': products,
    'addOns': [
      for (final group in addOnsOf(catalog).groups)
        for (final option in group.options)
          if (option.price > 0)
            {
              'sku': option.sku,
              'name': option.name,
              'price': (option.price * 100).round(),
            },
    ],
  };
}

Future<List<ErpProductModel>> _loadCatalog(BayanErpRepository erp) async {
  const page = 500;
  final all = <ErpProductModel>[];
  for (var offset = 0; ; offset += page) {
    final chunk = await erp.getProducts(offset: offset, limit: page);
    all.addAll(chunk);
    if (chunk.length < page) return all;
  }
}
