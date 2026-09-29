import '../../../../core/localization/arabic_plural.dart';
import '../../../../core/platforms/hungerstation/hs_types.dart';
import '../../../../core/platforms/keeta/keeta_types.dart';
import '../../data/repositories/product_publish_repository.dart';
import 'products_strings.dart';

final class ProductsStringsAr extends ProductsStrings {
  const ProductsStringsAr();

  // ── Catalog ────────────────────────────────────────────────────────────
  @override
  String get productsTitle => 'المنتجات';
  @override
  String get catalogSubtitle => 'كتالوج البيان';
  @override
  String get syncAlBayan => 'مزامنة البيان';
  @override
  String get syncComingSoon => 'ستتوفر المزامنة مع البيان قريبًا.';
  @override
  String get integrationBanner =>
      'كتالوج البيان — اختر منتجًا ثم أضفه إلى كيتا أو هنقرستيشن.';
  @override
  String get searchHint =>
      'ابحث في منتجات البيان بالاسم أو رمز المنتج أو الباركود…';
  @override
  String get allStatuses => 'كل الحالات';
  @override
  String itemCount(int n) => arabicPlural(
    n,
    zero: 'لا توجد منتجات',
    one: 'منتج واحد',
    two: 'منتجان',
    few: '$n منتجات',
    many: '$n منتجًا',
    other: '$n منتج',
  );
  @override
  String get noMatchingProducts => 'لا توجد منتجات مطابقة لعوامل التصفية';

  // ── Product fields ─────────────────────────────────────────────────────
  @override
  String get sku => 'رمز المنتج (SKU)';
  @override
  String get product => 'المنتج';
  @override
  String get category => 'الفئة';
  @override
  String get unit => 'الوحدة';
  @override
  String get salePrice => 'سعر البيع';
  @override
  String get costPrice => 'سعر التكلفة';
  @override
  String get taxRate => 'نسبة الضريبة';
  @override
  String get tax => 'الضريبة';
  @override
  String get stock => 'المخزون';
  @override
  String get status => 'الحالة';
  @override
  String get barcode => 'الباركود';

  // ── Product details ────────────────────────────────────────────────────
  @override
  String get productDetails => 'تفاصيل المنتج';
  @override
  String get addToPlatforms => 'إضافة إلى المنصات';
  @override
  String get openInAlBayan => 'فتح في البيان';
  @override
  String get editInAlBayan => 'تُعدَّل المنتجات من برنامج البيان المحاسبي.';

  // ── Al-Bayan product summary ───────────────────────────────────────────
  @override
  String get alBayanProduct => 'منتج البيان';
  @override
  String get alBayanProductSubtitle =>
      'من كتالوجك المحاسبي — غير قابل للتعديل هنا';
  @override
  String get ownershipNote =>
      'تبقى الأسعار والمخزون تحت إدارة البيان، ولا تحصل المنصات إلا على عرض المنتج في قائمتها.';

  // ── Publish page ───────────────────────────────────────────────────────
  @override
  String get backToProducts => 'العودة إلى منتجات البيان';
  @override
  String get adding => 'جارٍ الإضافة…';
  @override
  String publishSucceeded(
    String product,
    List<String> live,
    List<String> pending,
  ) {
    final parts = [
      if (live.isNotEmpty) 'تمت الإضافة إلى ${live.join('، ')}',
      if (pending.isNotEmpty) 'قيد المعالجة لدى ${pending.join('، ')}',
    ];
    return '$product: ${parts.join(' · ')}';
  }

  @override
  String get noPlatformSelected => 'اختر منصة واحدة على الأقل';
  @override
  String get publishFailedTitle => 'تعذّر نشر المنتج';
  @override
  String get publishedTitle => 'تم نشر المنتج';
  @override
  String platformFailed(String platform, String reason) => '$platform: $reason';
  @override
  String platformsFailed(int n) => arabicPlural(
    n,
    zero: 'لم يفشل النشر على أي منصة.',
    one: 'فشل النشر على منصة واحدة — راجع التفاصيل ثم أعد المحاولة.',
    two: 'فشل النشر على منصتين — راجع التفاصيل ثم أعد المحاولة.',
    few: 'فشل النشر على $n منصات — راجع التفاصيل ثم أعد المحاولة.',
    many: 'فشل النشر على $n منصة — راجع التفاصيل ثم أعد المحاولة.',
    other: 'فشل النشر على $n منصة — راجع التفاصيل ثم أعد المحاولة.',
  );

