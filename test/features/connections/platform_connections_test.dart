import 'package:bayan_desktop/core/platforms/common/delivery_platform.dart';
import 'package:bayan_desktop/core/platforms/common/platform_api_exception.dart';
import 'package:bayan_desktop/core/storage/app_preferences.dart';
import 'package:bayan_desktop/features/connections/data/platform_connections.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/platforms/fakes.dart';

void main() {
  late FakeExecutor executor;
  late PlatformConnections connections;
  late AppPreferences preferences;
  late List<Map<String, Object?>> shops;
  Object? Function()? failure;

  Future<void> build({Map<String, Object> prefs = const {}}) async {
    executor = FakeExecutor((request) {
      final fail = failure?.call();
      if (fail != null) throw fail;
      if (request.url.contains('deliveryhero')) {
        return request.url.endsWith('/v2/oauth/token')
            ? {'access_token': 'hs-token', 'token_type': 'Bearer', 'expires_in': 7200}
            : {'status': 'OPEN'};
      }
      return keetaOk({
        'brandName': 'Al-Bayan Brand',
        'authorizedShops': shops,
        'page': {'pageNum': 1, 'totalPage': 1},
      });
    });
    final apis = await buildApis(executor, prefs: prefs);
    preferences = AppPreferences(await SharedPreferences.getInstance());
    connections = PlatformConnections(
      apis,
      preferences,
      clock: () => DateTime.utc(2026, 10, 18, 12),
    );
  }

  setUp(() {
    shops = [
      {'id': 466663, 'name': 'Main branch', 'address': 'Riyadh'},
    ];
    failure = null;
  });

  test('the token is stored, used to list the shops, and a single shop is selected', () async {
    await build(prefs: const {});
    final result = await connections.connectKeeta(
      appId: 834563,
      appSecret: 'the-secret',
      accessToken: ' tok-abc-1234 ',
    );

    expect(result.ok, isTrue);
    expect(result.brandName, 'Al-Bayan Brand');
    expect(result.shopId, 466663);
    expect(preferences.keetaShopId, 466663);

    final request = executor.requests.first;
    expect(request.params['accessToken'], 'tok-abc-1234');
    expect(request.params['appId'], 834563);

    final snapshot = connections.keetaSnapshot();
    expect(snapshot.appId, 834563);
    expect(snapshot.hasSecret, isTrue);
    expect(snapshot.tokenTail, '1234');
    expect(snapshot.shopId, 466663);
  });

  test('with several shops none is picked until the caller chooses', () async {
    shops = [
      {'id': 1, 'name': 'A'},
      {'id': 2, 'name': 'B'},
    ];
    await build(prefs: keetaPrefs);
    final result = await connections.connectKeeta(accessToken: 'tok-1');
    expect(result.ok, isTrue);
    expect(result.shops.map((s) => s.id), [1, 2]);
    expect(result.shopId, isNull);
    expect(preferences.keetaShopId, isNull);

    // Typing a shop that is on the list selects it.
    final again = await connections.connectKeeta(shopId: 2);
    expect(again.shopId, 2);
    expect(preferences.keetaShopId, 2);

    // A shop the token cannot use is not stored.
    final wrong = await connections.connectKeeta(shopId: 99);
    expect(wrong.shopId, isNull);
  });

  test('blank fields keep what is stored; a rejected token is reported, not thrown', () async {
    await build(prefs: keetaPrefs);
    await connections.connectKeeta(accessToken: 'tok-keep-9999');
    expect(connections.keetaSnapshot().appId, 123, reason: 'App ID kept');

    failure = () => const PlatformApiException(
      'Token is invalid',
      platform: DeliveryPlatform.keeta,
      kind: PlatformErrorKind.unauthorized,
    );
    final result = await connections.connectKeeta(accessToken: 'bad');
    expect(result.ok, isFalse);
    expect(result.error, 'Token is invalid');
  });

  test('HungerStation values are stored and checked with a real call', () async {
    await build(prefs: const {});
    final error = await connections.connectHungerStation(
      clientId: ' my-client ',
      clientSecret: 'my-secret',
      chainId: 'chain-9',
      vendorId: 'vendor-9',
      sandbox: true,
    );
    expect(error, isNull);

    final snapshot = connections.hungerStationSnapshot();
    expect(snapshot.clientId, 'my-client');
    expect(snapshot.chainId, 'chain-9');
    expect(snapshot.vendorId, 'vendor-9');
    expect(snapshot.sandbox, isTrue);
    expect(snapshot.hasSecret, isTrue);
    expect(executor.requests.any((r) => r.url.contains('chain-9')), isTrue);
  });

  test('Bayan: the key is 8 characters or a 32-character md5; accounts are stored', () async {
    await build(prefs: const {});
    expect(PlatformConnections.normalizeOrderKey(' abcd1234 '), 'abcd1234');
    expect(
      PlatformConnections.normalizeOrderKey('0123456789abcdef0123456789ABCDEF'),
      '01234567',
    );
    expect(PlatformConnections.normalizeOrderKey('short'), isNull);
    expect(PlatformConnections.normalizeOrderKey('x' * 32), isNull);

    expect(await connections.saveBayan(orderKey: 'nope'), isNotNull);
    expect(connections.bayanSnapshot().hasKey, isFalse);

    expect(
      await connections.saveBayan(
        orderKey: 'abcd1234',
        keetaAccount: 120,
        hungerStationAccount: 121,
      ),
      isNull,
    );
    expect(preferences.bayanOrderKey, 'abcd1234');
    var snapshot = connections.bayanSnapshot();
    expect((snapshot.hasKey, snapshot.keetaAccount, snapshot.hungerStationAccount), (true, 120, 121));

    // A blank key keeps the stored one; clearing an account removes it.
    await connections.saveBayan(keetaAccount: 120);
    expect(preferences.bayanOrderKey, 'abcd1234');
    snapshot = connections.bayanSnapshot();
    expect(snapshot.hungerStationAccount, isNull);
  });
}
