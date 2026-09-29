import 'package:flutter/widgets.dart';

import '../../../../core/localization/locale_context.dart';
import '../../../../core/platforms/hungerstation/hs_types.dart';
import '../../../../core/platforms/keeta/keeta_types.dart';
import '../../data/repositories/product_publish_repository.dart';
import 'products_strings_ar.dart';
import 'products_strings_en.dart';

/// Text of the products feature. Generic words (cancel, active, money,
/// platform names…) come from `context.commonStrings`.
abstract class ProductsStrings {
  const ProductsStrings();

  // ── Catalog ────────────────────────────────────────────────────────────
  String get productsTitle;
  String get catalogSubtitle;
  String get syncAlBayan;
  String get syncComingSoon;
  String get integrationBanner;
  String get searchHint;
  String get allStatuses;
  String itemCount(int n);
  String get noMatchingProducts;

  // ── Product fields ─────────────────────────────────────────────────────
  String get sku;
  String get product;
  String get category;
  String get unit;
  String get salePrice;
  String get costPrice;
  String get taxRate;
  String get tax;
  String get stock;
  String get status;
  String get barcode;

  // ── Product details ────────────────────────────────────────────────────
  String get productDetails;
  String get addToPlatforms;
  String get openInAlBayan;
  String get editInAlBayan;

  // ── Al-Bayan product summary ───────────────────────────────────────────
  String get alBayanProduct;
  String get alBayanProductSubtitle;
  String get ownershipNote;

  // ── Publish page ───────────────────────────────────────────────────────
  String get backToProducts;
  String get adding;

  /// e.g. "Bread: Added to Keeta · still processing on HungerStation".
  String publishSucceeded(
    String product,
    List<String> live,
    List<String> pending,
  );
  String get noPlatformSelected;
  String get publishFailedTitle;
  String get publishedTitle;
  String platformFailed(String platform, String reason);
  String platformsFailed(int n);

  /// [platform] is the display name; [detail] is the platform's own text
  /// or the offending value, when the outcome has one.
  String publishNotice(PublishNotice notice, String platform, String? detail);

  // ── Listing details ────────────────────────────────────────────────────
  String get listingDetails;
  String get listingDetailsSubtitle;
  String get nameEnRequired;
  String get nameAr;
  String get descriptionEn;
  String get descriptionEnHint;
  String get descriptionAr;
  String get barcodeGtin;
  String get barcodeHint;
  String get imageUrls;
  String get imageGuidelines;

  // ── Platforms panel ────────────────────────────────────────────────────
  String get publishToPlatforms;
  String get publishToPlatformsSubtitle;
  String get selectAll;
  String get clear;
  String get notSelected;
  String get readyToPublish;
  String get publishing;
  String get published;
  String get processing;
  String get failed;
  String platformsSelected(int selected, int total);

  // ── Keeta listing ──────────────────────────────────────────────────────
  String get available;
  String get keetaAvailableHint;
  String get signatureItem;
  String get signatureItemHint;
  String get deliveryPriceRequired;
  String get menuCategoryRequired;
  String get menuCategoryHint;
  String get sellingTime;
  String get sellingTimeHint;
  String get allDay;
  String get dailyHours;
  String get hoursFrom;
  String get hoursTo;
  String get pickup;
  String get pickupHint;
  String get allowPickup;
  String get pickupPriceRequired;
  String get allergens;
  String get allergensHint;
  String allergen(KeetaAllergen allergen);
  String nutritionFacts(int filled);
  String get nutritionHint;

  /// Nutrient name with its unit, e.g. "Calories (kcal)".
  String nutrient(KeetaNutrient nutrient);
  String get servingSize;
  String get caffeine;

  // ── HungerStation listing ──────────────────────────────────────────────
  String get hsAvailableHint;
  String get priceRequired;
  String get hsCategoryHint;
  String get stockHint;
  String get quantity;
  String get maxPerOrder;
  String get noLimit;
  String get soldByWeight;
  String get soldByWeightHint;
  String get pricedByWeight;
  String get baseWeightRequired;
  String get averageWeightPerPiece;
  String get minimumOrderWeight;
  String weightUnit(HsWeightUnit unit);
}

extension ProductsStringsContext on BuildContext {
  ProductsStrings get productsStrings =>
      isArabic ? const ProductsStringsAr() : const ProductsStringsEn();
}