  @override
  String publishNotice(
    PublishNotice notice,
    String platform,
    String? detail,
  ) => switch (notice) {
    PublishNotice.added => 'تمت الإضافة إلى $platform',
    PublishNotice.addedWithoutImages =>
      'تمت الإضافة إلى $platform · لم تُرفق الصور (لم يُرجَع رقم المنتج)',
    PublishNotice.addedImagesRejected =>
      'تمت الإضافة إلى $platform · الصور: ${detail ?? 'مرفوضة'}',
    PublishNotice.addedWithoutStock =>
      'تمت الإضافة إلى $platform · اضبط HS_VENDOR_ID لتطبيق التوفر والمخزون',
    PublishNotice.processing => 'لا يزال المنتج قيد المعالجة لدى $platform',
    PublishNotice.error => detail ?? 'تعذّر النشر على $platform.',
    PublishNotice.rejected =>
      detail == null
          ? 'رفضت $platform المنتج.'
          : 'رفضت $platform المنتج — $detail',
    PublishNotice.unknownCategory => 'لا توجد في $platform فئة باسم "$detail".',
    PublishNotice.noJobId => 'لم تُرجع $platform رقم مهمة المعالجة.',
    PublishNotice.categoryNotCreated =>
      'لم تُرجع $platform الفئة الجديدة "$detail"',
    PublishNotice.noShop => 'لا يوجد متجر على $platform مصرّح له لهذا الحساب',
    PublishNotice.severalShops =>
      'يوجد أكثر من متجر على $platform — اختر متجرًا من صفحة التجار أولًا',
    PublishNotice.nameRequired => 'أدخل اسم المنتج',
    PublishNotice.priceRequired => 'يجب أن يكون السعر أكبر من 0',
    PublishNotice.pickupPriceRequired => 'يجب أن يكون سعر الاستلام أكبر من 0',
    PublishNotice.categoryRequired => 'تتطلب $platform تحديد فئة في القائمة',
    PublishNotice.sellingHoursRequired =>
      'أدخل ساعات البيع بالصيغة HH:mm – HH:mm',
    PublishNotice.servingSizeOutOfRange => 'يجب أن يكون عدد الأشخاص من 1 إلى 9',
    PublishNotice.caffeineNegative => 'لا يمكن أن تكون كمية الكافيين سالبة',
    PublishNotice.nutritionNegative => 'لا يمكن أن تكون القيم الغذائية سالبة',
    PublishNotice.invalidImageUrl =>
      'يجب أن تكون روابط الصور بصيغة http(s) ودون منفذ مخصص: $detail',
    PublishNotice.barcodeRequired =>
      'تتطلب $platform باركودًا ما لم يُبع المنتج بالوزن',
    PublishNotice.baseWeightRequired =>
      'أدخل الوزن الأساسي الذي ينطبق عليه السعر',
    PublishNotice.stockNegative => 'لا يمكن أن يكون المخزون سالبًا',
    PublishNotice.maxPerOrderTooLow => 'يجب ألا يقل الحد الأقصى لكل طلب عن 1',
  };

  // ── Listing details ────────────────────────────────────────────────────
  @override
  String get listingDetails => 'تفاصيل العرض';
  @override
  String get listingDetailsSubtitle => 'ما يراه العملاء على جميع المنصات';
  @override
  String get nameEnRequired => 'الاسم (بالإنجليزية) *';
  @override
  String get nameAr => 'الاسم (بالعربية)';
  @override
  String get descriptionEn => 'الوصف (بالإنجليزية)';
  @override
  String get descriptionEnHint => 'الحجم، المكونات، محتويات العبوة…';
  @override
  String get descriptionAr => 'الوصف (بالعربية)';
  @override
  String get barcodeGtin => 'الباركود (GTIN)';
  @override
  String get barcodeHint => 'مطلوب في هنقرستيشن ما لم يُبع المنتج بالوزن';
  @override
  String get imageUrls => 'روابط الصور (رابط في كل سطر)';
  @override
  String get imageGuidelines =>
      'بصيغة JPG أو PNG ومتاحة للعموم. كيتا: 600×450 على الأقل وبحجم أقصاه 5 ميجابايت. '
      'هنقرستيشن: 400×400 على الأقل، بخلفية بيضاء والمنتج في المنتصف.';

  // ── Platforms panel ────────────────────────────────────────────────────
  @override
  String get publishToPlatforms => 'النشر على المنصات';
  @override
  String get publishToPlatformsSubtitle =>
      'اختر المنصات التي سيُعرض عليها هذا المنتج';
  @override
  String get selectAll => 'تحديد الكل';
  @override
  String get clear => 'مسح';
  @override
  String get notSelected => 'غير محددة';
  @override
  String get readyToPublish => 'جاهزة للنشر';
  @override
  String get publishing => 'جارٍ النشر…';
  @override
  String get published => 'تم النشر';
  @override
  String get processing => 'قيد المعالجة…';
  @override
  String get failed => 'فشل النشر';
  @override
  String platformsSelected(int selected, int total) =>
      'المحدد: $selected من $total';

