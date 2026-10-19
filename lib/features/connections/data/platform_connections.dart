import '../../../core/platforms/platforms.dart';
import '../../../core/storage/app_preferences.dart';

/// One shop Keeta says the token may use.
final class KeetaShop {
  const KeetaShop({required this.id, required this.name, this.address = ''});

  final int id;
  final String name;
  final String address;
}

/// What a Keeta connection test found.
final class KeetaConnectionResult {
  const KeetaConnectionResult({
    this.brandName = '',
    this.shops = const [],
    this.shopId,
    this.error,
  });

  final String brandName;
  final List<KeetaShop> shops;

  /// The shop now in use (null when several shops exist and none was chosen).
  final int? shopId;
  final String? error;

  bool get ok => error == null;
}

/// What is set up for Keeta right now, for the connection form.
final class KeetaSnapshot {
  const KeetaSnapshot({
    required this.appId,
    required this.hasSecret,
    required this.tokenTail,
    required this.shopId,
    required this.testValues,
  });

  final int appId;
  final bool hasSecret;

  /// Last characters of the access token, or null when there is none.
  final String? tokenTail;
  final int? shopId;

  /// The values are the placeholders debug builds use with the mock backend.
  final bool testValues;
}

final class BayanSnapshot {
  const BayanSnapshot({
    required this.hasKey,
    required this.keetaAccount,
    required this.hungerStationAccount,
  });

  final bool hasKey;
  final int? keetaAccount;
  final int? hungerStationAccount;
}

final class HungerStationSnapshot {
  const HungerStationSnapshot({
    required this.clientId,
    required this.hasSecret,
    required this.chainId,
    required this.vendorId,
    required this.sandbox,
    required this.testValues,
  });

  final String clientId;
  final bool hasSecret;
  final String chainId;
  final String vendorId;
  final bool sandbox;
  final bool testValues;
}

