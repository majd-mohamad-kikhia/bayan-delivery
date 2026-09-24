import 'dart:async';

import '../../../../core/network/api_exception.dart';
import '../../../../core/platforms/common/platform_utils.dart';
import '../../../../core/platforms/platforms.dart';
import '../../../../core/storage/app_preferences.dart';
import '../../../../core/utils/async_cache.dart';
import '../models/listing_models.dart';

enum PublishPhase {
  idle,
  publishing,

  /// Live on the platform.
  published,

  /// Accepted, but the platform is still processing it (async job).
  processing,
  failed;

  /// Nothing left to do for this platform.
  bool get isDone => this == published || this == processing;
}

/// Result of publishing one product to one platform. Never an exception:
/// every failure becomes a readable [message].
final class PublishOutcome {
  const PublishOutcome(this.phase, this.message);

  const PublishOutcome.failed(this.message) : phase = PublishPhase.failed;

  final PublishPhase phase;
  final String message;
}

/// Publishes Al-Bayan products to delivery platforms, sending exactly the
/// fields each add-product API defines (Keeta menu OpenAPI 3.0.3,
/// HungerStation Partner API v2.0.2).
///
/// - Input is validated against each platform's rules before any request,
///   so a missing barcode or pickup price costs no round-trip.
/// - Everything besides the product itself (Keeta shop, category ids,
///   HungerStation taxonomy and locales, tokens) is cached and can be
///   [prewarm]ed while the form is being filled, so the publish is usually
///   one request per platform.
/// - A missing Keeta category is created once, even when several products
///   need it at the same moment.
class ProductPublishRepository {
  ProductPublishRepository({
    required PlatformApis apis,
    required AppPreferences preferences,
    this.hsJobTimeout = const Duration(seconds: 20),
  }) : _apis = apis,
       _preferences = preferences;

  /// Platforms with a publishing integration, in display order.
  static const List<String> supportedPlatforms = ['keeta', 'hungerstation'];

  static final RegExp _arabic = RegExp(r'[؀-ۿ]');

  final PlatformApis _apis;
  final AppPreferences _preferences;

  /// How long to wait for HungerStation's async catalog job before
  /// reporting the product as still processing.
  final Duration hsJobTimeout;

  final AsyncCache<int> _keetaShop = AsyncCache(
    maxAge: const Duration(minutes: 30),
  );
  final AsyncCache<_Categories<int>> _keetaCategories = AsyncCache(
    maxAge: const Duration(minutes: 10),
  );
  final AsyncCache<_HsTaxonomy> _hsTaxonomy = AsyncCache(
    maxAge: const Duration(minutes: 30),
  );
  final SingleFlight<int> _keetaCategoryCreation = SingleFlight<int>();

  /// Starts loading what [platformId] needs, ignoring errors — the real
  /// publish reports them.
  void prewarm(String platformId) {
    final Future<Object?>? work = switch (platformId) {
      'keeta' => _keetaShopId().then(_keetaCategoryIndex),
      'hungerstation' => _hsCategories(),
      _ => null,
    };
    work?.ignore();
  }

  /// Existing category names on [platformId], for autocomplete. Empty when
  /// they can't be loaded (the publish will report why).
  Future<List<String>> categoryNames(String platformId) async {
    try {
      return switch (platformId) {
        'keeta' => (await _keetaCategoryIndex(await _keetaShopId())).names,
        'hungerstation' => (await _hsCategories()).names,
        _ => const <String>[],
      };
    } on Object {
      return const [];
    }
  }

  Future<PublishOutcome> publish(
    ListingContent content,
    PlatformListing listing,
  ) async {
    try {
      return switch (listing) {
        KeetaListing() => await _publishToKeeta(content, listing),
        HsListing() => await _publishToHungerStation(content, listing),
      };
    } on ApiException catch (e) {
      return PublishOutcome.failed(e.message);
    } on ArgumentError catch (e) {
      return PublishOutcome.failed('${e.message}');
    }
  }

  // ── Keeta ─────────────────────────────────────────────────────────────────

