import '../../../../core/platforms/hungerstation/hs_types.dart';
import '../../../../core/platforms/keeta/keeta_types.dart';
import '../../data/repositories/product_publish_repository.dart';
import 'products_strings.dart';

final class ProductsStringsEn extends ProductsStrings {
  const ProductsStringsEn();

  // ── Catalog ────────────────────────────────────────────────────────────
  @override
  String get productsTitle => 'Products';
  @override
  String get catalogSubtitle => 'Al-Bayan catalog';
  @override
  String get syncAlBayan => 'Sync Al-Bayan';
  @override
  String get syncComingSoon => 'Sync with Al-Bayan will be available soon.';
  @override
  String get integrationBanner =>
      'Al-Bayan catalog — select a product, then add it to Keeta or HungerStation.';
  @override
  String get searchHint => 'Search Al-Bayan products by name, SKU, or barcode…';
  @override
  String get allStatuses => 'All status';
  @override
  String itemCount(int n) => n == 1 ? '1 item' : '$n items';
  @override
  String get noMatchingProducts => 'No products match your filters';

  // ── Product fields ─────────────────────────────────────────────────────
  @override
  String get sku => 'SKU';
  @override
  String get product => 'Product';
  @override
  String get category => 'Category';
  @override
  String get unit => 'Unit';
  @override
  String get salePrice => 'Sale price';
  @override
  String get costPrice => 'Cost price';
  @override
  String get taxRate => 'Tax rate';
  @override
  String get tax => 'Tax';
  @override
  String get stock => 'Stock';
  @override
  String get status => 'Status';
  @override
  String get barcode => 'Barcode';

  // ── Product details ────────────────────────────────────────────────────
  @override
  String get productDetails => 'Product details';
  @override
  String get addToPlatforms => 'Add to platforms';
  @override
  String get openInAlBayan => 'Open in Al-Bayan';
  @override
  String get editInAlBayan => 'Edit products in Al-Bayan Accounting.';

  // ── Al-Bayan product summary ───────────────────────────────────────────
  @override
  String get alBayanProduct => 'Al-Bayan product';
  @override
  String get alBayanProductSubtitle =>
      'From your accounting catalog — not editable here';
  @override
  String get ownershipNote =>
      'Prices & stock stay owned by Al-Bayan. Platforms only get a menu listing.';

  // ── Publish page ───────────────────────────────────────────────────────
  @override
  String get backToProducts => 'Back to Al-Bayan products';
  @override
  String get adding => 'Adding…';
  @override
  String publishSucceeded(
    String product,
    List<String> live,
    List<String> pending,
  ) {
    final parts = [
      if (live.isNotEmpty) 'Added to ${live.join(', ')}',
      if (pending.isNotEmpty) 'still processing on ${pending.join(', ')}',
    ];
    return '$product: ${parts.join(' · ')}';
  }

  @override
  String get noPlatformSelected => 'Select at least one platform';
  @override
  String get publishFailedTitle => "Couldn't publish the product";
  @override
  String get publishedTitle => 'Product published';
  @override
  String platformFailed(String platform, String reason) => '$platform: $reason';
  @override
  String platformsFailed(int n) =>
      '$n platforms failed — see details, then retry.';

  @override
  String publishNotice(
    PublishNotice notice,
    String platform,
    String? detail,
  ) => switch (notice) {
    PublishNotice.added => 'Added to $platform',
    PublishNotice.addedWithoutImages =>
      'Added to $platform · images not attached (no product id returned)',
    PublishNotice.addedImagesRejected =>
      'Added to $platform · images: ${detail ?? 'rejected'}',
    PublishNotice.addedWithoutStock =>
      'Added to $platform · set HS_VENDOR_ID to apply availability and stock',
    PublishNotice.processing => '$platform is still processing it',
    PublishNotice.error => detail ?? 'Could not publish to $platform.',
    PublishNotice.rejected =>
      detail == null
          ? '$platform rejected the product.'
          : '$platform rejected it — $detail',
    PublishNotice.unknownCategory =>
      '$platform has no category named "$detail".',
    PublishNotice.noJobId => '$platform did not return a job id.',
    PublishNotice.categoryNotCreated =>
      '$platform did not return the new category "$detail"',
    PublishNotice.noShop => 'No $platform shop is authorized for this account',
    PublishNotice.severalShops =>
      'Several $platform shops — choose one in Merchants first',
    PublishNotice.nameRequired => 'Enter a product name',
    PublishNotice.priceRequired => 'Price must be greater than 0',
    PublishNotice.pickupPriceRequired => 'Pickup price must be greater than 0',
    PublishNotice.categoryRequired => '$platform needs a menu category',
    PublishNotice.sellingHoursRequired =>
      'Enter the selling hours as HH:mm – HH:mm',
    PublishNotice.servingSizeOutOfRange => 'Serving size must be 1 to 9 people',
    PublishNotice.caffeineNegative => 'Caffeine cannot be negative',
    PublishNotice.nutritionNegative => 'Nutrition values cannot be negative',
    PublishNotice.invalidImageUrl =>
      'Image URLs must be http(s) links without a custom port: $detail',
    PublishNotice.barcodeRequired =>
      '$platform needs a barcode unless the product is sold by weight',
    PublishNotice.baseWeightRequired =>
      'Enter the base weight the price applies to',
    PublishNotice.stockNegative => 'Stock cannot be negative',
    PublishNotice.maxPerOrderTooLow => 'Max per order must be at least 1',
  };