/// Saves what a restaurant types in to connect Keeta or HungerStation, and
/// checks it against the platform right away.
class PlatformConnections {
  PlatformConnections(
    this._apis,
    this._preferences, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final PlatformApis _apis;
  final AppPreferences _preferences;
  final DateTime Function() _clock;

  static const _mockSecret = 'mock-secret';

  KeetaSnapshot keetaSnapshot() {
    final credentials = _apis.credentials.keeta;
    final token = _apis.keeta.auth.currentToken?.accessToken;
    return KeetaSnapshot(
      appId: credentials.appId,
      hasSecret: credentials.appSecret.isNotEmpty,
      tokenTail: token == null || token.isEmpty
          ? null
          : token.substring(token.length > 4 ? token.length - 4 : 0),
      shopId: _preferences.keetaShopId,
      testValues:
          credentials.appSecret == _mockSecret ||
          token == 'mock-keeta-access-token',
    );
  }

  HungerStationSnapshot hungerStationSnapshot() {
    final credentials = _apis.credentials.hungerStation;
    return HungerStationSnapshot(
      clientId: credentials.clientId,
      hasSecret: credentials.clientSecret.isNotEmpty,
      chainId: credentials.chainId,
      vendorId: credentials.vendorId,
      sandbox: credentials.environment == HsEnvironment.sandbox,
      testValues: credentials.clientSecret == _mockSecret,
    );
  }

  /// Stores what was entered (a blank field keeps what is already stored),
  /// then asks Keeta which shops the token can use.
  ///
  /// With one shop it is selected on its own. With several, [shopId] must be
  /// one of them, otherwise [KeetaConnectionResult.shopId] stays null and the
  /// caller shows the list to choose from.
  Future<KeetaConnectionResult> connectKeeta({
    int? appId,
    String appSecret = '',
    String accessToken = '',
    String refreshToken = '',
    int? shopId,
  }) async {
    try {
      final stored = _apis.credentials.keeta;
      if ((appId != null && appId > 0) || appSecret.trim().isNotEmpty) {
        await _apis.credentials.saveKeeta(
          KeetaCredentials(
            appId: appId != null && appId > 0 ? appId : stored.appId,
            appSecret: appSecret.trim().isEmpty
                ? stored.appSecret
                : appSecret.trim(),
          ),
        );
      }
      if (accessToken.trim().isNotEmpty) {
        await _apis.keeta.auth.adoptToken(
          AuthToken(
            accessToken: accessToken.trim(),
            refreshToken: refreshToken.trim().isEmpty
                ? null
                : refreshToken.trim(),
            obtainedAt: _clock().toUtc(),
          ),
        );
      }

      final shops = [
        for (final s in await _apis.keeta.account.authorizedShops())
          if ((s['id'] as num?)?.toInt() case final id?)
            KeetaShop(
              id: id,
              name: '${s['name'] ?? id}',
              address: '${s['address'] ?? ''}',
            ),
      ];
      final brand = (await _apis.keeta.account
          .authorizedResources())['brandName'];

      final chosen = _chooseShop(shops, shopId);
      if (chosen != null) await _preferences.setKeetaShopId(chosen);
      return KeetaConnectionResult(
        brandName: '${brand ?? ''}',
        shops: shops,
        shopId: chosen,
      );
    } on Object catch (e) {
      return KeetaConnectionResult(error: _message(e));
    }
  }

  static int? _chooseShop(List<KeetaShop> shops, int? wanted) {
    if (wanted != null && shops.any((s) => s.id == wanted)) return wanted;
    return shops.length == 1 ? shops.single.id : null;
  }

  Future<void> chooseKeetaShop(int shopId) =>
      _preferences.setKeetaShopId(shopId);

  /// Stores the HungerStation values and checks them with a call that needs
  /// the token and the vendor. Returns an error message, or null when it works.
  Future<String?> connectHungerStation({
    required String clientId,
    String clientSecret = '',
    required String chainId,
    required String vendorId,
    required bool sandbox,
  }) async {
    try {
      final stored = _apis.credentials.hungerStation;
      await _apis.credentials.saveHungerStation(
        HungerStationCredentials(
          clientId: clientId.trim(),
          clientSecret: clientSecret.trim().isEmpty
              ? stored.clientSecret
              : clientSecret.trim(),
          chainId: chainId.trim(),
          vendorId: vendorId.trim(),
          environment: sandbox
              ? HsEnvironment.sandbox
              : HsEnvironment.production,
        ),
      );
      await _apis.hungerStation.outletStatus();
      return null;
    } on Object catch (e) {
      return _message(e);
    }
  }

  // ── Bayan (orders booked as invoices) ──────────────────────────────────────

  /// The 8-character key out of what was typed: exactly 8 characters as they
  /// are, or a 32-character md5 (its first 8 characters). Null otherwise.
  static String? normalizeOrderKey(String input) {
    final text = input.trim();
    if (text.runes.length == 8) return text;
    if (RegExp(r'^[0-9a-fA-F]{32}$').hasMatch(text)) {
      return text.substring(0, 8);
    }
    return null;
  }

  BayanSnapshot bayanSnapshot() => BayanSnapshot(
    hasKey: _preferences.bayanOrderKey.isNotEmpty,
    keetaAccount: _preferences.bayanAccount('keeta'),
    hungerStationAccount: _preferences.bayanAccount('hungerstation'),
  );

  /// Saves the Bayan settings. A blank [orderKey] keeps the stored one.
  /// Returns an error message, or null.
  Future<String?> saveBayan({
    String orderKey = '',
    int? keetaAccount,
    int? hungerStationAccount,
  }) async {
    if (orderKey.trim().isNotEmpty) {
      final key = normalizeOrderKey(orderKey);
      if (key == null) {
        return 'The key must be 8 characters (or the 32-character md5).';
      }
      await _preferences.setBayanOrderKey(key);
    }
    await _preferences.setBayanAccount('keeta', keetaAccount);
    await _preferences.setBayanAccount('hungerstation', hungerStationAccount);
    return null;
  }

  static String _message(Object e) =>
      e is PlatformApiException ? e.message : '$e';
}
