import '../../../core/platforms/platforms.dart';
import '../../../core/storage/app_preferences.dart';

/// A Keeta menu category.
class MenuCategory {
  const MenuCategory({required this.id, required this.name});

  final int id;
  final String name;
}

/// A Keeta product (SPU) as the menu manager shows it. [raw] is the whole
/// object Keeta returned: updates send it back with only the edited fields
/// changed, because Keeta rewrites the product from what it receives.
class MenuProduct {
  const MenuProduct({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.available,
    required this.categoryIds,
    required this.raw,
  });

  factory MenuProduct.fromJson(Map<String, dynamic> json) {
    final skus = json['skuList'] is List ? json['skuList'] as List : const [];
    final firstSku = skus.whereType<Map>().firstOrNull;
    return MenuProduct(
      id: (json['id'] as num).toInt(),
      name: '${json['name'] ?? ''}',
      description: '${json['description'] ?? ''}',
      price: double.tryParse('${firstSku?['price']}') ?? 0,
      available: ((json['status'] as num?) ?? 0) == 1,
      categoryIds: [
        for (final c
            in (json['shopCategoryList'] as List? ?? const []).whereType<Map>())
          if (c['id'] is num) (c['id'] as num).toInt(),
      ],
      raw: json,
    );
  }

  final int id;
  final String name;
  final String description;
  final double price;
  final bool available;
  final List<int> categoryIds;
  final Map<String, dynamic> raw;
}

/// The shop's whole menu, in display order.
class KeetaMenu {
  const KeetaMenu({required this.categories, required this.products});

  final List<MenuCategory> categories;

  /// Every product, already ordered inside its category.
  final List<MenuProduct> products;

  List<MenuProduct> productsOf(int categoryId) => [
    for (final p in products)
      if (p.categoryIds.contains(categoryId)) p,
  ];
}

/// Reads and edits the Keeta menu: product name / price / availability /
/// delete, and the order of categories and products.
class KeetaMenuRepository {
  KeetaMenuRepository({
    required PlatformApis apis,
    required AppPreferences preferences,
  }) : _apis = apis,
       _preferences = preferences;

  final PlatformApis _apis;
  final AppPreferences _preferences;
  int? _shopId;

  Future<int> _shop() async {
    final selected = _preferences.keetaShopId;
    if (selected != null) return selected;
    if (_shopId != null) return _shopId!;
    final shops = await _apis.keeta.account.authorizedShops();
    if (shops.isEmpty) {
      throw StateError('No Keeta shop is authorized for this account');
    }
    return _shopId = (shops.first['id'] as num).toInt();
  }

  Future<KeetaMenu> load() async {
    final shopId = await _shop();
    final results = await Future.wait([
      _apis.keeta.menu.categories(shopId),
      _apis.keeta.menu.products(shopId),
    ]);
    List<Map<String, dynamic>> maps(Object? data) => [
      for (final m in (data is List ? data : const []).whereType<Map>())
        m.cast<String, dynamic>(),
    ];

    final categories = [
      for (final c in maps(results[0]))
        if (c['id'] is num)
          MenuCategory(
            id: (c['id'] as num).toInt(),
            name: '${c['name'] ?? ''}',
          ),
    ];
    final products = [
      for (final p in maps(results[1]))
        if (p['id'] is num) MenuProduct.fromJson(p),
    ];
    return KeetaMenu(categories: categories, products: products);
  }

  /// [raw] with the given edits: only [name], [description] and [price] (the
  /// first SKU's delivery price) change; Keeta rewrites a product from what it
  /// receives, so everything else goes back as it came.
  static Map<String, Object?> editedBody(
    Map<String, dynamic> raw, {
    String? name,
    String? description,
    double? price,
  }) {
    final body = <String, Object?>{...raw};
    if (name != null) {
      body['name'] = name;
      // A translation of the old name would now be wrong.
      body
        ..remove('nameTranslation')
        ..remove('targetLanguageType')
        ..remove('nameTranslateType');
    }
    if (description != null) body['description'] = description;
    if (price != null) {
      final skus = [
        for (final sku
            in (body['skuList'] as List? ?? const []).whereType<Map>())
          Map<String, Object?>.of(sku.cast<String, Object?>()),
      ];
      if (skus.isEmpty) throw StateError('This product has no SKU to price');
      skus.first['price'] = price.toStringAsFixed(2);
      body['skuList'] = skus;
    }
    return body;
  }

