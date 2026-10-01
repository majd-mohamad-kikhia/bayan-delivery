import 'merchants_strings.dart';

final class MerchantsStringsAr extends MerchantsStrings {
  const MerchantsStringsAr();

  // ── Keeta shops panel ──────────────────────────────────────────────────
  @override
  String get keetaShops => 'فروع كيتا';
  @override
  String get keetaShopsSubtitle => 'الفروع · ساعات العمل · حالة الطوارئ';
  @override
  String get noAuthorizedShops => 'لا توجد فروع مصرّح بها';
  @override
  String get branch => 'الفرع';
  @override
  String get branchStatus => 'حالة الفرع';
  @override
  String get emergencyClose => 'إغلاق طارئ';
  @override
  String get reopen => 'إعادة الفتح';
  @override
  String get businessHoursLocal => 'ساعات العمل (بالتوقيت المحلي)';
  @override
  String get loadingHours => 'جارٍ تحميل ساعات العمل…';
  @override
  String shopFallbackName(int id) => 'فرع $id';

  // ── Shop availability ──────────────────────────────────────────────────
  @override
  String get available => 'متاح';
  @override
  String get unavailable => 'غير متاح';

  // ── Emergency status dialog ────────────────────────────────────────────
  @override
  String get confirmStatus => 'تأكيد الحالة';
  @override
  String get emergencyCloseTitle => 'إغلاق طارئ؟';
  @override
  String get reopenBranchTitle => 'إعادة فتح الفرع؟';
  @override
  String emergencyCloseBody(String shopName) =>
      'سيتم إغلاق «$shopName» فورًا على كيتا. استخدم هذا الخيار للإغلاق غير المخطط له فقط، وليس لساعات العمل المجدولة.';
  @override
  String reopenBranchBody(String shopName) =>
      'سيتم إعادة «$shopName» إلى حالة «متاح» على كيتا.';
  @override
  String get closeNow => 'أغلق الآن';
  @override
  String get thisBranch => 'الفرع';

  // ── Business hours ─────────────────────────────────────────────────────
  @override
  String get noWeeklyHours => 'لم يتم إعداد ساعات العمل الأسبوعية';
  @override
  String get closedAllDay => 'مغلق';
  @override
  String get listSeparator => '، ';
  @override
  String get monday => 'الاثنين';
  @override
  String get tuesday => 'الثلاثاء';
  @override
  String get wednesday => 'الأربعاء';
  @override
  String get thursday => 'الخميس';
  @override
  String get friday => 'الجمعة';
  @override
  String get saturday => 'السبت';
  @override
  String get sunday => 'الأحد';

  // ── HungerStation outlet panel ─────────────────────────────────────────
  @override
  String get hsOutlet => 'فرع هنقرستيشن';
  @override
  String get hsOutletSubtitle => 'فتح / إغلاق حالة المتجر';
  @override
  String get updateStatus => 'تحديث الحالة';
  @override
  String get reopenOpen => 'إعادة الفتح';
  @override
  String get closeForToday => 'إغلاق لبقية اليوم';
  @override
  String get closeUntil => 'إغلاق حتى…';
  @override
  String get closedReasonTitle => 'سبب الإغلاق';
  @override
  String get closedReasonSubtitle =>
      'لماذا يُغلق الفرع؟ لن يتمكن العملاء من الطلب حتى تعيد فتحه.';
  @override
  String get vendorStatus => 'حالة المتجر';
  @override
  String vendorIdLabel(String id) => 'المتجر: $id';
  @override
  String chainIdLabel(String id) => 'السلسلة: $id';
  @override
  String closedReasonLabel(String reason) => 'السبب: $reason';
  @override
  String closedUntilLabel(String until) => 'حتى: $until';

  // ── HungerStation close-until picker ───────────────────────────────────
  @override
  String get closeUntilTitle => 'موعد إعادة الفتح';
  @override
  String get closeUntilSubtitle => 'اختر متى يعود الفرع لاستقبال الطلبات.';
  @override
  String get quickPicks => 'اختيارات سريعة';
  @override
  String get pickTime => 'الوقت';
  @override
  String inMinutes(int minutes) => 'بعد $minutes دقيقة';
  @override
  String inHours(int hours) => switch (hours) {
        1 => 'بعد ساعة',
        2 => 'بعد ساعتين',
        _ => 'بعد $hours ساعات',
      };
  @override
  String get tomorrowMorning => 'غدًا صباحًا';
  @override
  String get periodMorning => 'الصباح';
  @override
  String get periodAfternoon => 'الظهر';
  @override
  String get periodEvening => 'المساء';
  @override
  String get periodNight => 'آخر الليل';
  @override
  String reopensAt(String date, String time) => 'يعود للعمل $date · $time';
  @override
  String reopensIn(int days, int hours, int minutes) {
    final parts = [
      if (days > 0) '$days يوم',
      if (hours > 0) '$hours س',
      if (minutes > 0 || (days == 0 && hours == 0)) '$minutes د',
    ];
    return 'بعد ${parts.join(' ')}';
  }
  @override
  String get pickFutureTime => 'اختر وقتًا في المستقبل';
  @override
  String get confirmClosure => 'تأكيد الإغلاق';

  // ── HungerStation vendor statuses ──────────────────────────────────────
  @override
  String get statusOpen => 'مفتوح';
  @override
  String get statusClosedToday => 'مغلق اليوم';
  @override
  String get statusClosedUntil => 'مغلق مؤقتًا';
  @override
  String get statusClosed => 'مغلق';
  @override
  String get statusCheckin => 'تسجيل الحضور';

  // ── HungerStation closed reasons ───────────────────────────────────────
  @override
  String get reasonTooBusyNoDrivers => 'ضغط عالٍ — لا يوجد مناديب';
  @override
  String get reasonTooBusyKitchen => 'ضغط عالٍ — المطبخ';
  @override
  String get reasonMenuUpdates => 'تحديثات على القائمة';
  @override
  String get reasonTechnicalProblem => 'مشكلة تقنية';
  @override
  String get reasonClosed => 'مغلق';
  @override
  String get reasonOther => 'أخرى';
  @override
  String get reasonBadWeather => 'سوء الأحوال الجوية';
  @override
  String get reasonHoliday => 'عطلة / مناسبة خاصة';
}
