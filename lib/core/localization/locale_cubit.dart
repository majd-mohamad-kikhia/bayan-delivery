import 'package:flutter_bloc/flutter_bloc.dart';

import '../storage/app_preferences.dart';
import 'app_language.dart';

final class LocaleCubit extends Cubit<AppLanguage> {
  LocaleCubit(this._preferences)
      : super(AppLanguage.fromCode(_preferences.languageCode));

  final AppPreferences _preferences;

  void change(AppLanguage language) {
    if (language == state) return;
    emit(language);
    _preferences.setLanguageCode(language.code);
  }

  void toggle() =>
      change(state == AppLanguage.ar ? AppLanguage.en : AppLanguage.ar);
}
