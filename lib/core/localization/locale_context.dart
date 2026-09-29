import 'package:flutter/widgets.dart';

import 'app_language.dart';
import 'common_strings.dart';
import 'common_strings_ar.dart';
import 'common_strings_en.dart';

/// Locale lookups for widgets.
///
/// `Localizations.localeOf` only notifies dependents when the locale changes,
/// and every strings class is a `const` singleton, so reading strings in
/// `build()` costs no allocation and triggers no extra rebuilds.
extension LocaleContext on BuildContext {
  AppLanguage get language =>
      AppLanguage.fromCode(Localizations.localeOf(this).languageCode);

  bool get isArabic => language == AppLanguage.ar;

  CommonStrings get commonStrings =>
      isArabic ? const CommonStringsAr() : const CommonStringsEn();
}
