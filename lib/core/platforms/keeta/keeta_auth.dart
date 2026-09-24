import 'dart:async';

import '../auth/auth_token.dart';
import '../auth/token_store.dart';
import '../common/delivery_platform.dart';
import '../common/platform_api_exception.dart';
import '../common/platform_executor.dart';
import '../common/platform_utils.dart';
import '../config/platform_credentials.dart';
import '../config/platform_credentials_store.dart';
import 'keeta_endpoints.dart';
import 'keeta_response.dart';
import 'keeta_signer.dart';

/// Owns the merchant `accessToken`:
/// - served from memory → disk → `KEETA_ACCESS_TOKEN` seed;
/// - refreshed [refreshWindow] before its 90-day expiry — the access and
///   refresh tokens expire together, so refreshing late is unrecoverable;
/// - the refresh token is single use: the new pair is persisted before it
///   is handed out, and concurrent callers share one refresh;
/// - refresh transport failures are retried (Keeta asks for 3–5 attempts).
class KeetaAuth {
  KeetaAuth({
    required PlatformExecutor executor,
    required PlatformCredentialsStore credentials,
    required TokenStore tokens,
    Clock? clock,
  }) : _executor = executor,
       _credentials = credentials,
       _tokens = tokens,
       _clock = clock ?? DateTime.now;

  static const Duration refreshWindow = Duration(days: 7);

  /// After a failed proactive refresh, keep using the still-valid token for
  /// this long before trying again, instead of slowing down every call.
  static const Duration _proactiveRetryPause = Duration(minutes: 5);

  /// A token younger than this that Keeta rejects isn't an expiry problem
  /// (likely a signature bug) — don't burn refresh tokens on it.
  static const Duration _minRecoverAge = Duration(minutes: 10);

  static const int _refreshAttempts = 4;

  final PlatformExecutor _executor;
  final PlatformCredentialsStore _credentials;
  final TokenStore _tokens;
  final Clock _clock;
  final SingleFlight<AuthToken> _refresh = SingleFlight<AuthToken>();
  DateTime? _proactiveFailedAt;

  /// The token requests will use, or null if Keeta isn't authorized yet.
  AuthToken? get currentToken {
    final credentials = _credentials.keeta;
    return credentials.isComplete ? _load(credentials) : null;
  }

  Future<String> accessToken() async {
    final credentials = _credentials.requireKeeta();
    final token = _load(credentials);
    if (token == null) {
      throw const PlatformApiException(
        'Keeta is not authorized — exchange an authorization code or set KEETA_ACCESS_TOKEN.',
        platform: DeliveryPlatform.keeta,
        kind: PlatformErrorKind.notConfigured,
      );
    }

    final now = _clock();
    final pausedUntil = _proactiveFailedAt?.add(_proactiveRetryPause);
    final paused =
        pausedUntil != null &&
        now.isBefore(pausedUntil) &&
        !token.isExpired(now);
    if (token.refreshToken != null &&
        token.expiresWithin(refreshWindow, now) &&
        !paused) {
      try {
        final refreshed = await refresh();
        _proactiveFailedAt = null;
        return refreshed.accessToken;
      } on PlatformApiException {
        if (token.isExpired(_clock())) rethrow;
        _proactiveFailedAt = _clock();
      }
    }
    return token.accessToken;
  }

  /// Exchanges the code from Server Callback / Standard OAuth mode and
  /// stores the resulting token pair.
  Future<AuthToken> exchangeAuthorizationCode(String code) => _grant(
    _credentials.requireKeeta(),
    {'grantType': 'authorization_code', 'code': code},
    attempts: 1,
  );

  Future<AuthToken> refresh() => _refresh.run('refresh', () {
    final credentials = _credentials.requireKeeta();
    final refreshToken = _load(credentials)?.refreshToken;
    if (refreshToken == null) {
      throw const PlatformApiException(
        'No Keeta refresh token — re-authorize the merchant.',
        platform: DeliveryPlatform.keeta,
        kind: PlatformErrorKind.notConfigured,
      );
    }
    return _grant(credentials, {
      'grantType': 'refresh_token',
      'refreshToken': refreshToken,
    }, attempts: _refreshAttempts);
  });

  /// Stores a token obtained elsewhere (e.g. pasted from the dashboard).
  Future<void> adoptToken(AuthToken token) =>
      _save(_credentials.requireKeeta(), token);

  Future<void> clear() => _tokens.delete(_key(_credentials.keeta));

  /// Called after Keeta rejected [failedAccessToken]. Returns true when the
  /// call should be replayed with a newer token.
  Future<bool> recover(String? failedAccessToken) async {
    final current = currentToken;
    if (current == null) return false;
    if (current.accessToken != failedAccessToken) return true;

    final obtainedAt = current.obtainedAt;
    final tooFresh =
        obtainedAt != null && _clock().difference(obtainedAt) < _minRecoverAge;
    if (current.refreshToken == null || tooFresh) return false;
    try {
      await refresh();
      return true;
    } on PlatformApiException {
      return false;
    }
  }

  Future<AuthToken> _grant(
    KeetaCredentials credentials,
    Map<String, Object?> grant, {
    required int attempts,
  }) async {
    for (var attempt = 0; ; attempt++) {
      final request = KeetaSigner.signedRequest(
        endpoint: KeetaEndpoints.oauthToken,
        credentials: credentials,
        params: grant,
        now: _clock(),
      );
      try {
        final token = _parseToken(await _executor.execute(request));
        await _save(credentials, token);
        return token;
      } on PlatformApiException catch (e) {
        if (!e.isTransient || attempt + 1 >= attempts) rethrow;
        await Future<void>.delayed(backoffDelay(attempt));
      }
    }
  }

  AuthToken _parseToken(Object? raw) {
    var body = raw is Map ? raw : null;
    // The token endpoint answers flat; tolerate the standard envelope too.
    if (body != null && body['accessToken'] == null) {
      final data = KeetaResponse.fromRaw(body, KeetaEndpoints.oauthToken).data;
      body = data is Map ? data : null;
    }

    final accessToken = body?['accessToken'];
    if (accessToken is! String || accessToken.isEmpty) {
      throw PlatformApiException(
        'Keeta returned no accessToken',
        platform: DeliveryPlatform.keeta,
        kind: PlatformErrorKind.executor,
        endpointId: KeetaEndpoints.oauthToken.id,
        details: raw,
      );
    }

    final now = _clock();
    final expiresIn = body!['expiresIn'];
    return AuthToken(
      accessToken: accessToken,
      refreshToken: body['refreshToken']?.toString(),
      obtainedAt: now,
      expiresAt: expiresIn is num
          ? now.add(Duration(seconds: expiresIn.toInt()))
          : null,
    );
  }

  String _key(KeetaCredentials credentials) => 'keeta.${credentials.appId}';

  AuthToken? _load(KeetaCredentials credentials) {
    final key = _key(credentials);
    final stored = _tokens.read(key);
    final seed = _credentials.keetaSeedToken;
    if (seed == null) return stored;

    final origin = _credentials.keetaSeedFingerprint;
    if (stored != null && stored.origin == origin) return stored;

    // A different KEETA_ACCESS_TOKEN was configured since the stored chain
    // began: the newly configured token wins.
    final adopted = seed.withOrigin(origin);
    unawaited(_tokens.write(key, adopted));
    return adopted;
  }

  Future<void> _save(KeetaCredentials credentials, AuthToken token) =>
      _tokens.write(
        _key(credentials),
        token.withOrigin(_credentials.keetaSeedFingerprint),
      );
}