  // ── Keeta listing ──────────────────────────────────────────────────────
  @override
  String get available => 'متوفر';
  @override
  String get keetaAvailableHint => 'عند الإيقاف يظهر المنتج كغير متوفر';
  @override
  String get signatureItem => 'منتج مميز';
  @override
  String get signatureItemHint => 'بحد أقصى 15 منتجًا لكل متجر';
  @override
  String get deliveryPriceRequired => 'سعر التوصيل (ر.س) *';
  @override
  String get menuCategoryRequired => 'فئة القائمة *';
  @override
  String get menuCategoryHint => 'فئة حالية أو جديدة';
  @override
  String get sellingTime => 'وقت البيع';
  @override
  String get sellingTimeHint => 'أوقات توفر المنتج للطلب';
  @override
  String get allDay => 'طوال اليوم';
  @override
  String get dailyHours => 'ساعات يومية';
  @override
  String get hoursFrom => 'من (HH:mm)';
  @override
  String get hoursTo => 'إلى (HH:mm)';
  @override
  String get pickup => 'الاستلام';
  @override
  String get pickupHint => 'التوصيل مفعّل دائمًا';
  @override
  String get allowPickup => 'السماح بالاستلام من المتجر';
  @override
  String get pickupPriceRequired => 'سعر الاستلام (ر.س) *';
  @override
  String get allergens => 'مسببات الحساسية';
  @override
  String get allergensHint =>
      'مطلوبة في المملكة العربية السعودية (هيئة الغذاء والدواء) — اتركها فارغة إن لم توجد';
  @override
  String allergen(KeetaAllergen allergen) => switch (allergen) {
    KeetaAllergen.celery => 'الكرفس',
    KeetaAllergen.sulfite => 'الكبريتيت',
    KeetaAllergen.milk => 'الحليب',
    KeetaAllergen.nuts => 'المكسرات',
    KeetaAllergen.peanuts => 'الفول السوداني',
    KeetaAllergen.fish => 'الأسماك',
    KeetaAllergen.grains => 'الحبوب',
    KeetaAllergen.soybeans => 'فول الصويا',
    KeetaAllergen.lupins => 'الترمس',
    KeetaAllergen.molluscs => 'الرخويات',
    KeetaAllergen.sesameSeeds => 'السمسم',
    KeetaAllergen.mustard => 'الخردل',
    KeetaAllergen.eggs => 'البيض',
    KeetaAllergen.crustaceans => 'القشريات',
  };
  @override
  String nutritionFacts(int filled) =>
      filled == 0 ? 'القيم الغذائية' : 'القيم الغذائية ($filled)';
  @override
  String get nutritionHint =>
      'تُعرض السعرات الحرارية في القوائم بالمملكة العربية السعودية';
  @override
  String nutrient(KeetaNutrient nutrient) => switch (nutrient) {
    KeetaNutrient.calories => 'السعرات الحرارية (سعرة)',
    KeetaNutrient.protein => 'البروتين (غ)',
    KeetaNutrient.totalFat => 'إجمالي الدهون (غ)',
    KeetaNutrient.saturatedFat => 'الدهون المشبعة (غ)',
    KeetaNutrient.transFat => 'الدهون المتحولة (غ)',
    KeetaNutrient.cholesterol => 'الكوليسترول (ملغ)',
    KeetaNutrient.carbohydrates => 'الكربوهيدرات (غ)',
    KeetaNutrient.fiber => 'الألياف (غ)',
    KeetaNutrient.totalSugar => 'إجمالي السكريات (غ)',
    KeetaNutrient.addedSugar => 'السكر المضاف (غ)',
    KeetaNutrient.salt => 'الملح (غ)',
    KeetaNutrient.sodium => 'الصوديوم (ملغ)',
  };
  @override
  String get servingSize => 'يكفي (1–9 أشخاص)';
  @override
  String get caffeine => 'الكافيين (ملغ)';

  // ── HungerStation listing ──────────────────────────────────────────────
  @override
  String get hsAvailableHint => 'يُطبَّق مباشرةً بعد إضافة المنتج';
  @override
  String get priceRequired => 'السعر (ر.س) *';
  @override
  String get hsCategoryHint => 'من قائمة فئات هنقرستيشن';
  @override
  String get stockHint =>
      'يتوقف المنتج تلقائيًا عندما تصل الكمية إلى المخزون الاحتياطي للمبيعات أو أقل';
  @override
  String get quantity => 'الكمية';
  @override
  String get maxPerOrder => 'الحد الأقصى لكل طلب';
  @override
  String get noLimit => 'بلا حد';
  @override
  String get soldByWeight => 'البيع بالوزن';
  @override
  String get soldByWeightHint => 'لا حاجة إلى باركود عند التفعيل';
  @override
  String get pricedByWeight => 'التسعير حسب الوزن';
  @override
  String get baseWeightRequired => 'الوزن الأساسي للسعر *';
  @override
  String get averageWeightPerPiece => 'متوسط وزن القطعة';
  @override
  String get minimumOrderWeight => 'الحد الأدنى لوزن الطلب';
  @override
  String weightUnit(HsWeightUnit unit) => switch (unit) {
    HsWeightUnit.kg => 'كغ',
    HsWeightUnit.g => 'غ',
  };
}
