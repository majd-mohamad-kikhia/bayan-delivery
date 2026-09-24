import 'package:bayan_desktop/core/platforms/auth/auth_token.dart';
import 'package:bayan_desktop/core/platforms/common/platform_api_exception.dart';
import 'package:bayan_desktop/core/platforms/common/delivery_platform.dart';
import 'package:bayan_desktop/core/platforms/keeta/keeta_endpoints.dart';
import 'package:bayan_desktop/core/platforms/keeta/keeta_signer.dart';
import 'package:bayan_desktop/core/platforms/keeta/keeta_types.dart';
import 'package:bayan_desktop/core/platforms/keeta/keeta_webhook.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  var now = DateTime.utc(2026, 9, 21, 12);
  DateTime clock() => now;

  setUp(() => now = DateTime.utc(2026, 9, 21, 12));

  AuthToken seed({
    Duration expiresIn = const Duration(days: 60),
    DateTime? obtainedAt,
  }) => AuthToken(
    accessToken: 'access-1',
    refreshToken: 'refresh-1',
    expiresAt: now.add(expiresIn),
    obtainedAt: obtainedAt,
  );

  test('sends signed requests with the documented order fields', () async {
    final executor = FakeExecutor((_) => keetaOk());
    final apis = await buildApis(executor, keetaSeed: seed(), clock: clock);

    await apis.keeta.orders.cancel(
      shopId: 466663,
      orderViewId: 756823555555859,
      code: KeetaCancelCode.other,
      reason: 'too expensive',
    );

    final request = executor.requests.single;
    expect(request.url, 'https://open.mykeeta.com/api/open/order/cancel');
    expect(request.params, containsPair('orderViewId', 756823555555859));
    expect(request.params, containsPair('cancelCode', 500000));
    expect(request.params, containsPair('cancelReason', 'too expensive'));
    expect(request.params, containsPair('accessToken', 'access-1'));
    expect(request.params, containsPair('appId', 123));
    expect(
      KeetaSigner.verify(
        url: request.url,
        params: request.params,
        appSecret: 'secret',
      ),
      isTrue,
    );
  });

  test('rejects a missing "other" reason before any request', () async {
    final executor = FakeExecutor((_) => keetaOk());
    final apis = await buildApis(executor, keetaSeed: seed(), clock: clock);

    expect(
      () => apis.keeta.orders.cancel(
        shopId: 1,
        orderViewId: 2,
        code: KeetaCancelCode.other,
      ),
      throwsArgumentError,
    );
    expect(executor.requests, isEmpty);
  });

  test('non-zero code becomes a classified PlatformApiException', () async {
    final executor = FakeExecutor(
      (_) => {'code': 115000250, 'message': 'order not found'},
    );
    final apis = await buildApis(executor, keetaSeed: seed(), clock: clock);

    await expectLater(
      apis.keeta.orders.confirm(shopId: 1, orderViewId: 2),
      throwsA(
        isA<PlatformApiException>()
            .having((e) => e.code, 'code', 115000250)
            .having((e) => e.kind, 'kind', PlatformErrorKind.rejected)
            .having((e) => e.message, 'message', 'order not found')
            .having((e) => e.platform, 'platform', DeliveryPlatform.keeta),
      ),
    );
  });

  test('identical concurrent reads share one request; writes do not', () async {
    final executor = FakeExecutor((_) => keetaOk({'shopId': 1}));
    final apis = await buildApis(executor, keetaSeed: seed(), clock: clock);

    await Future.wait([
      apis.keeta.shop.details(1),
      apis.keeta.shop.details(1),
      apis.keeta.shop.details(1),
    ]);
    expect(executor.requests, hasLength(1));

    await Future.wait([apis.keeta.shop.suspend(1), apis.keeta.shop.suspend(1)]);
    expect(executor.requestsTo(KeetaEndpoints.suspendShop.id), hasLength(2));
  });

  test('retries transient failures on reads only', () async {
    var calls = 0;
    final executor = FakeExecutor((_) {
      if (++calls == 1) {
        throw const PlatformApiException(
          'down',
          platform: DeliveryPlatform.keeta,
          kind: PlatformErrorKind.transport,
        );
      }
      return keetaOk({'orderInfo': {}});
    });
    final apis = await buildApis(executor, keetaSeed: seed(), clock: clock);

    expect(await apis.keeta.orders.details(shopId: 1, orderViewId: 2), {
      'orderInfo': {},
    });
    expect(calls, 2);

    calls = 0;
    await expectLater(
      apis.keeta.orders.confirm(shopId: 1, orderViewId: 2),
      throwsA(isA<PlatformApiException>()),
    );
    expect(calls, 1, reason: 'a confirm must never be replayed blindly');
  });

  test(
    'batch availability is chunked by 200 and partial failures merged',
    () async {
      final executor = FakeExecutor((request) {
        final ids = request.params['spuIdList']! as List;
        return {
          'code': 0,
          'message': 'Partial Failure',
          'data': [ids.length],
          'errorList': [if (ids.length == 50) 'spu 999 missing'],
        };
      });
      final apis = await buildApis(executor, keetaSeed: seed(), clock: clock);

      final result = await apis.keeta.menu.setProductsAvailable(
        shopId: 1,
        spuIds: List.generate(450, (i) => i),
        available: false,
      );

      expect(
        executor.requests.map((r) => (r.params['spuIdList']! as List).length),
        [200, 200, 50],
      );
      expect(executor.requests.first.params['status'], 0);
      expect(result.data, [200, 200, 50]);
      expect(result.errorList, ['spu 999 missing']);
      expect(result.hasPartialFailure, isTrue);
    },
  );

  test(
    'refreshes proactively inside the window, once for concurrent callers',
    () async {
      final executor = FakeExecutor((request) {
        if (request.endpoint == KeetaEndpoints.oauthToken) {
          return {
            'accessToken': 'access-2',
            'refreshToken': 'refresh-2',
            'expiresIn': 7776000,
          };
        }
        return keetaOk();
      });
      final apis = await buildApis(
        executor,
        keetaSeed: seed(expiresIn: const Duration(days: 3)),
        clock: clock,
      );

      await Future.wait([
        apis.keeta.orders.confirm(shopId: 1, orderViewId: 1),
        apis.keeta.orders.confirm(shopId: 1, orderViewId: 2),
      ]);

      final refreshes = executor.requestsTo(KeetaEndpoints.oauthToken.id);
      expect(refreshes, hasLength(1));
      expect(
        refreshes.single.params,
        containsPair('grantType', 'refresh_token'),
      );
      expect(
        refreshes.single.params,
        containsPair('refreshToken', 'refresh-1'),
      );
      expect(refreshes.single.params.containsKey('accessToken'), isFalse);

      final calls = executor.requestsTo(KeetaEndpoints.confirmOrder.id);
      expect(
        calls.map((r) => r.params['accessToken']),
        everyElement('access-2'),
      );
      expect(apis.keeta.auth.currentToken?.refreshToken, 'refresh-2');
      expect(
        apis.keeta.auth.currentToken?.expiresAt,
        now.add(const Duration(days: 90)),
      );
    },
  );

  test(
    'recovers from a rejected token by refreshing and replaying once',
    () async {
      final executor = FakeExecutor((request) {
        if (request.endpoint == KeetaEndpoints.oauthToken) {
          return {
            'accessToken': 'access-2',
            'refreshToken': 'refresh-2',
            'expiresIn': 7776000,
          };
        }
        return request.params['accessToken'] == 'access-1'
            ? {'code': 115000120, 'message': 'token expired'}
            : keetaOk();
      });
      final apis = await buildApis(executor, keetaSeed: seed(), clock: clock);

      await apis.keeta.orders.markReady(shopId: 1, orderViewId: 2);

      expect(executor.requests.map((r) => r.endpoint.id), [
        KeetaEndpoints.orderReady.id,
        KeetaEndpoints.oauthToken.id,
        KeetaEndpoints.orderReady.id,
      ]);
    },
  );

  test('does not burn refresh tokens when a fresh token is rejected', () async {
    final executor = FakeExecutor(
      (_) => {'code': 115000110, 'message': 'The sig calculation error'},
    );
    final apis = await buildApis(
      executor,
      keetaSeed: seed(obtainedAt: now),
      clock: clock,
    );

    await expectLater(
      apis.keeta.orders.markReady(shopId: 1, orderViewId: 2),
      throwsA(
        isA<PlatformApiException>().having(
          (e) => e.isAuthError,
          'isAuthError',
          isTrue,
        ),
      ),
    );
    expect(executor.requestsTo(KeetaEndpoints.oauthToken.id), isEmpty);
  });

  test('authorizedShops fetches remaining pages after page 1', () async {
    final executor = FakeExecutor((request) {
      final page = request.params['pageNum']! as int;
      return keetaOk({
        'authorizedShops': [
          {'id': page, 'name': 'Shop $page'},
        ],
        'page': {'pageNum': page, 'totalPage': 3},
      });
    });
    final apis = await buildApis(executor, keetaSeed: seed(), clock: clock);

    final shops = await apis.keeta.account.authorizedShops();
    expect(shops.map((s) => s['id']), [1, 2, 3]);
    expect(executor.requests.first.params['pageSize'], 200);
  });

  test('missing credentials fail fast as notConfigured', () async {
    final executor = FakeExecutor((_) => keetaOk());
    final apis = await buildApis(executor, prefs: const {}, clock: clock);

    await expectLater(
      apis.keeta.shop.details(1),
      throwsA(
        isA<PlatformApiException>().having(
          (e) => e.kind,
          'kind',
          PlatformErrorKind.notConfigured,
        ),
      ),
    );
    expect(executor.requests, isEmpty);
  });

  test('webhook message is decoded twice', () {
    final hook = KeetaWebhook.tryParse({
      'sig': 'x',
      'eventId': 1002,
      'appId': 3762772727,
      'messageId': '1930106161957212198',
      'shopId': 145541,
      'message':
          '{"opTime":1749008143025,"orderViewId":553440887574627,"shopId":145541,"status":30}',
      'timestamp': 1749008143,
    })!;
    expect(hook.event, KeetaWebhookEvent.orderAccepted);
    expect(hook.orderViewId, 553440887574627);
    expect(KeetaWebhook.tryParse(const {}), isNull, reason: 'heartbeat');
  });
}
