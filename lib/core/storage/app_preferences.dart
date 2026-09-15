import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

class AppPreferences {
  AppPreferences(this._prefs);

  static const _dongleKey = 'dongle_number';
  static const _keetaShopIdKey = 'keeta_shop_id';

  final SharedPreferences _prefs;

  static Future<AppPreferences> create() async {
    return AppPreferences(await SharedPreferences.getInstance());
  }

  String get dongleNumber =>
      _prefs.getString(_dongleKey) ?? AppConstants.defaultDongleNumber;

  Future<void> setDongleNumber(String value) => _prefs.setString(_dongleKey, value);

  int? get keetaShopId {
    final value = _prefs.getInt(_keetaShopIdKey);
    return value == null || value == 0 ? null : value;
  }

  Future<void> setKeetaShopId(int shopId) => _prefs.setInt(_keetaShopIdKey, shopId);
}
