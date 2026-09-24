import 'package:equatable/equatable.dart';

import '../../../../core/platforms/hungerstation/hs_types.dart';
import '../../../../core/platforms/keeta/keeta_types.dart';
import 'product_model.dart';

/// What customers see on every platform. Starts from the Al-Bayan product
/// and can be edited before publishing.
final class ListingContent extends Equatable {
  const ListingContent({
    required this.sku,
    required this.nameEn,
    this.nameAr = '',
    this.descriptionEn = '',
    this.descriptionAr = '',
    this.imageUrls = const [],
    this.barcode = '',
  });

  factory ListingContent.fromProduct(ProductModel product) => ListingContent(
    sku: product.sku,
    nameEn: product.name,
    nameAr: product.nameAr,
    barcode: product.barcode ?? '',
  );

  /// Al-Bayan SKU — the product's id on every platform (Keeta
  /// `openItemCode`, HungerStation `sku`).
  final String sku;
  final String nameEn;
  final String nameAr;
  final String descriptionEn;
  final String descriptionAr;

  /// Public JPG/PNG URLs. Keeta: ≥ 600×450, ≤ 5MB. HungerStation:
  /// ≥ 400×400, white background, product centered.
  final List<String> imageUrls;

  /// GTIN. HungerStation requires one unless the product is sold by weight.
  final String barcode;

  ListingContent copyWith({
    String? nameEn,
    String? nameAr,
    String? descriptionEn,
    String? descriptionAr,
    List<String>? imageUrls,
    String? barcode,
  }) => ListingContent(
    sku: sku,
    nameEn: nameEn ?? this.nameEn,
    nameAr: nameAr ?? this.nameAr,
    descriptionEn: descriptionEn ?? this.descriptionEn,
    descriptionAr: descriptionAr ?? this.descriptionAr,
    imageUrls: imageUrls ?? this.imageUrls,
    barcode: barcode ?? this.barcode,
  );

  @override
  List<Object?> get props => [
    sku,
    nameEn,
    nameAr,
    descriptionEn,
    descriptionAr,
    imageUrls,
    barcode,
  ];
}

/// Platform-specific publish settings — one subtype per platform, holding
/// exactly the fields that platform's add-product API takes.
sealed class PlatformListing extends Equatable {
  const PlatformListing({
    required this.price,
    this.available = true,
    this.category = '',
  });

  /// Default settings for [platformId], seeded from the Al-Bayan product.
  static PlatformListing initialFor(String platformId, ProductModel product) =>
      switch (platformId) {
        'keeta' => KeetaListing(
          price: product.salePrice,
          category: product.category,
        ),
        'hungerstation' => HsListing(
          price: product.salePrice,
          quantity: product.stockQty < 0 ? 0 : product.stockQty.floor(),
        ),
        _ => throw ArgumentError.value(
          platformId,
          'platformId',
          'no publishing integration',
        ),
      };

  String get platformId;

  /// Selling price in the merchant's currency.
  final double price;
  final bool available;

  /// Menu category name (Keeta: in-store category, created if missing;
  /// HungerStation: must exist in its category list).
  final String category;
}

/// Keeta SPU with a single SKU — `/product/spu/batchcreate`.
final class KeetaListing extends PlatformListing {
  const KeetaListing({
    required super.price,
    super.available,
    super.category,
    this.signature = false,
    this.limitedHours = false,
    this.sellingHours,
    this.pickup = false,
    this.pickupPrice,
    this.allergens = const {},
    this.nutrition = const {},
    this.servingSize,
    this.caffeineMg,
  });

  @override
  String get platformId => 'keeta';

  /// `isSpecialty` — at most 15 per store.
  final bool signature;

  /// Sell only during [sellingHours] every day, instead of all day.
  final bool limitedHours;
  final KeetaSellingHours? sellingHours;

