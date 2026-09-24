import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'platform_api_exception.dart';
import 'platform_endpoint.dart';
import 'platform_executor.dart';
import 'platform_request.dart';
import 'platform_utils.dart';

/// Call pipeline shared by every platform:
///
/// 1. identical in-flight reads are coalesced into one upstream request;
/// 2. the subclass builds and authenticates the request;
/// 3. the backend executor runs it;
/// 4. the subclass interprets the platform response;
/// 5. an auth failure renews credentials once and replays the call;
/// 6. reads are retried with backoff on transient failures. Writes never
///    are — replaying a cancel or a refund is not safe.
abstract class PlatformClient<R> {
  PlatformClient(this.executor, {this.maxReadRetries = 2});

  final PlatformExecutor executor;
  final int maxReadRetries;
  final SingleFlight<R> _reads = SingleFlight<R>();

  /// Calls [endpoint]. [params] is the JSON body (query string for GET);
  /// [pathParams] fills `{placeholders}` in the endpoint path; [device]
  /// overrides where the executor forwards the result.
  Future<R> send(
    PlatformEndpoint endpoint, {
    Map<String, Object?> params = const {},
    Map<String, String> pathParams = const {},
    String? device,
  }) {
    final body = normalizeParams(params);
    if (!endpoint.isRead || device != null) {
      return _run(endpoint, body, pathParams, device);
    }
    final key = '${endpoint.id}|${jsonEncode(pathParams)}|${jsonEncode(body)}';
    return _reads.run(key, () => _run(endpoint, body, pathParams, null));
  }

  Future<R> _run(
    PlatformEndpoint endpoint,
    Map<String, Object?> params,
    Map<String, String> pathParams,
    String? device,
  ) async {
    var attempt = 0;
    var reauthenticated = false;
    while (true) {
      PlatformRequest? request;
      try {
        request = await buildRequest(endpoint, params, pathParams, device);
        return interpret(endpoint, await executor.execute(request));
      } on PlatformApiException catch (e) {
        if (e.isAuthError &&
            request != null &&
            endpoint.requiresAuth &&
            !reauthenticated &&
            await reauthenticate(request)) {
          reauthenticated = true;
          continue;
        }
        if (endpoint.isRead && e.isTransient && attempt < maxReadRetries) {
          await Future<void>.delayed(backoffDelay(attempt++));
          continue;
        }
        rethrow;
      }
    }
  }

  /// Resolves URL, auth and signature for one attempt. Called again on
  /// every retry, so timestamps and tokens are always fresh.
  @protected
  Future<PlatformRequest> buildRequest(
    PlatformEndpoint endpoint,
    Map<String, Object?> params,
    Map<String, String> pathParams,
    String? device,
  );

  /// Turns the raw platform body into [R], throwing on platform-level errors.
  @protected
  R interpret(PlatformEndpoint endpoint, Object? raw);

  /// Called at most once per call after the platform rejected [failed]'s
  /// credentials. Returns true if the call should be replayed.
  @protected
  Future<bool> reauthenticate(PlatformRequest failed);
}
