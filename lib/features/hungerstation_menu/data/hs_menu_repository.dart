import 'package:flutter/foundation.dart';

import '../../../core/platforms/platforms.dart';

/// A category that has products on HungerStation.
@immutable
final class HsMenuCategory {
  const HsMenuCategory({required this.id, required this.name});

  /// Products with no category are listed under this id.
  static const uncategorizedId = '';

  final String id;
  final String name;
}

/// One product as HungerStation lists it. HungerStation identifies it by SKU,
/// which is the Al-Bayan product number.
@immutable
final class HsMenuProduct {
  const HsMenuProduct({
    required this.sku,
    required this.name,
    required this.altName,
    required this.price,
    required this.active,
    required this.categoryIds,
    this.quantity,
  });

  final String sku;
  final String name;

  /// The title in the other language, when there is one.
  final String altName;
  final double price;
  final bool active;
  final int? quantity;
  final List<String> categoryIds;
}

/// What is on HungerStation right now: only the categories that hold products
/// (its own taxonomy lists every category it has).
@immutable
final class HsMenu {
  const HsMenu({required this.categories, required this.products});

  final List<HsMenuCategory> categories;
  final List<HsMenuProduct> products;

  List<HsMenuProduct> productsOf(String categoryId) => [
    for (final p in products)
      if (categoryId == HsMenuCategory.uncategorizedId
          ? p.categoryIds.isEmpty
          : p.categoryIds.contains(categoryId))
        p,
  ];
}

/// Reads the HungerStation catalog and changes what its API lets a vendor
/// change: price and availability, by SKU. (Names, categories and order are
/// not editable there.)
class HsMenuRepository {
  HsMenuRepository(this._apis);

  final PlatformApis _apis;

  static const _pageSize = 100;

  Future<HsMenu> load() async {
    final results = await Future.wait([_categories(), _products()]);
    return parse(results[0], results[1]);
  }

  Future<List<dynamic>> _categories() async {
    final body = await _apis.hungerStation.categories(onlyLeaves: false);
    final list = body['categories'];
    return list is List ? list : const [];
  }

  Future<List<dynamic>> _products() async {
    final all = <dynamic>[];
    for (var page = 1; ; page++) {
      final body = await _apis.hungerStation.products(
        page: page,
        pageSize: _pageSize,
      );
      final list = body['products'] ?? body['items'];
      final found = list is List ? list : const [];
      all.addAll(found);
      if (found.length < _pageSize) return all;
    }
  }

  Future<void> setPrice(String sku, double price) =>
      _update(HsProductUpdate(sku: sku, price: price));

  Future<void> setAvailable(String sku, bool available) =>
      _update(HsProductUpdate(sku: sku, active: available));

  Future<void> _update(HsProductUpdate update) async {
    final job = await _apis.hungerStation.updateProducts(products: [update]);
    final result = job.id.isEmpty
        ? job
        : await _apis.hungerStation.waitForCatalogJob(
            job.id,
            timeout: const Duration(seconds: 20),
          );
    if (result.isFailed) {
      throw StateError(
        result.rejectionFor(update.sku) ??
            'HungerStation did not accept the change',
      );
    }
    final rejection = result.rejectionFor(update.sku);
    if (rejection != null) throw StateError(rejection);
  }

  @visibleForTesting
  static HsMenu parse(List<dynamic> categories, List<dynamic> products) {
    final names = <String, String>{};
    for (final c in categories.whereType<Map>()) {
      final id = '${c['global_id'] ?? c['id'] ?? ''}';
      if (id.isEmpty) continue;
      final name = _title((c['details'] as Map?)?['name'] ?? c['name']);
      if (name.name.isNotEmpty) names[id] = name.name;
    }

    final parsed = <HsMenuProduct>[];
    for (final item in products.whereType<Map>()) {
      final sku = '${item['sku'] ?? item['vendor_sku'] ?? ''}'.trim();
      if (sku.isEmpty) continue;
      final title = _title(item['title'] ?? item['name']);
      parsed.add(
        HsMenuProduct(
          sku: sku,
          name: title.name.isEmpty ? sku : title.name,
          altName: title.alt,
          price: _price(item['price']),
          active: item['active'] != false && item['is_active'] != false,
          quantity: item['quantity'] is num
              ? (item['quantity'] as num).toInt()
              : null,
          categoryIds: _categoryIds(item['categories'] ?? item['category']),
        ),
      );
    }

    final used = {for (final p in parsed) ...p.categoryIds};
    final listed = [
      for (final id in used) HsMenuCategory(id: id, name: names[id] ?? id),
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return HsMenu(
      categories: [
        ...listed,
        if (parsed.any((p) => p.categoryIds.isEmpty))
          const HsMenuCategory(
            id: HsMenuCategory.uncategorizedId,
            name: 'Uncategorized',
          ),
      ],
      products: parsed,
    );
  }

  /// HungerStation titles are keyed by locale (`en_SA`, `ar_SA`).
  static ({String name, String alt}) _title(Object? value) {
    if (value is String) return (name: value.trim(), alt: '');
    if (value is Map && value.isNotEmpty) {
      String? english;
      String? other;
      for (final e in value.entries) {
        final text = '${e.value}'.trim();
        if (text.isEmpty) continue;
        if ('${e.key}'.startsWith('en')) {
          english ??= text;
        } else {
          other ??= text;
        }
      }
      final name = english ?? other ?? '';
      final alt = english != null ? (other ?? '') : '';
      return (name: name, alt: alt);
    }
    return (name: '', alt: '');
  }

  static double _price(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    if (value is Map) return _price(value['amount'] ?? value['value']);
    return 0;
  }

  static List<String> _categoryIds(Object? value) {
    final list = value is List ? value : (value == null ? const [] : [value]);
    return [
      for (final c in list)
        if (c is Map) '${c['global_id'] ?? c['id'] ?? ''}' else '$c',
    ].where((id) => id.isNotEmpty).toList();
  }
}
