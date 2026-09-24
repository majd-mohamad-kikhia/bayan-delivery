import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_token.dart';
import '../common/delivery_platform.dart';
import '../common/platform_api_exception.dart';
import 'platform_credentials.dart';

/// Where platform credentials come from, in priority order:
/// 1. values saved at runtime via [saveKeeta] / [saveHungerStation]
///    (for a future settings screen);
/// 2. `--dart-define` values baked in at build time:
///
/// ```bash
/// flutter run -d macos \
///   --dart-define=KEETA_APP_ID=... --dart-define=KEETA_APP_SECRET=... \
///   --dart-define=KEETA_ACCESS_TOKEN=... --dart-define=KEETA_REFRESH_TOKEN=... \
///   --dart-define=HS_CLIENT_ID=... --dart-define=HS_CLIENT_SECRET=... \
///   --dart-define=HS_CHAIN_ID=... --dart-define=HS_VENDOR_ID=... \
///   --dart-define=HS_SANDBOX=true
/// ```
///
/// Values are memoized; a save invalidates the memo.
class PlatformCredentialsStore {
  PlatformCredentialsStore(this._prefs, {AuthToken? keetaSeedToken})
    : _keetaSeedOverride = keetaSeedToken;

  static const _keetaAppId = 'platform.keeta.app_id';
  static const _keetaAppSecret = 'platform.keeta.app_secret';
  static const _hsClientId = 'platform.hs.client_id';
  static const _hsClientSecret = 'platform.hs.client_secret';
  static const _hsChainId = 'platform.hs.chain_id';
  static const _hsVendorId = 'platform.hs.vendor_id';
  static const _hsEnvironment = 'platform.hs.environment';

  final SharedPreferences _prefs;
  final AuthToken? _keetaSeedOverride;

  KeetaCredentials? _keeta;
  HungerStationCredentials? _hungerStation;

  KeetaCredentials get keeta => _keeta ??= KeetaCredentials(
    appId:
        _prefs.getInt(_keetaAppId) ??
        int.tryParse(const String.fromEnvironment('KEETA_APP_ID')) ??
        0,
    appSecret:
        _prefs.getString(_keetaAppSecret) ??
        const String.fromEnvironment('KEETA_APP_SECRET'),
  );

  HungerStationCredentials get hungerStation =>
      _hungerStation ??= HungerStationCredentials(
        clientId:
            _prefs.getString(_hsClientId) ??
            const String.fromEnvironment('HS_CLIENT_ID'),
        clientSecret:
            _prefs.getString(_hsClientSecret) ??
            const String.fromEnvironment('HS_CLIENT_SECRET'),
        chainId:
            _prefs.getString(_hsChainId) ??
            const String.fromEnvironment('HS_CHAIN_ID'),
        vendorId:
            _prefs.getString(_hsVendorId) ??
            const String.fromEnvironment('HS_VENDOR_ID'),
        environment: switch (_prefs.getString(_hsEnvironment)) {
          'sandbox' => HsEnvironment.sandbox,
          'production' => HsEnvironment.production,
          _ =>
            const bool.fromEnvironment('HS_SANDBOX')
                ? HsEnvironment.sandbox
                : HsEnvironment.production,
        },
      );

  /// Merchant token supplied at build time (Keeta "Simplified Mode": copied
  /// from the dashboard). Used until the first refresh replaces it.
  late final AuthToken? keetaSeedToken = _keetaSeedOverride ?? _readKeetaSeed();

  /// Short hash identifying [keetaSeedToken] without storing it twice.
  late final String? keetaSeedFingerprint = switch (keetaSeedToken) {
    final seed? =>
      sha256.convert(utf8.encode(seed.accessToken)).toString().substring(0, 16),
    null => null,
  };

  KeetaCredentials requireKeeta() {
    final credentials = keeta;
    if (credentials.isComplete) return credentials;
    throw const PlatformApiException(
      'Keeta credentials are missing (KEETA_APP_ID / KEETA_APP_SECRET).',
      platform: DeliveryPlatform.keeta,
      kind: PlatformErrorKind.notConfigured,
    );
  }

  HungerStationCredentials requireHungerStation() {
    final credentials = hungerStation;
    if (credentials.isComplete) return credentials;
    throw const PlatformApiException(
      'HungerStation credentials are missing (HS_CLIENT_ID / HS_CLIENT_SECRET / HS_CHAIN_ID).',
      platform: DeliveryPlatform.hungerStation,
      kind: PlatformErrorKind.notConfigured,
    );
  }

  Future<void> saveKeeta(KeetaCredentials credentials) async {
    _keeta = credentials;
    await Future.wait([
      _prefs.setInt(_keetaAppId, credentials.appId),
      _prefs.setString(_keetaAppSecret, credentials.appSecret),
    ]);
  }

  Future<void> saveHungerStation(HungerStationCredentials credentials) async {
    _hungerStation = credentials;
    await Future.wait([
      _prefs.setString(_hsClientId, credentials.clientId),
      _prefs.setString(_hsClientSecret, credentials.clientSecret),
      _prefs.setString(_hsChainId, credentials.chainId),
      _prefs.setString(_hsVendorId, credentials.vendorId),
      _prefs.setString(_hsEnvironment, credentials.environment.name),
    ]);
  }

  static AuthToken? _readKeetaSeed() {
    const access = String.fromEnvironment('KEETA_ACCESS_TOKEN');
    if (access.isEmpty) return null;
    const refresh = String.fromEnvironment('KEETA_REFRESH_TOKEN');
    // Unix seconds; 0 = unknown.
    const expiresAt = int.fromEnvironment('KEETA_TOKEN_EXPIRES_AT');
    return AuthToken(
      accessToken: access,
      refreshToken: refresh.isEmpty ? null : refresh,
      expiresAt: expiresAt == 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000, isUtc: true),
    );
  }
}
