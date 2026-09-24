import 'package:bayan_desktop/core/platforms/config/platform_credentials.dart';
import 'package:bayan_desktop/core/platforms/keeta/keeta_endpoints.dart';
import 'package:bayan_desktop/core/platforms/keeta/keeta_signer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const url = 'https://open.mykeeta.com/api/open/product/shopcategory/update';

  test('matches the example in Keeta Authorization Guide §2', () {
    final sig = KeetaSigner.sign(
      url: url,
      appSecret: 'abc',
      params: {
        'appId': 123,
        'timestamp': 1682566749,
        'accessToken': 'abc',
        'shopId': 123,
        'shopCategory': {
          'id': 123,
          'name': 'test',
          'type': 0,
          'description': null,
        },
      },
    );
    expect(
      sig,
      '48eb6d562bb0673e3db753831f032be237fc19d1e5c33fcb5386d89c0eebca86',
    );
  });

  test('ignores an existing sig and key order', () {
    final a = KeetaSigner.sign(
      url: url,
      appSecret: 's',
      params: {'b': 2, 'a': 1},
    );
    final b = KeetaSigner.sign(
      url: url,
      appSecret: 's',
      params: {'a': 1, 'sig': 'old', 'b': 2},
    );
    expect(a, b);
  });

  test('signedRequest adds common params and a verifiable sig', () {
    final request = KeetaSigner.signedRequest(
      endpoint: KeetaEndpoints.confirmOrder,
      credentials: const KeetaCredentials(appId: 7, appSecret: 'secret'),
      params: {'shopId': 1, 'orderViewId': 2},
      now: DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true),
      accessToken: 'token',
    );

    expect(request.url, 'https://open.mykeeta.com/api/open/order/confirm');
    expect(request.params, containsPair('appId', 7));
    expect(request.params, containsPair('accessToken', 'token'));
    expect(request.params, containsPair('timestamp', 1700000000));
    expect(
      KeetaSigner.verify(
        url: request.url,
        params: request.params,
        appSecret: 'secret',
      ),
      isTrue,
    );
    expect(
      KeetaSigner.verify(
        url: request.url,
        params: request.params,
        appSecret: 'wrong',
      ),
      isFalse,
    );
  });
}
