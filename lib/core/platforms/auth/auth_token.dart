/// An OAuth access token plus what's needed to know when to renew it.
final class AuthToken {
  const AuthToken({
    required this.accessToken,
    this.refreshToken,
    this.expiresAt,
    this.obtainedAt,
    this.origin,
  });

  factory AuthToken.fromJson(Map<String, dynamic> json) {
    DateTime? time(Object? millis) => millis is num
        ? DateTime.fromMillisecondsSinceEpoch(millis.toInt(), isUtc: true)
        : null;
    return AuthToken(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String?,
      expiresAt: time(json['expiresAt']),
      obtainedAt: time(json['obtainedAt']),
      origin: json['origin'] as String?,
    );
  }

  final String accessToken;

  /// Keeta only. Single use: every refresh returns a new one.
  final String? refreshToken;

  /// Null when unknown (e.g. a token copied from the Keeta dashboard).
  final DateTime? expiresAt;

  final DateTime? obtainedAt;

  /// Fingerprint of the configured seed token this token chain supersedes.
  /// Lets a newly configured seed win over an older stored chain.
  final String? origin;

  bool isExpired(DateTime now) {
    final expiry = expiresAt;
    return expiry != null && !now.isBefore(expiry);
  }

  /// True once [now] is within [window] of expiry. Renew here instead of
  /// waiting for a 401.
  bool expiresWithin(Duration window, DateTime now) {
    final expiry = expiresAt;
    return expiry != null && !now.add(window).isBefore(expiry);
  }

  AuthToken withOrigin(String? origin) => AuthToken(
    accessToken: accessToken,
    refreshToken: refreshToken,
    expiresAt: expiresAt,
    obtainedAt: obtainedAt,
    origin: origin,
  );

  Map<String, Object?> toJson() => {
    'accessToken': accessToken,
    if (refreshToken != null) 'refreshToken': refreshToken,
    if (expiresAt != null) 'expiresAt': expiresAt!.millisecondsSinceEpoch,
    if (obtainedAt != null) 'obtainedAt': obtainedAt!.millisecondsSinceEpoch,
    if (origin != null) 'origin': origin,
  };
}
