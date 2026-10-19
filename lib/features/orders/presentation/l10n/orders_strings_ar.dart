import '../../../../core/localization/arabic_plural.dart';
import 'orders_strings.dart';

final class OrdersStringsAr extends OrdersStrings {
  const OrdersStringsAr();

  @override
  String get liveKanban => 'لوحة الطلبات المباشرة';
  @override
  String get orderArchive => 'أرشيف الطلبات';
  @override
  String get products => 'المنتجات';
  @override
  String get bayanErp => 'نظام البيان';
  @override
  String get hsOutlet => 'فرع هنقرستيشن';
  @override
  String get keetaShops => 'متاجر كيتا';

  @override
  String get liveBoard => 'اللوحة المباشرة';
  @override
  String get archive => 'الأرشيف';
  @override
  String get refresh => 'تحديث';
  @override
  String updatedAgo(String ago) => 'آخر تحديث $ago';

  @override
  String get loadingOrders => 'جارٍ تحميل الطلبات…';
  @override
  String get noOrders => 'لا توجد طلبات';
  @override
  String get allPlatforms => 'الكل';
  @override
  String get sidebarCollapse => 'طي القائمة';
  @override
  String get sidebarExpand => 'توسيع القائمة';
  @override
  String get columnPreparing => 'قيد التحضير';
  @override
  String get columnEndProcess => 'إنهاء الطلب';
  @override
  String get columnAttention => 'تحتاج إجراء';
  @override
  String get newOrderTitle => 'طلب جديد!';
  @override
  String newOrdersCount(int n) => '$n طلبات جديدة!';
  @override
  String get newOrderDismiss => 'حسناً، تم';
  @override
  String get noArchivedOrders => 'لا توجد طلبات مؤرشفة بعد';
  @override
  String get actionFailed => 'تعذّر تحديث الطلب';

  @override
  String itemCount(int n) => arabicPlural(
    n,
    zero: 'لا أصناف',
    one: 'صنف واحد',
    two: 'صنفان',
    few: '$n أصناف',
    many: '$n صنفًا',
    other: '$n صنف',
  );
  @override
  String reason(String reason) => 'السبب: $reason';

  @override
  String get orderDetail => 'تفاصيل الطلب';
  @override
  String createdAgo(String ago) => 'أُنشئ $ago';
  @override
  String get customer => 'العميل';
  @override
  String get name => 'الاسم';
  @override
  String get phone => 'الجوال';
  @override
  String get items => 'الأصناف';
  @override
  String get unknownItem => 'صنف غير معروف';

  @override
  String get dateFilterTitle => 'عرض طلبات';

  @override
  String get dateToday => 'اليوم';

  @override
  String get dateYesterday => 'أمس';

  @override
  String get dateLast7Days => 'آخر 7 أيام';

  @override
  String get dateThisMonth => 'هذا الشهر';

  @override
  String get dateAll => 'كل الأوقات';

  @override
  String get dateCustom => 'فترة مخصصة';

  @override
  String get dateCustomHelp => 'اختر أول يوم وآخر يوم';

  @override
  String get addOns => 'الإضافات';

  @override
  String get itemSubtotal => 'الصنف';
  @override
  String eachPrice(String price) => '$price للوحدة';
  @override
  String get payment => 'الدفع';
  @override
  String get total => 'الإجمالي';
  @override
  String get subtotal => 'المجموع الفرعي';
  @override
  String get vat => 'ضريبة القيمة المضافة';
  @override
  String get discount => 'الخصم';
  @override
  String get deliveryFee => 'رسوم التوصيل';
  @override
  String get serviceFee => 'رسوم الخدمة';
  @override
  String get cancellation => 'الإلغاء';

  @override
  String get vendorDelivery => 'توصيل بواسطة المتجر';
  @override
  String get logisticsDelivery => 'توصيل عبر المنصة';

  @override
  String get cancelOrderTitle => 'إلغاء الطلب؟';
  @override
  String get cancelOrder => 'إلغاء الطلب';
  @override
  String get rejectRefundTitle => 'رفض الاسترداد؟';
  @override
  String get rejectRefund => 'رفض الاسترداد';
  @override
  String orderNumber(String id) => 'رقم الطلب: $id';
  @override
  String get cancelReasonPrompt =>
      'يُرجى ذكر السبب. لا يمكن التراجع عن هذا الإجراء.';
  @override
  String get cancelReasonHint => 'مثال: نفاد المخزون، طلب العميل…';
  @override
  String get keepOrder => 'الإبقاء على الطلب';