  // ── Listing details ────────────────────────────────────────────────────
  @override
  String get listingDetails => 'Listing details';
  @override
  String get listingDetailsSubtitle => 'What customers see on every platform';
  @override
  String get nameEnRequired => 'Name (English) *';
  @override
  String get nameAr => 'Name (Arabic)';
  @override
  String get descriptionEn => 'Description (English)';
  @override
  String get descriptionEnHint => 'Size, ingredients, what’s in the pack…';
  @override
  String get descriptionAr => 'Description (Arabic)';
  @override
  String get barcodeGtin => 'Barcode (GTIN)';
  @override
  String get barcodeHint => 'Required on HungerStation unless sold by weight';
  @override
  String get imageUrls => 'Image URLs (one per line)';
  @override
  String get imageGuidelines =>
      'JPG or PNG, publicly reachable. Keeta: at least 600×450, up to 5 MB. '
      'HungerStation: at least 400×400, white background, product centered.';

  // ── Platforms panel ────────────────────────────────────────────────────
  @override
  String get publishToPlatforms => 'Publish to platforms';
  @override
  String get publishToPlatformsSubtitle =>
      'Choose where this product goes live';
  @override
  String get selectAll => 'Select all';
  @override
  String get clear => 'Clear';
  @override
  String get notSelected => 'Not selected';
  @override
  String get readyToPublish => 'Ready to publish';
  @override
  String get publishing => 'Publishing…';
  @override
  String get published => 'Published';
  @override
  String get processing => 'Processing…';
  @override
  String get failed => 'Failed';
  @override
  String platformsSelected(int selected, int total) =>
      '$selected of $total platforms';

  // ── Keeta listing ──────────────────────────────────────────────────────
  @override
  String get available => 'Available';
  @override
  String get keetaAvailableHint => 'status — off lists it as unavailable';
  @override
  String get signatureItem => 'Signature item';
  @override
  String get signatureItemHint => 'isSpecialty — max 15 per store';
  @override
  String get deliveryPriceRequired => 'Delivery price (SAR) *';
  @override
  String get menuCategoryRequired => 'Menu category *';
  @override
  String get menuCategoryHint => 'Existing or new category';
  @override
  String get sellingTime => 'Selling time';
  @override
  String get sellingTimeHint => 'availableTime';
  @override
  String get allDay => 'All day';
  @override
  String get dailyHours => 'Daily hours';
  @override
  String get hoursFrom => 'From (HH:mm)';
  @override
  String get hoursTo => 'To (HH:mm)';
  @override
  String get pickup => 'Pickup';
  @override
  String get pickupHint => 'userGetModeList — delivery is always on';
  @override
  String get allowPickup => 'Allow pickup';
  @override
  String get pickupPriceRequired => 'Pickup price (SAR) *';
  @override
  String get allergens => 'Allergens';
  @override
  String get allergensHint =>
      'Required in Saudi Arabia (SFDA) — leave empty if none';
  @override
  String allergen(KeetaAllergen allergen) => allergen.wire;
  @override
  String nutritionFacts(int filled) =>
      filled == 0 ? 'Nutrition facts' : 'Nutrition facts ($filled)';
  @override
  String get nutritionHint => 'Calories are shown on menus in Saudi Arabia';
  @override
  String nutrient(KeetaNutrient nutrient) =>
      '${nutrient.label} (${nutrient.unit})';
  @override
  String get servingSize => 'Serves (1–9 people)';
  @override
  String get caffeine => 'Caffeine (mg)';

  // ── HungerStation listing ──────────────────────────────────────────────
  @override
  String get hsAvailableHint =>
      'active — applied right after the product is added';
  @override
  String get priceRequired => 'Price (SAR) *';
  @override
  String get hsCategoryHint => 'From HungerStation’s list';
  @override
  String get stockHint =>
      'quantity at or below the sales buffer turns the product off';
  @override
  String get quantity => 'Quantity';
  @override
  String get maxPerOrder => 'Max per order';
  @override
  String get noLimit => 'No limit';
  @override
  String get soldByWeight => 'Sold by weight';
  @override
  String get soldByWeightHint =>
      'is_sold_by_weight — no barcode needed when on';
  @override
  String get pricedByWeight => 'Priced by weight';
  @override
  String get baseWeightRequired => 'Base weight the price is for *';
  @override
  String get averageWeightPerPiece => 'Average weight per piece';
  @override
  String get minimumOrderWeight => 'Minimum order weight';
  @override
  String weightUnit(HsWeightUnit unit) => unit.wire;
}