  Future<PublishOutcome> _publishToKeeta(
    ListingContent content,
    KeetaListing listing,
  ) async {
    _validateKeeta(content, listing);
    final shopId = await _keetaShopId();
    final categoryId = await _keetaCategoryId(shopId, listing.category.trim());

    final response = await _apis.keeta.menu.createProducts(
      shopId: shopId,
      spuList: [keetaSpu(content, listing, categoryId)],
    );
    if (response.hasPartialFailure) {
      return PublishOutcome.failed(
        _describe(response.errorList.first) ?? 'Keeta rejected the product.',
      );
    }

    // External image URLs can't go in the create call; bind them to the
    // new SPU (Keeta fetches them asynchronously, errors → webhook 1201).
    if (content.imageUrls.isEmpty) {
      return const PublishOutcome(PublishPhase.published, 'Added to Keeta');
    }
    final spuId = response.dataList
        .where((spu) => spu['openItemCode'] == content.sku)
        .map((spu) => spu['id'])
        .whereType<num>()
        .firstOrNull;
    if (spuId == null) {
      return const PublishOutcome(
        PublishPhase.published,
        'Added to Keeta · images not attached (no product id returned)',
      );
    }
    try {
      final bind = await _apis.keeta.menu.bindProductPictures(
        shopId: shopId,
        urlsBySpuId: {spuId.toInt(): content.imageUrls},
      );
      if (bind.hasPartialFailure) {
        return PublishOutcome(
          PublishPhase.published,
          'Added to Keeta · images: ${_describe(bind.errorList) ?? 'rejected'}',
        );
      }
    } on ApiException catch (e) {
      return PublishOutcome(
        PublishPhase.published,
        'Added to Keeta · images: ${e.message}',
      );
    }
    return const PublishOutcome(PublishPhase.published, 'Added to Keeta');
  }

  void _validateKeeta(ListingContent content, KeetaListing listing) {
    _requireName(content);
    _requirePrice(listing.price, 'Price');
    checkArgument(
      listing.category.trim().isNotEmpty,
      'category',
      'Keeta needs a menu category',
    );
    if (listing.limitedHours) {
      checkArgument(
        listing.sellingHours != null,
        'sellingHours',
        'Enter the selling hours as HH:mm – HH:mm',
      );
    }
    if (listing.pickup) _requirePrice(listing.pickupPrice, 'Pickup price');
    final serving = listing.servingSize;
    checkArgument(
      serving == null || (serving >= 1 && serving <= 9),
      'servingSize',
      'Serving size must be 1 to 9 people',
    );
    checkArgument(
      (listing.caffeineMg ?? 0) >= 0,
      'caffeine',
      'Caffeine cannot be negative',
    );
    checkArgument(
      listing.nutrition.values.every((value) => value >= 0),
      'nutrition',
      'Nutrition values cannot be negative',
    );
    _requireImageUrls(content.imageUrls);
  }

  /// SPU payload for `/product/spu/batchcreate` (one SKU).
  static Map<String, Object?> keetaSpu(
    ListingContent content,
    KeetaListing listing,
    int categoryId,
  ) {
    final hours = listing.limitedHours ? listing.sellingHours : null;
    return {
      ..._keetaText('name', content.nameEn, content.nameAr),
      ..._keetaText(
        'description',
        content.descriptionEn,
        content.descriptionAr,
      ),
      'status': listing.available ? 1 : 0,
      'isSpecialty': listing.signature ? 1 : 0,
      'openItemCode': content.sku,
      'shopCategoryList': [
        {'id': categoryId},
      ],
      'availableTime': hours == null
          ? {'code': 0}
          : {'code': 1, 'values': List.filled(7, hours.wire)},
      'userGetModeList': ['delivery', if (listing.pickup) 'pickup'],
      'skuList': [
        {
          'price': _money(listing.price),
          if (listing.pickup) 'pickPrice': _money(listing.pickupPrice!),
          'openItemCode': content.sku,
          'allergens': [
            for (final allergen in listing.allergens) allergen.wire,
          ],
          if (listing.nutrition.isNotEmpty)
            'nutritionalInfo': {
              for (final entry in listing.nutrition.entries)
                entry.key.wire: entry.value,
            },
          'servingSize': ?listing.servingSize,
          'caffeine': ?listing.caffeineMg,
        },
      ],
    };
  }