  @override
  String get dongleDialogTitle => 'جهاز ربط المطعم';
  @override
  String get dongleNumber => 'رقم جهاز الربط';

  @override
  String get actionAccept => 'قبول';
  @override
  String get actionConfirm => 'تأكيد';
  @override
  String get actionReady => 'جاهز';
  @override
  String get actionHandoff => 'تسليم';
  @override
  String get actionDispatch => 'إرسال';
  @override
  String get actionCancel => 'إلغاء';
  @override
  String get actionAgreeRefund => 'قبول الاسترداد';
  @override
  String get actionRejectRefund => 'رفض الاسترداد';

  @override
  String get menus => 'القوائم';

  @override
  String get reports => 'التقارير';

  @override
  String get actionSelfDispatch => 'توصيلنا';

  @override
  String get actionSelfDeliver => 'تم التسليم';

  @override
  String get actionCourier => 'السائق';

  @override
  String get actionPartialRefund => 'استرداد جزئي';

  @override
  String get selfDeliveryBadge => 'توصيلنا';

  @override
  String get courierDialogTitle => 'بيانات السائق';

  @override
  String get courierDispatchSubtitle => 'من سيوصّل هذا الطلب؟';

  @override
  String get courierDeliverSubtitle => 'أكّد وصول الطلب للزبون';

  @override
  String get courierUpdateSubtitle => 'حدّث السائق الظاهر للزبون';

  @override
  String get courierName => 'اسم السائق';

  @override
  String get courierPhone => 'الهاتف';

  @override
  String get courierPlate => 'رقم اللوحة';

  @override
  String get courierVehicle => 'المركبة';

  @override
  String get vehicleWalking => 'مشياً';

  @override
  String get vehicleBicycle => 'دراجة';

  @override
  String get vehicleMotorcycle => 'دراجة نارية';

  @override
  String get vehicleCar => 'سيارة';

  @override
  String get courierConfirmDispatch => 'خرج للتوصيل';

  @override
  String get courierConfirmDeliver => 'تم التسليم';

  @override
  String get courierConfirmUpdate => 'حفظ السائق';

  @override
  String get courierNeedsOne => 'املأ حقلاً واحداً على الأقل';

  @override
  String get refundTitle => 'استرداد جزئي';

  @override
  String get refundSubtitle => 'أرجع ثمن الأصناف التي فيها مشكلة فقط';

  @override
  String get refundLoading => 'جارٍ فحص ما يمكن إرجاعه…';

  @override
  String get refundNothing => 'لا يوجد ما يمكن إرجاعه في هذا الطلب';

  @override
  String get refundAlready => 'تم إرجاعه';

  @override
  String get refundReason => 'السبب';

  @override
  String get refundReasonOther => 'سبب آخر';

  @override
  String get refundReasonSlow => 'بطء التحضير';

  @override
  String get refundReasonIngredients => 'نقص المكونات';

  @override
  String get refundReasonMissing => 'نقص أو عدم اكتمال التوصيل';

  @override
  String get refundReasonWrong => 'صنف خاطئ';

  @override
  String get refundDescribe => 'اكتب السبب';

  @override
  String get refundTotal => 'إجمالي الاسترداد';

  @override
  String get refundApply => 'إرجاع المبلغ';

  @override
  String get statusNew => 'جديد';
  @override
  String get statusCreated => 'تم الإنشاء';
  @override
  String get statusConfirmed => 'مؤكد';
  @override
  String get statusAccepted => 'مقبول';
  @override
  String get statusReadyForPickup => 'جاهز للاستلام';
  @override
  String get statusPickedUp => 'تم الاستلام';
  @override
  String get statusDispatched => 'قيد التوصيل';
  @override
  String get statusDelivered => 'تم التوصيل';
  @override
  String get statusCompleted => 'مكتمل';
  @override
  String get statusCancelled => 'ملغي';
  @override
  String get statusRefundRequest => 'طلب استرداد';
  @override
  String get statusCancelRequest => 'طلب إلغاء';
}
