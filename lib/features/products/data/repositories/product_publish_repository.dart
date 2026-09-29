import 'dart:async';

import 'package:equatable/equatable.dart';

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

/// What happened when publishing to one platform; the UI words it.
enum PublishNotice {
  /// Live on the platform.
  added,

  /// Live, but no product id came back to attach the images to.
  addedWithoutImages,

  /// Live, but the images were refused ([PublishOutcome.detail]: why).
  addedImagesRejected,

  /// Live on HungerStation, but availability and stock weren't applied:
  /// no default vendor (`HS_VENDOR_ID`) is configured.
  addedWithoutStock,

  /// Accepted; the platform is still processing it.
  processing,

  /// Failed with the platform's or network's own words in the detail.
  error,

  /// The platform refused the product (detail: its reason, if any).
  rejected,

  /// No platform category has the name in the detail.
  unknownCategory,
  noJobId,

  /// The category in the detail was created but its id never came back.
  categoryNotCreated,
  noShop,
  severalShops,

  // Checked before any request.
  nameRequired,
  priceRequired,
  pickupPriceRequired,
  categoryRequired,
  sellingHoursRequired,
  servingSizeOutOfRange,
  caffeineNegative,
  nutritionNegative,

  /// The offending URL is the detail.
  invalidImageUrl,
  barcodeRequired,
  baseWeightRequired,
  stockNegative,
  maxPerOrderTooLow,
}

/// Result of publishing one product to one platform. Never an exception:
/// every failure becomes a [notice], plus the platform's own text or the
/// offending value in [detail] when there is one.
final class PublishOutcome extends Equatable {
  const PublishOutcome(this.phase, this.notice, [this.detail]);

  const PublishOutcome.failed(this.notice, [this.detail])
    : phase = PublishPhase.failed;

  final PublishPhase phase;
  final PublishNotice notice;
  final String? detail;

  @override
  List<Object?> get props => [phase, notice, detail];
}

/// Stops a publish with a [PublishNotice]; [ProductPublishRepository.publish]
/// turns it into a failed [PublishOutcome].
final class _PublishStop implements Exception {
  const _PublishStop(this.notice, [this.detail]);

  final PublishNotice notice;
  final String? detail;
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
    } on _PublishStop catch (e) {
      return PublishOutcome.failed(e.notice, e.detail);
    } on ApiException catch (e) {
      return PublishOutcome.failed(PublishNotice.error, e.message);
    } on ArgumentError catch (e) {
      return PublishOutcome.failed(PublishNotice.error, '${e.message}');
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
      final reason = _describe(response.errorList.first);
      return reason == null
          ? const PublishOutcome.failed(PublishNotice.rejected)
          : PublishOutcome.failed(PublishNotice.error, reason);
    }

    // External image URLs can't go in the create call; bind them to the
    // new SPU (Keeta fetches them asynchronously, errors → webhook 1201).
    if (content.imageUrls.isEmpty) {
      return const PublishOutcome(PublishPhase.published, PublishNotice.added);
    }
    final spuId = response.dataList
        .where((spu) => spu['openItemCode'] == content.sku)
        .map((spu) => spu['id'])
        .whereType<num>()
        .firstOrNull;
    if (spuId == null) {
      return const PublishOutcome(
        PublishPhase.published,
        PublishNotice.addedWithoutImages,
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
          PublishNotice.addedImagesRejected,
          _describe(bind.errorList),
        );
      }
    } on ApiException catch (e) {
      return PublishOutcome(
        PublishPhase.published,
        PublishNotice.addedImagesRejected,
        e.message,
      );
    }
    return const PublishOutcome(PublishPhase.published, PublishNotice.added);
  }

  void _validateKeeta(ListingContent content, KeetaListing listing) {
    _requireName(content);
    _requirePrice(listing.price, PublishNotice.priceRequired);
    _check(listing.category.trim().isNotEmpty, PublishNotice.categoryRequired);
    if (listing.limitedHours) {
      _check(listing.sellingHours != null, PublishNotice.sellingHoursRequired);
    }
    if (listing.pickup) {
      _requirePrice(listing.pickupPrice, PublishNotice.pickupPriceRequired);
    }
    final serving = listing.servingSize;
    _check(
      serving == null || (serving >= 1 && serving <= 9),
      PublishNotice.servingSizeOutOfRange,
    );
    _check((listing.caffeineMg ?? 0) >= 0, PublishNotice.caffeineNegative);
    _check(
      listing.nutrition.values.every((value) => value >= 0),
      PublishNotice.nutritionNegative,
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
      _check(shops.isNotEmpty, PublishNotice.noShop);
      _check(shops.length == 1, PublishNotice.severalShops);
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
        throw _PublishStop(PublishNotice.categoryNotCreated, name);
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
        return PublishOutcome.failed(PublishNotice.unknownCategory, category);
      }
    }

    final job = await hs.addProducts(
      vendorIds: [if (vendorId.isNotEmpty) vendorId else '*'],
      products: [hsProduct(content, listing, taxonomy, categoryId)],
    );
    if (job.id.isEmpty) {
      return const PublishOutcome.failed(PublishNotice.noJobId);
    }

    final result = await hs.waitForCatalogJob(job.id, timeout: hsJobTimeout);
    if (result.isFailed) {
      final reason =
          result.rejectionFor(content.sku) ?? _describe(result.raw['result']);
      return reason == null
          ? const PublishOutcome.failed(PublishNotice.rejected)
          : PublishOutcome.failed(PublishNotice.error, reason);
    }
    if (!result.isCompleted) {
      return const PublishOutcome(
        PublishPhase.processing,
        PublishNotice.processing,
      );
    }
    // A completed job can still reject this product (e.g. images: poor quality).
    final rejection = result.rejectionFor(content.sku);
    if (rejection != null) {
      return PublishOutcome.failed(PublishNotice.rejected, rejection);
    }

    // Availability and stock aren't part of the add call.
    if (vendorId.isEmpty) {
      return const PublishOutcome(
        PublishPhase.published,
        PublishNotice.addedWithoutStock,
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
    return const PublishOutcome(PublishPhase.published, PublishNotice.added);
  }

  void _validateHungerStation(ListingContent content, HsListing listing) {
    _requireName(content);
    _requirePrice(listing.price, PublishNotice.priceRequired);
    _check(
      listing.soldByWeight || content.barcode.trim().isNotEmpty,
      PublishNotice.barcodeRequired,
    );
    if (listing.soldByWeight) {
      _check(
        (listing.baseWeight?.value ?? 0) > 0,
        PublishNotice.baseWeightRequired,
      );
    }
    _check((listing.quantity ?? 0) >= 0, PublishNotice.stockNegative);
    _check(
      listing.maxPerOrder == null || listing.maxPerOrder! >= 1,
      PublishNotice.maxPerOrderTooLow,
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

  static void _check(bool condition, PublishNotice notice, [String? detail]) {
    if (!condition) throw _PublishStop(notice, detail);
  }

  static void _requireName(ListingContent content) => _check(
    content.nameEn.trim().isNotEmpty || content.nameAr.trim().isNotEmpty,
    PublishNotice.nameRequired,
  );

  static void _requirePrice(double? price, PublishNotice notice) =>
      _check(price != null && price > 0, notice);

  static void _requireImageUrls(List<String> urls) {
    for (final url in urls) {
      final uri = Uri.tryParse(url);
      _check(
        uri != null &&
            (uri.scheme == 'https' || uri.scheme == 'http') &&
            uri.host.isNotEmpty &&
            !uri.hasPort,
        PublishNotice.invalidImageUrl,
        url,
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
