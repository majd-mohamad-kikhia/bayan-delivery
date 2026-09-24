import 'dart:async';

import 'package:bayan_desktop/core/network/api_exception.dart';
import 'package:bayan_desktop/core/platforms/common/http_method.dart';
import 'package:bayan_desktop/core/platforms/common/platform_api_exception.dart';
import 'package:bayan_desktop/core/platforms/common/platform_executor.dart';
import 'package:bayan_desktop/core/platforms/common/platform_request.dart';
import 'package:bayan_desktop/core/platforms/common/platform_utils.dart';
import 'package:bayan_desktop/core/platforms/hungerstation/hs_endpoints.dart';
import 'package:bayan_desktop/core/platforms/keeta/keeta_endpoints.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  group('catalogs', () {
    test('every endpoint has a unique id and a rooted path', () {
      final all = [...KeetaEndpoints.all, ...HsEndpoints.all];
      expect(all.map((e) => e.id).toSet(), hasLength(all.length));
      expect(all.every((e) => e.path.startsWith('/')), isTrue);
      expect(KeetaEndpoints.all, hasLength(50));
      expect(HsEndpoints.all, hasLength(11));
      expect(
        KeetaEndpoints.all.every((e) => e.method == HttpMethod.post),
        isTrue,
      );
    });

    test('resolvePath fills and encodes placeholders', () {
      expect(
        HsEndpoints.catalogJob.resolvePath({
          'chain_id': 'c 1',
          'job_id': 'j/2',
        }),
        '/v2/chains/c%201/catalog/jobs/j%2F2',
      );
      expect(KeetaEndpoints.confirmOrder.resolvePath(), '/order/confirm');
      expect(
        () => HsEndpoints.catalogJob.resolvePath({'chain_id': 'c'}),
        throwsArgumentError,
      );
    });
  });

  group('utils', () {
    test('normalizeParams drops top-level nulls and integral doubles', () {
      expect(
        normalizeParams({
          'a': null,
          'b': 10.0,
          'c': 1.5,
          'd': {'x': 2.0, 'y': null},
          'e': [3.0],
        }),
        {
          'b': 10,
          'c': 1.5,
          'd': {'x': 2, 'y': null},
          'e': [3],
        },
      );
    });

    test('SingleFlight shares one in-flight future per key', () async {
      final flight = SingleFlight<int>();
      var calls = 0;
      final completer = Completer<int>();
      Future<int> task() {
        calls++;
        return completer.future;
      }

      final a = flight.run('k', task);
      final b = flight.run('k', task);
      completer.complete(1);
      expect(await Future.wait([a, b]), [1, 1]);
      expect(calls, 1);

      await flight.run('k', () async => 2);
      expect(calls, 1, reason: 'a finished key starts a fresh task');
    });

    test('mapConcurrent keeps order and bounds concurrency', () async {
      var active = 0;
      var peak = 0;
      final result = await mapConcurrent([1, 2, 3, 4, 5, 6, 7], 3, (n) async {
        active++;
        peak = peak > active ? peak : active;
        await Future<void>.delayed(Duration(milliseconds: 8 - n));
        active--;
        return n * 10;
      });
      expect(result, [10, 20, 30, 40, 50, 60, 70]);
      expect(peak, 3);
    });

    test('chunked splits by size', () {
      expect(chunked([1, 2, 3, 4, 5], 2), [
        [1, 2],
        [3, 4],
        [5],
      ]);
    });
  });

  group('PlatformExecutor', () {
    const request = PlatformRequest(
      endpoint: HsEndpoints.outletStatus,
      url: 'https://x/v2/chains/c/vendors/v/status',
      params: {'a': '1'},
      headers: {'Authorization': 'Bearer t'},
    );

    Future<Object?> run(Map<String, dynamic> envelope, {FakeApiClient? api}) =>
        PlatformExecutor(
          api ?? FakeApiClient((_) => envelope),
          path: '/api/execute',
        ).execute(request);

    test(
      'sends the executeApiAndSendWebhook payload and returns result',
      () async {
        final api = FakeApiClient(
          (_) => {
            'success': true,
            'apiSuccess': true,
            'result': {'status': 'OPEN'},
          },
        );
        expect(await run(const {}, api: api), {'status': 'OPEN'});
        expect(api.lastPayload, {
          'platform': 'hungerstation',
          'method': 'GET',
          'path': 'https://x/v2/chains/c/vendors/v/status',
          'params': {'a': '1'},
          'headers': {'Authorization': 'Bearer t'},
          'timeoutMs': 10000,
        });
        expect(api.lastTimeout, const Duration(seconds: 15));
      },
    );

    test('a failed webhook forward does not fail the call', () async {
      expect(
        await run({
          'success': false,
          'apiSuccess': true,
          'webhookSuccess': false,
          'result': 1,
          'error': 'x',
        }),
        1,
      );
    });

    Future<PlatformApiException> failure(Map<String, dynamic> envelope) async {
      try {
        await run(envelope);
      } on PlatformApiException catch (e) {
        return e;
      }
      fail('expected PlatformApiException');
    }

    test('classifies platform HTTP errors', () async {
      final unauthorized = await failure({
        'apiSuccess': false,
        'error': 'API call failed (401): {"message":"Invalid token"}',
      });
      expect(unauthorized.kind, PlatformErrorKind.unauthorized);
      expect(unauthorized.statusCode, 401);
      expect(unauthorized.message, 'Invalid token');

      final server = await failure({
        'apiSuccess': false,
        'error': 'API call failed (503): "down"',
      });
      expect(server.kind, PlatformErrorKind.serverError);
      expect(server.isTransient, isTrue);

      final rejected = await failure({
        'apiSuccess': false,
        'error': 'API call failed (400): {"error":"bad"}',
      });
      expect(rejected.kind, PlatformErrorKind.rejected);
      expect(rejected.isTransient, isFalse);
    });

    test('classifies executor and transport errors', () async {
      final timeout = await failure({
        'apiSuccess': false,
        'error': 'Request to x timed out after 10000ms',
      });
      expect(timeout.kind, PlatformErrorKind.transport);

      final wrongRoute = await failure({'error': 'Not found'});
      expect(wrongRoute.kind, PlatformErrorKind.executor);

      final unreachable = FakeApiClient(
        (_) => throw const ApiException('Cannot reach the server.'),
      );
      await expectLater(
        run(const {}, api: unreachable),
        throwsA(
          isA<PlatformApiException>().having(
            (e) => e.kind,
            'kind',
            PlatformErrorKind.transport,
          ),
        ),
      );
    });
  });
}