  /// Sends [product] back with the given edits.
  Future<void> updateProduct(
    MenuProduct product, {
    String? name,
    String? description,
    double? price,
  }) async {
    final response = await _apis.keeta.menu.updateProducts(
      shopId: await _shop(),
      spuList: [
        editedBody(
          product.raw,
          name: name,
          description: description,
          price: price,
        ),
      ],
    );
    _check(response);
  }

  /// Applies price / name changes to many products at once, by Keeta product
  /// id, in batches (Keeta takes up to 200 per call; 100 here). Returns the
  /// ids Keeta did not accept; a failed batch fails all of its products.
  Future<Set<int>> updateMany(
    List<({int spuId, double? price, String? name})> changes,
  ) async {
    if (changes.isEmpty) return const {};
    final menu = await load();
    final byId = {for (final p in menu.products) p.id: p};
    final shopId = await _shop();
    final failed = <int>{};

    const batchSize = 100;
    for (var i = 0; i < changes.length; i += batchSize) {
      final batch = changes.sublist(
        i,
        (i + batchSize).clamp(0, changes.length),
      );
      final spuList = <Map<String, Object?>>[];
      final ids = <int>[];
      for (final c in batch) {
        final product = byId[c.spuId];
        if (product == null) {
          failed.add(c.spuId); // no longer on Keeta
          continue;
        }
        spuList.add(editedBody(product.raw, name: c.name, price: c.price));
        ids.add(c.spuId);
      }
      if (spuList.isEmpty) continue;
      try {
        final response = await _apis.keeta.menu.updateProducts(
          shopId: shopId,
          spuList: spuList,
        );
        // Partial failures name the product; anything unnamed fails the batch.
        for (final error in response.errorList) {
          final id = error is Map ? error['id'] : null;
          if (id is num && ids.contains(id.toInt())) {
            failed.add(id.toInt());
          } else {
            failed.addAll(ids);
          }
        }
      } catch (_) {
        failed.addAll(ids);
      }
    }
    return failed;
  }

  Future<void> setAvailable(int productId, bool available) async {
    final response = await _apis.keeta.menu.setProductsAvailable(
      shopId: await _shop(),
      spuIds: [productId],
      available: available,
    );
    _check(response);
  }

  Future<void> deleteProduct(int productId) async {
    final response = await _apis.keeta.menu.deleteProducts(
      shopId: await _shop(),
      spuIds: [productId],
    );
    _check(response);
  }

  Future<void> renameCategory(MenuCategory category, String name) async {
    final response = await _apis.keeta.menu.updateCategory(
      shopId: await _shop(),
      category: {
        'id': category.id,
        'name': name,
        'sourceLanguageType': RegExp(r'[؀-ۿ]').hasMatch(name) ? 'ar' : 'en',
        'type': 0,
        'openItemCode': 'cat-${category.id}',
      },
    );
    _check(response);
  }

  /// Categories can only be deleted when empty (Keeta refuses otherwise).
  Future<void> deleteCategory(int categoryId) async {
    final response = await _apis.keeta.menu.deleteCategories(
      shopId: await _shop(),
      categoryIds: [categoryId],
    );
    _check(response);
  }

  /// [orderedIds] must hold every category of the shop.
  Future<void> reorderCategories(List<int> orderedIds) async {
    final response = await _apis.keeta.menu.reorderCategories(
      shopId: await _shop(),
      sequenceByCategoryId: {
        for (var i = 0; i < orderedIds.length; i++) orderedIds[i]: i + 1,
      },
    );
    _check(response);
  }

  /// [orderedIds] must hold every product of [categoryId].
  Future<void> reorderProducts(int categoryId, List<int> orderedIds) async {
    final response = await _apis.keeta.menu.reorderProducts(
      shopId: await _shop(),
      categoryId: categoryId,
      sequenceBySpuId: {
        for (var i = 0; i < orderedIds.length; i++) orderedIds[i]: i + 1,
      },
    );
    _check(response);
  }

  static void _check(KeetaResponse response) {
    if (response.hasPartialFailure) {
      final first = response.errorList.first;
      final message = first is Map ? (first['message'] ?? first['msg']) : first;
      throw StateError(
        'Keeta rejected the change${message == null ? '' : ': $message'}',
      );
    }
  }
}
