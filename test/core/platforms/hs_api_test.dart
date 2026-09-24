import 'package:bayan_desktop/core/platforms/common/delivery_platform.dart';
import 'package:bayan_desktop/core/platforms/common/http_method.dart';
import 'package:bayan_desktop/core/platforms/common/platform_api_exception.dart';
import 'package:bayan_desktop/core/platforms/hungerstation/hs_endpoints.dart';
import 'package:bayan_desktop/core/platforms/hungerstation/hs_types.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  var now = DateTime.utc(2026, 9, 21, 12);
  DateTime clock() => now;

  setUp(() => now = DateTime.utc(2026, 9, 21, 12));

  Object? tokenResponse(String token) => {
    'access_token': token,
    'token_type': 'Bearer',
    'expires_in': 7200,
  };

  test(
    'fetches one form-encoded token for concurrent calls and reuses it',
    () async {
      final executor = FakeExecutor(
        (request) => request.endpoint == HsEndpoints.token
            ? tokenResponse('jwt-1')
            : {'status': 'OPEN'},
      );
      final apis = await buildApis(executor, clock: clock);

      await Future.wait([
        apis.hungerStation.outletStatus(),
        apis.hungerStation.categories(),
        apis.hungerStation.exportCatalog(),
      ]);
      await apis.hungerStation.outletStatus(vendorId: 'other');

      final tokens = executor.requestsTo(HsEndpoints.token.id);
      expect(tokens, hasLength(1));
      expect(
        tokens.single.url,
        'https://sandbox.partner.deliveryhero.io/v2/oauth/token',
      );
      expect(
        tokens.single.headers['Content-Type'],
        'application/x-www-form-urlencoded',
      );
      expect(tokens.single.params, {
        'grant_type': 'client_credentials',
        'client_id': 'client',
        'client_secret': 'client-secret',
      });

      final status = executor.requestsTo(HsEndpoints.outletStatus.id);
      expect(
        status.first.url,
        'https://sandbox.partner.deliveryhero.io/v2/chains/chain-1/vendors/vendor-1/status',
      );
      expect(status.last.url, endsWith('/vendors/other/status'));
      expect(status.first.headers['Authorization'], 'Bearer jwt-1');
      expect(status.first.endpoint.method, HttpMethod.get);
    },
  );

  test('renews the token shortly before it expires', () async {
    var issued = 0;
    final executor = FakeExecutor(
      (request) => request.endpoint == HsEndpoints.token
          ? tokenResponse('jwt-${++issued}')
          : const {},
    );
    final apis = await buildApis(executor, clock: clock);

    await apis.hungerStation.outletStatus();
    now = now.add(const Duration(minutes: 116));
    await apis.hungerStation.categories();

    expect(executor.requestsTo(HsEndpoints.token.id), hasLength(2));
    expect(
      executor
          .requestsTo(HsEndpoints.categories.id)
          .single
          .headers['Authorization'],
      'Bearer jwt-2',
    );
  });

  test('a 401 drops the token, fetches a new one and replays once', () async {
    var issued = 0;
    final executor = FakeExecutor((request) {
      if (request.endpoint == HsEndpoints.token) {
        return tokenResponse('jwt-${++issued}');
      }
      if (request.headers['Authorization'] == 'Bearer jwt-1') {
        throw const PlatformApiException(
          'Unauthorized',
          platform: DeliveryPlatform.hungerStation,
          kind: PlatformErrorKind.unauthorized,
          statusCode: 401,
        );
      }
      return {'job_id': 'job-1', 'job_status': 'QUEUED'};
    });
    final apis = await buildApis(executor, clock: clock);

    final job = await apis.hungerStation.updateProducts(
      products: const [HsProductUpdate(sku: 'A', price: 10.0)],
    );

    expect(job.id, 'job-1');
    expect(executor.requests.map((r) => r.endpoint.id), [
      HsEndpoints.token.id,
      HsEndpoints.updateProducts.id,
      HsEndpoints.token.id,
      HsEndpoints.updateProducts.id,
    ]);
    expect(executor.requests.last.params, {
      'products': [
        {'sku': 'A', 'price': 10},
      ],
    });
  });

  test('query params are stringified and nulls dropped', () async {
    final executor = FakeExecutor(
      (request) =>
          request.endpoint == HsEndpoints.token ? tokenResponse('t') : const {},
    );
    final apis = await buildApis(executor, clock: clock);

    await apis.hungerStation.products(
      query: 'Milk',
      categoryIds: ['a', 'b'],
      isActive: true,
      page: 1,
    );

    expect(executor.requestsTo(HsEndpoints.products.id).single.params, {
      'query_term': 'Milk',
      'category_global_ids': 'a,b',
      'is_active': 'true',
      'page': '1',
    });
  });

  test(
    'outlet status updates are validated and closed_until is UTC seconds',
    () async {
      final executor = FakeExecutor(
        (request) => request.endpoint == HsEndpoints.token
            ? tokenResponse('t')
            : const {},
      );
      final apis = await buildApis(executor, clock: clock);
      final hs = apis.hungerStation;

      expect(
        () => hs.updateOutletStatus(status: HsOutletStatus.closedToday),
        throwsArgumentError,
      );
      expect(
        () => hs.updateOutletStatus(
          status: HsOutletStatus.closedUntil,
          reason: HsClosedReason.other,
        ),
        throwsArgumentError,
      );
      expect(
        () => hs.updateOutletStatus(status: HsOutletStatus.closed),
        throwsArgumentError,
      );
      expect(executor.requests, isEmpty);

      await hs.updateOutletStatus(
        status: HsOutletStatus.closedUntil,
        reason: HsClosedReason.technicalProblem,
        closedUntil: DateTime.utc(2026, 9, 30, 10, 0, 36, 500),
      );
      final update = executor
          .requestsTo(HsEndpoints.updateOutletStatus.id)
          .single;
      expect(update.endpoint.method, HttpMethod.put);
      expect(update.params, {
        'status': 'CLOSED_UNTIL',
        'closed_reason': 'TECHNICAL_PROBLEM',
        'closed_until': '2026-09-30T10:00:36Z',
      });

      await hs.updateOutletStatus(status: HsOutletStatus.open);
      expect(
        executor.requestsTo(HsEndpoints.updateOutletStatus.id).last.params,
        {'status': 'OPEN'},
      );
    },
  );

  test('missing vendor is reported as notConfigured', () async {
    final executor = FakeExecutor((request) => tokenResponse('t'));
    final apis = await buildApis(
      executor,
      prefs: const {
        'platform.hs.client_id': 'c',
        'platform.hs.client_secret': 's',
        'platform.hs.chain_id': 'chain',
      },
      clock: clock,
    );

    await expectLater(
      apis.hungerStation.outletStatus(),
      throwsA(
        isA<PlatformApiException>().having(
          (e) => e.kind,
          'kind',
          PlatformErrorKind.notConfigured,
        ),
      ),
    );
    // Chain-level endpoints still work without a vendor.
    await apis.hungerStation.catalogJob('job-9');
    expect(
      executor.requestsTo(HsEndpoints.catalogJob.id).single.url,
      endsWith('/v2/chains/chain/catalog/jobs/job-9'),
    );
  });
}
