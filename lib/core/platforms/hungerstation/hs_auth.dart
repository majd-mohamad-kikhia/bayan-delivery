import '../auth/auth_token.dart';
import '../auth/token_store.dart';
import '../common/delivery_platform.dart';
import '../common/platform_api_exception.dart';
import '../common/platform_executor.dart';
import '../common/platform_request.dart';
import '../common/platform_utils.dart';
import '../config/platform_credentials.dart';
import '../config/platform_credentials_store.dart';
import 'hs_endpoints.dart';

/// OAuth 2.0 client-credentials token for HungerStation.
///
/// The ~2h JWT is cached in memory and on disk and renewed
/// [refreshWindow] before expiry. Concurrent callers share one token
/// request, which matters with a 50 requests/min limit on the endpoint.
///
/// The token request is form-encoded: the executor must send `params` as
/// `application/x-www-form-urlencoded` when that Content-Type is set.
class HsAuth {
  HsAuth({
    required PlatformExecutor executor,
    required PlatformCredentialsStore credentials,
    required TokenStore tokens,
    Clock? clock,
  }) : _executor = executor,
       _credentials = credentials,
       _tokens = tokens,
       _clock = clock ?? DateTime.now;

  static const Duration refreshWindow = Duration(minutes: 5);
  static const int _maxAttempts = 3;

  final PlatformExecutor _executor;
  final PlatformCredentialsStore _credentials;
  final TokenStore _tokens;
  final Clock _clock;
  final SingleFlight<AuthToken> _fetches = SingleFlight<AuthToken>();

  Future<String> accessToken() async {
    final credentials = _credentials.requireHungerStation();
    final key = _key(credentials);
    final cached = _tokens.read(key);
    if (cached != null && !cached.expiresWithin(refreshWindow, _clock())) {
      return cached.accessToken;
    }
    return (await _fetches.run(
      key,
      () => _fetch(credentials, key),
    )).accessToken;
  }

  /// Drops [failedToken] after a 401 so the next call fetches a new one.
  /// A token already replaced by a concurrent caller is left alone.
  Future<void> invalidate(String? failedToken) async {
    final credentials = _credentials.hungerStation;
    if (!credentials.isComplete) return;
    final key = _key(credentials);
    if (_tokens.read(key)?.accessToken == failedToken) {
      await _tokens.delete(key);
    }
  }

  String _key(HungerStationCredentials credentials) =>
      'hungerstation.${credentials.environment.name}.${credentials.clientId}';

  Future<AuthToken> _fetch(
    HungerStationCredentials credentials,
    String key,
  ) async {
    final request = PlatformRequest(
      endpoint: HsEndpoints.token,
      url: '${credentials.environment.baseUrl}${HsEndpoints.token.path}',
      params: {
        'grant_type': 'client_credentials',
        'client_id': credentials.clientId,
        'client_secret': credentials.clientSecret,
      },
      headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
    );

    for (var attempt = 0; ; attempt++) {
      try {
        final token = _parse(await _executor.execute(request));
        await _tokens.write(key, token);
        return token;
      } on PlatformApiException catch (e) {
        if (!e.isTransient || attempt + 1 >= _maxAttempts) rethrow;
        await Future<void>.delayed(backoffDelay(attempt));
      }
    }
  }

  AuthToken _parse(Object? raw) {
    final body = raw is Map ? raw : const {};
    final accessToken = body['access_token'];
    if (accessToken is! String || accessToken.isEmpty) {
      throw PlatformApiException(
        'HungerStation returned no access_token',
        platform: DeliveryPlatform.hungerStation,
        kind: PlatformErrorKind.executor,
        endpointId: HsEndpoints.token.id,
        details: raw,
      );
    }
    final now = _clock();
    final expiresIn = body['expires_in'];
    return AuthToken(
      accessToken: accessToken,
      obtainedAt: now,
      expiresAt: now.add(
        Duration(seconds: expiresIn is num ? expiresIn.toInt() : 3600),
      ),
    );
  }
}