  /// Keeta bilingual text: English is the source and Arabic its
  /// merchant-provided translation (or Arabic alone when there's no
  /// English). [field] is `name` or `description` — their keys differ.
  static Map<String, Object?> _keetaText(
    String field,
    String english,
    String arabic,
  ) {
    final en = english.trim();
    final ar = arabic.trim();
    if (en.isEmpty && ar.isEmpty) return const {};

    final isName = field == 'name';
    final source = isName ? 'sourceLanguageType' : 'descSourceLanguageType';
    final target = isName ? 'targetLanguageType' : 'descTargetLanguageType';
    final translation = isName ? 'nameTranslation' : 'descriptionTranslation';
    final translateType = isName
        ? 'nameTranslateType'
        : 'descriptionTranslateType';

    if (en.isEmpty) return {field: ar, source: 'ar'};
    return {
      field: en,
      source: _arabic.hasMatch(en) ? 'ar' : 'en',
      if (ar.isNotEmpty && ar != en) ...{
        translation: ar,
        target: 'ar',
        translateType: 1,
      },
    };
  }

  /// The shop chosen in the Merchants panel, else the account's only shop.
  Future<int> _keetaShopId() async {
    final selected = _preferences.keetaShopId;
    if (selected != null) return selected;
    return _keetaShop.get('default', () async {
      final shops = await _apis.keeta.account.authorizedShops();
      checkArgument(
        shops.isNotEmpty,
        'shop',
        'No Keeta shop is authorized for this account',
      );
      checkArgument(
        shops.length == 1,
        'shop',
        'Several Keeta shops — choose one in Merchants first',
      );
      return (shops.single['id'] as num).toInt();
    });
  }

  Future<_Categories<int>> _keetaCategoryIndex(
    int shopId, {
    bool refresh = false,
  }) => _keetaCategories.get('$shopId', () async {
    final data = await _apis.keeta.menu.categories(shopId);
    final categories = _Categories<int>();
    for (final category
        in data is List ? data.whereType<Map>() : const <Map>[]) {
      final id = category['id'];
      if (id is! num) continue;
      categories.add(id.toInt(), [
        category['name'],
        category['nameTranslation'],
      ]);
    }
    return categories;
  }, refresh: refresh);

  Future<int> _keetaCategoryId(int shopId, String name) async {
    final cached = (await _keetaCategoryIndex(shopId)).idOf(name);
    if (cached != null) return cached;

    // Maybe created elsewhere since we cached — look once more first.
    final index = await _keetaCategoryIndex(shopId, refresh: true);
    final fresh = index.idOf(name);
    if (fresh != null) return fresh;

    return _keetaCategoryCreation.run('$shopId|${_key(name)}', () async {
      final response = await _apis.keeta.menu.createCategory(
        shopId: shopId,
        category: {
          'name': name,
          'sourceLanguageType': _arabic.hasMatch(name) ? 'ar' : 'en',
          'type': 0,
        },
      );
      final id = response.dataMap['id'];
      if (id is num) {
        index.add(id.toInt(), [name]);
        return id.toInt();
      }
      _keetaCategories.invalidate('$shopId');
      final created = (await _keetaCategoryIndex(shopId)).idOf(name);
      if (created == null) {
        throw ArgumentError('Keeta did not return the new category "$name"');
      }
      return created;
    });
  }

  // ── HungerStation ─────────────────────────────────────────────────────────

