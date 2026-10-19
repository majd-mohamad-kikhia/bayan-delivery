import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

class AppPreferences {
  AppPreferences(this._prefs);

  static const _dongleKey = 'dongle_number';
  static const _keetaShopIdKey = 'keeta_shop_id';
  static const _bayanOrderKeyKey = 'bayan_order_key';
  static const _bayanAccountPrefix = 'bayan_account.';
  static const _languageKey = 'language_code';
  static const _sidebarCollapsedKey = 'sidebar_collapsed';
  static const _bulkKeetaCategoryKey = 'bulk_keeta_category';
  static const _bulkHsCategoryKey = 'bulk_hs_category';
  static const _lastCourierKey = 'last_courier';
  static const _reportsFilterKey = 'reports_filter';
  static const _alertMutedKey = 'order_alert_muted';
  static const _autoAddKey = 'auto_add_new_products';
  static const _reportsPlatformKey = 'reports_platform';
  static const _erpProductsSyncKey = 'erp_products_last_sync';
  static const _bulkBarcodeFromSkuKey = 'bulk_barcode_from_sku';

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

  /// The 8-character key stamped into the `Hash` of every order sent to Bayan.
  String get bayanOrderKey => _prefs.getString(_bayanOrderKeyKey) ?? '';

  Future<void> setBayanOrderKey(String value) =>
      _prefs.setString(_bayanOrderKeyKey, value);

  /// Bayan account number (`AccNum`) the orders of [platform] are booked to.
  int? bayanAccount(String platform) {
    final value = _prefs.getInt('$_bayanAccountPrefix$platform');
    return value == null || value <= 0 ? null : value;
  }

  Future<void> setBayanAccount(String platform, int? account) => account == null
      ? _prefs.remove('$_bayanAccountPrefix$platform')
      : _prefs.setInt('$_bayanAccountPrefix$platform', account);

  bool get sidebarCollapsed => _prefs.getBool(_sidebarCollapsedKey) ?? false;

  Future<void> setSidebarCollapsed(bool value) =>
      _prefs.setBool(_sidebarCollapsedKey, value);

  /// Last values used by the bulk "add to all platforms" dialog.
  String get bulkKeetaCategory => _prefs.getString(_bulkKeetaCategoryKey) ?? '';
  String get bulkHsCategory => _prefs.getString(_bulkHsCategoryKey) ?? '';
  bool get bulkBarcodeFromSku => _prefs.getBool(_bulkBarcodeFromSkuKey) ?? true;

  Future<void> setBulkDefaults({
    required String keetaCategory,
    required String hsCategory,
    required bool barcodeFromSku,
  }) async {
    await _prefs.setString(_bulkKeetaCategoryKey, keetaCategory);
    await _prefs.setString(_bulkHsCategoryKey, hsCategory);
    await _prefs.setBool(_bulkBarcodeFromSkuKey, barcodeFromSku);
  }

  /// When the Bayan ERP products were last synced (survives restarts).
  DateTime? get erpProductsLastSync {
    final millis = _prefs.getInt(_erpProductsSyncKey);
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<void> setErpProductsLastSync(DateTime value) =>
      _prefs.setInt(_erpProductsSyncKey, value.millisecondsSinceEpoch);

  /// The courier used last, as JSON (name, phone, vehicle, plate), so the
  /// next dispatch starts pre-filled.
  Map<String, Object?> get lastCourier {
    final raw = _prefs.getString(_lastCourierKey);
    if (raw == null) return const {};
    try {
      return (jsonDecode(raw) as Map).cast<String, Object?>();
    } catch (_) {
      return const {};
    }
  }

  Future<void> setLastCourier(Map<String, Object?> value) =>
      _prefs.setString(_lastCourierKey, jsonEncode(value));

  /// The Reports date range last chosen, as JSON `{preset, start?, end?}`.
  String? get reportsFilter => _prefs.getString(_reportsFilterKey);
  Future<void> setReportsFilter(String json) => _prefs.setString(_reportsFilterKey, json);

  /// The Reports platform last chosen: `all`, `keeta` or `hungerstation`.
  String get reportsPlatform => _prefs.getString(_reportsPlatformKey) ?? 'all';
  Future<void> setReportsPlatform(String platform) => _prefs.setString(_reportsPlatformKey, platform);

  /// The repeating new-order sound is switched off (the light stays).
  bool get orderAlertMuted => _prefs.getBool(_alertMutedKey) ?? false;
  Future<void> setOrderAlertMuted(bool value) => _prefs.setBool(_alertMutedKey, value);

  /// New Al-Bayan products are put on the platforms by the sync, without a
  /// button. On unless switched off.
  bool get autoAddNewProducts => _prefs.getBool(_autoAddKey) ?? true;
  Future<void> setAutoAddNewProducts(bool value) => _prefs.setBool(_autoAddKey, value);

  String? get languageCode => _prefs.getString(_languageKey);

  Future<void> setLanguageCode(String code) => _prefs.setString(_languageKey, code);
}
