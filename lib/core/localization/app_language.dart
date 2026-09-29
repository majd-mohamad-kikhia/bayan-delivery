import 'dart:ui';

enum AppLanguage {
  en('en', 'English'),
  ar('ar', 'العربية');

  const AppLanguage(this.code, this.nativeName);

  final String code;

  /// Always shown in its own script so users can find their language.
  final String nativeName;

  Locale get locale => Locale(code);

  bool get isRtl => this == AppLanguage.ar;

  static const List<Locale> supportedLocales = [Locale('en'), Locale('ar')];

  static AppLanguage fromCode(String? code) =>
      code == AppLanguage.ar.code ? AppLanguage.ar : AppLanguage.en;
}