  Future<PublishOutcome> _publishToHungerStation(
    ListingContent content,
    HsListing listing,
  ) async {
    _validateHungerStation(content, listing);
    final hs = _apis.hungerStation;
    final vendorId = _apis.credentials.hungerStation.vendorId;
    final taxonomy = await _hsCategories();

    String? categoryId;
    final category = listing.category.trim();
    if (category.isNotEmpty) {
      categoryId =
          taxonomy.idOf(category) ??
          (await _hsCategories(refresh: true)).idOf(category);
      if (categoryId == null) {
        return PublishOutcome.failed(
          'HungerStation has no category named "$category".',
        );
      }
    }

    final job = await hs.addProducts(
      vendorIds: [if (vendorId.isNotEmpty) vendorId else '*'],
      products: [hsProduct(content, listing, taxonomy, categoryId)],
    );
    if (job.id.isEmpty) {
      return const PublishOutcome.failed(
        'HungerStation did not return a job id.',
      );
    }

    final result = await hs.waitForCatalogJob(job.id, timeout: hsJobTimeout);
    if (result.isFailed) {
      return PublishOutcome.failed(
        result.rejectionFor(content.sku) ??
            _describe(result.raw['result']) ??
            'HungerStation could not add the product.',
      );
    }
    if (!result.isCompleted) {
      return const PublishOutcome(
        PublishPhase.processing,
        'HungerStation is still processing it',
      );
    }
    // A completed job can still reject this product (e.g. images: poor quality).
    final rejection = result.rejectionFor(content.sku);
    if (rejection != null) {
      return PublishOutcome.failed('HungerStation rejected it — $rejection');
    }

    // Availability and stock aren't part of the add call.
    if (vendorId.isEmpty) {
      return const PublishOutcome(
        PublishPhase.published,
        'Added to HungerStation · set HS_VENDOR_ID to apply availability and stock',
      );
    }
    await hs.updateProducts(
      products: [
        HsProductUpdate(
          sku: content.sku,
          active: listing.available,
          quantity: listing.quantity,
          maximumSalesQuantity: listing.maxPerOrder,
        ),
      ],
    );
    return const PublishOutcome(
      PublishPhase.published,
      'Added to HungerStation',
    );
  }

  void _validateHungerStation(ListingContent content, HsListing listing) {
    _requireName(content);
    _requirePrice(listing.price, 'Price');
    checkArgument(
      listing.soldByWeight || content.barcode.trim().isNotEmpty,
      'barcode',
      'HungerStation needs a barcode unless the product is sold by weight',
    );
    if (listing.soldByWeight) {
      checkArgument(
        (listing.baseWeight?.value ?? 0) > 0,
        'baseWeight',
        'Enter the base weight the price applies to',
      );
    }
    checkArgument(
      (listing.quantity ?? 0) >= 0,
      'quantity',
      'Stock cannot be negative',
    );
    checkArgument(
      listing.maxPerOrder == null || listing.maxPerOrder! >= 1,
      'maxPerOrder',
      'Max per order must be at least 1',
    );
    _requireImageUrls(content.imageUrls);
  }

  /// Product payload for `POST /v2/chains/{chain_id}/catalog`.
  static Map<String, Object?> hsProduct(
    ListingContent content,
    HsListing listing,
    HsCatalogLocales locales,
    String? categoryId,
  ) {
    Map<String, String> localized(String english, String arabic) => {
      if (english.trim().isNotEmpty) locales.englishLocale: english.trim(),
      if (arabic.trim().isNotEmpty) locales.arabicLocale: arabic.trim(),
    };
    Map<String, Object> weight(String field, HsWeight? value) => value == null
        ? const {}
        : {field: value.value, '${field}_unit': value.unit.wire};

    final description = localized(content.descriptionEn, content.descriptionAr);
    final barcode = content.barcode.trim();
    return {
      'sku': content.sku,
      'title': localized(content.nameEn, content.nameAr),
      if (description.isNotEmpty) 'description': description,
      if (barcode.isNotEmpty) 'barcodes': [barcode],
      if (content.imageUrls.isNotEmpty) 'images': content.imageUrls,
      if (categoryId != null) 'categories': [categoryId],
      'price': listing.price,
      if (listing.soldByWeight) ...{
        'is_sold_by_weight': true,
        'weight_specifications': {
          ...weight('base_weight', listing.baseWeight),
          ...weight('average_weight_per_piece', listing.averageWeightPerPiece),
          ...weight('minimum_starting_weight', listing.minimumStartingWeight),
        },
      },
    };
  }