  /// Adds `pickup` to `userGetModeList`; needs [pickupPrice].
  final bool pickup;
  final double? pickupPrice;

  final Set<KeetaAllergen> allergens;
  final Map<KeetaNutrient, int> nutrition;

  /// People the portion serves, 1–9.
  final int? servingSize;
  final double? caffeineMg;

  KeetaListing copyWith({
    double? price,
    bool? available,
    String? category,
    bool? signature,
    bool? limitedHours,
    KeetaSellingHours? Function()? sellingHours,
    bool? pickup,
    double? Function()? pickupPrice,
    Set<KeetaAllergen>? allergens,
    Map<KeetaNutrient, int>? nutrition,
    int? Function()? servingSize,
    double? Function()? caffeineMg,
  }) => KeetaListing(
    price: price ?? this.price,
    available: available ?? this.available,
    category: category ?? this.category,
    signature: signature ?? this.signature,
    limitedHours: limitedHours ?? this.limitedHours,
    sellingHours: sellingHours != null ? sellingHours() : this.sellingHours,
    pickup: pickup ?? this.pickup,
    pickupPrice: pickupPrice != null ? pickupPrice() : this.pickupPrice,
    allergens: allergens ?? this.allergens,
    nutrition: nutrition ?? this.nutrition,
    servingSize: servingSize != null ? servingSize() : this.servingSize,
    caffeineMg: caffeineMg != null ? caffeineMg() : this.caffeineMg,
  );

  @override
  List<Object?> get props => [
    price,
    available,
    category,
    signature,
    limitedHours,
    sellingHours,
    pickup,
    pickupPrice,
    allergens,
    nutrition,
    servingSize,
    caffeineMg,
  ];
}

/// HungerStation catalog product — `POST /catalog`, then `PUT /catalog`
/// for availability and stock.
final class HsListing extends PlatformListing {
  const HsListing({
    required super.price,
    super.available,
    super.category,
    this.quantity,
    this.maxPerOrder,
    this.soldByWeight = false,
    this.baseWeight,
    this.averageWeightPerPiece,
    this.minimumStartingWeight,
  });

  @override
  String get platformId => 'hungerstation';

  /// Stock on hand; at or below the vendor's sales buffer the product goes
  /// inactive automatically.
  final int? quantity;

  /// `maximum_sales_quantity` per order.
  final int? maxPerOrder;

  final bool soldByWeight;

  /// Reference weight [price] applies to (e.g. 1 KG). Required when
  /// [soldByWeight].
  final HsWeight? baseWeight;
  final HsWeight? averageWeightPerPiece;

  /// Smallest orderable weight.
  final HsWeight? minimumStartingWeight;

  HsListing copyWith({
    double? price,
    bool? available,
    String? category,
    int? Function()? quantity,
    int? Function()? maxPerOrder,
    bool? soldByWeight,
    HsWeight? Function()? baseWeight,
    HsWeight? Function()? averageWeightPerPiece,
    HsWeight? Function()? minimumStartingWeight,
  }) => HsListing(
    price: price ?? this.price,
    available: available ?? this.available,
    category: category ?? this.category,
    quantity: quantity != null ? quantity() : this.quantity,
    maxPerOrder: maxPerOrder != null ? maxPerOrder() : this.maxPerOrder,
    soldByWeight: soldByWeight ?? this.soldByWeight,
    baseWeight: baseWeight != null ? baseWeight() : this.baseWeight,
    averageWeightPerPiece: averageWeightPerPiece != null
        ? averageWeightPerPiece()
        : this.averageWeightPerPiece,
    minimumStartingWeight: minimumStartingWeight != null
        ? minimumStartingWeight()
        : this.minimumStartingWeight,
  );

  @override
  List<Object?> get props => [
    price,
    available,
    category,
    quantity,
    maxPerOrder,
    soldByWeight,
    baseWeight,
    averageWeightPerPiece,
    minimumStartingWeight,
  ];
}
