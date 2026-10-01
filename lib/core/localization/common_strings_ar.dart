import '../errors/app_error_kind.dart';
import 'arabic_plural.dart';
import 'common_strings.dart';

final class CommonStringsAr extends CommonStrings {
  const CommonStringsAr();

  @override
  String get appName => 'البيان — مركز التوصيل';
  @override
  String get brandName => 'البيان';
  @override
  String get brandTagline => 'مركز التوصيل';

  @override
  String get retry => 'إعادة المحاولة';
  @override
  String get cancel => 'إلغاء';
  @override
  String get close => 'إغلاق';
  @override
  String get save => 'حفظ';
  @override
  String get confirm => 'تأكيد';
  @override
  String get back => 'رجوع';
  @override
  String get edit => 'تعديل';
  @override
  String get copy => 'نسخ';
  @override
  String copied(String label) => 'تم نسخ $label';

  @override
  String get loading => 'جارٍ التحميل…';
  @override
  String get somethingWentWrong => 'حدث خطأ ما.';
  @override
  String get active => 'نشط';
  @override
  String get inactive => 'غير نشط';
  @override
  String get all => 'الكل';

  @override
  String errorTitle(AppErrorKind kind) => switch (kind) {
        AppErrorKind.offline => 'تعذّر الاتصال بالخادم',
        AppErrorKind.timeout => 'الخادم يستغرق وقتًا طويلًا',
        AppErrorKind.unauthorized => 'تم رفض الوصول',
        AppErrorKind.notConfigured => 'يلزم إكمال الإعداد',
        AppErrorKind.rateLimited => 'طلبات كثيرة جدًا',
        AppErrorKind.server => 'خطأ في الخادم',
        AppErrorKind.rejected => 'تم رفض الطلب',
        AppErrorKind.unknown => 'حدث خطأ ما',
      };
  @override
  String errorAdvice(AppErrorKind kind) => switch (kind) {
        AppErrorKind.offline =>
          'تحقّق من اتصال الإنترنت ومن تشغيل الخادم، ثم أعد المحاولة.',
        AppErrorKind.timeout =>
          'الاتصال بطيء أو الخادم مشغول. يرجى المحاولة بعد قليل.',
        AppErrorKind.unauthorized =>
          'تم رفض بيانات الدخول. تحقّق من إعدادات الحساب.',
        AppErrorKind.notConfigured =>
          'بعض بيانات الدخول أو الإعدادات غير مكتملة لهذه الخدمة.',
        AppErrorKind.rateLimited =>
          'يرجى الانتظار بضع ثوانٍ قبل المحاولة مرة أخرى.',
        AppErrorKind.server =>
          'واجه الخادم مشكلة. يرجى المحاولة بعد قليل.',
        AppErrorKind.rejected => 'تعذّر على الخادم تنفيذ هذا الطلب.',
        AppErrorKind.unknown =>
          'حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى.',
      };
  @override
  String get showDetails => 'عرض التفاصيل';
  @override
  String get hideDetails => 'إخفاء التفاصيل';
  @override
  String get copyDetails => 'نسخ التفاصيل';
  @override
  String get detailsCopied => 'تم نسخ التفاصيل';
  @override
  String get dismiss => 'إغلاق';
  @override
  String get showingCachedData => 'يتم عرض آخر بيانات تم تحميلها';

  @override
  String get language => 'اللغة';

  @override
  String get justNow => 'الآن';
  @override
  String secondsAgo(int n) => arabicPlural(
        n,
        zero: 'الآن',
        one: 'منذ ثانية',
        two: 'منذ ثانيتين',
        few: 'منذ $n ثوانٍ',
        many: 'منذ $n ثانية',
        other: 'منذ $n ثانية',
      );
  @override
  String minutesAgo(int n) => arabicPlural(
        n,
        zero: 'الآن',
        one: 'منذ دقيقة',
        two: 'منذ دقيقتين',
        few: 'منذ $n دقائق',
        many: 'منذ $n دقيقة',
        other: 'منذ $n دقيقة',
      );
  @override
  String hoursAgo(int n) => arabicPlural(
        n,
        zero: 'الآن',
        one: 'منذ ساعة',
        two: 'منذ ساعتين',
        few: 'منذ $n ساعات',
        many: 'منذ $n ساعة',
        other: 'منذ $n ساعة',
      );
  @override
  String daysAgo(int n) => arabicPlural(
        n,
        zero: 'اليوم',
        one: 'منذ يوم',
        two: 'منذ يومين',
        few: 'منذ $n أيام',
        many: 'منذ $n يومًا',
        other: 'منذ $n يوم',
      );

  @override
  String money(double amount) => '${amount.toStringAsFixed(2)} ر.س';

  @override
  String get keeta => 'كيتا';
  @override
  String get hungerStation => 'هنقرستيشن';
}