  /// Active leaf categories plus the locales the catalog uses — titles are
  /// keyed by locale (`en_SA`, …). Empty when no default vendor is set.
  Future<_HsTaxonomy> _hsCategories({bool refresh = false}) {
    final vendorId = _apis.credentials.hungerStation.vendorId;
    if (vendorId.isEmpty) return Future.value(_HsTaxonomy.empty);
    return _hsTaxonomy.get(vendorId, () async {
      final body = await _apis.hungerStation.categories();
      return _HsTaxonomy.parse(body['categories']);
    }, refresh: refresh);
  }

  // ── Shared checks & helpers ───────────────────────────────────────────────

  static void _requireName(ListingContent content) => checkArgument(
    content.nameEn.trim().isNotEmpty || content.nameAr.trim().isNotEmpty,
    'name',
    'Enter a product name',
  );

  static void _requirePrice(double? price, String label) => checkArgument(
    price != null && price > 0,
    'price',
    '$label must be greater than 0',
  );

  static void _requireImageUrls(List<String> urls) {
    for (final url in urls) {
      final uri = Uri.tryParse(url);
      checkArgument(
        uri != null &&
            (uri.scheme == 'https' || uri.scheme == 'http') &&
            uri.host.isNotEmpty &&
            !uri.hasPort,
        'imageUrls',
        'Image URLs must be http(s) links without a custom port: $url',
      );
    }
  }

  /// Both platforms accept at most two decimals.
  static String _money(double value) => value.toStringAsFixed(2);

  static String _key(String name) => name.trim().toLowerCase();

  /// First human-readable message inside a platform error payload.
  static String? _describe(Object? value, [int depth = 0]) {
    if (depth > 3 || value == null) return null;
    if (value is String) return value.trim().isEmpty ? null : value.trim();
    if (value is Map) {
      for (final key in const [
        'errorMsg',
        'errorMessage',
        'message',
        'msg',
        'reason',
        'error',
        'errors',
        'detail',
      ]) {
        final text = _describe(value[key], depth + 1);
        if (text != null) return text;
      }
    }
    if (value is List) {
      for (final item in value) {
        final text = _describe(item, depth + 1);
        if (text != null) return text;
      }
    }
    return null;
  }
}

/// Locale keys a HungerStation catalog uses for titles and descriptions.
abstract interface class HsCatalogLocales {
  String get englishLocale;
  String get arabicLocale;
}

/// Category lookup by normalized name, plus display names for suggestions.
final class _Categories<Id> {
  final Map<String, Id> _ids = {};
  final List<String> names = [];

  void add(Id id, Iterable<Object?> labels) {
    var first = true;
    for (final label in labels) {
      if (label is! String || label.trim().isEmpty) continue;
      _ids[ProductPublishRepository._key(label)] = id;
      if (first) names.add(label.trim());
      first = false;
    }
  }

  Id? idOf(String name) =>
      name.trim().isEmpty ? null : _ids[ProductPublishRepository._key(name)];
}

final class _HsTaxonomy implements HsCatalogLocales {
  _HsTaxonomy(this._categories, this.englishLocale, this.arabicLocale);

  static final empty = _HsTaxonomy(_Categories<String>(), 'en_SA', 'ar_SA');

  factory _HsTaxonomy.parse(Object? categories) {
    final index = _Categories<String>();
    String? english;
    String? arabic;
    for (final category
        in categories is List ? categories.whereType<Map>() : const <Map>[]) {
      final id = category['global_id']?.toString();
      final names = (category['details'] as Map?)?['name'];
      if (id == null || names is! Map || category['active'] == false) continue;
      for (final locale in names.keys.map((key) => '$key')) {
        english ??= locale.startsWith('en') ? locale : null;
        arabic ??= locale.startsWith('ar') ? locale : null;
      }
      // English first so it becomes the suggested display name.
      index.add(id, [
        for (final entry in names.entries)
          if ('${entry.key}'.startsWith('en')) entry.value,
        for (final entry in names.entries)
          if (!'${entry.key}'.startsWith('en')) entry.value,
      ]);
    }
    return _HsTaxonomy(
      index,
      english ?? empty.englishLocale,
      arabic ?? empty.arabicLocale,
    );
  }

  final _Categories<String> _categories;

  @override
  final String englishLocale;

  @override
  final String arabicLocale;

  List<String> get names => _categories.names;

  String? idOf(String name) => _categories.idOf(name);
}
