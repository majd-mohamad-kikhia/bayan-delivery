import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'auth_token.dart';

/// Persists tokens so an app restart reuses them instead of paying for an
/// extra token round-trip (HungerStation) or losing a single-use refresh
/// token (Keeta). After the first read of a key it is served from memory.
class TokenStore {
  TokenStore(this._prefs);

  static const _prefix = 'platform_token.';

  final SharedPreferences _prefs;
  final Map<String, AuthToken?> _cache = {};

  AuthToken? read(String key) {
    if (_cache.containsKey(key)) return _cache[key];

    AuthToken? token;
    final raw = _prefs.getString('$_prefix$key');
    if (raw != null) {
      try {
        token = AuthToken.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        // Corrupt entry — treat as absent; the next write replaces it.
      }
    }
    return _cache[key] = token;
  }

  /// Updates memory synchronously, then persists.
  Future<void> write(String key, AuthToken token) {
    _cache[key] = token;
    return _prefs.setString('$_prefix$key', jsonEncode(token.toJson()));
  }

  Future<void> delete(String key) {
    _cache[key] = null;
    return _prefs.remove('$_prefix$key');
  }
}
