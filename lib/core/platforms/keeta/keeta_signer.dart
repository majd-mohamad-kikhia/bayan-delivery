import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../common/platform_endpoint.dart';
import '../common/platform_request.dart';
import '../config/platform_credentials.dart';
import 'keeta_endpoints.dart';

/// Keeta request signature (Authorization Guide §2):
///
///     sig = sha256_hex(url + "?" + k1=v1&k2=v2… + appSecret)
///
/// Keys sorted in ASCII order, `sig` excluded. Nested JSON values are
/// compact JSON in their original key order (no inner sorting); strings are
/// used as-is (no URL encoding).
abstract final class KeetaSigner {
  static String sign({
    required String url,
    required Map<String, Object?> params,
    required String appSecret,
  }) {
    final keys = params.keys.where((key) => key != 'sig').toList()..sort();
    final buffer = StringBuffer(url)..write('?');
    for (var i = 0; i < keys.length; i++) {
      if (i > 0) buffer.write('&');
      buffer
        ..write(keys[i])
        ..write('=')
        ..write(_valueString(params[keys[i]]));
    }
    buffer.write(appSecret);
    return sha256.convert(utf8.encode(buffer.toString())).toString();
  }

  /// Checks the `sig` of an incoming Keeta webhook delivered to [url].
  static bool verify({
    required String url,
    required Map<String, Object?> params,
    required String appSecret,
  }) {
    final received = params['sig'];
    if (received is! String || received.length != 64) return false;
    final expected = sign(url: url, params: params, appSecret: appSecret);
    var diff = 0;
    for (var i = 0; i < 64; i++) {
      diff |= expected.codeUnitAt(i) ^ received.codeUnitAt(i);
    }
    return diff == 0;
  }

  /// Adds the common parameters (`appId`, `accessToken` when given,
  /// `timestamp`) plus `sig` to [params] — which must already be normalized.
  static PlatformRequest signedRequest({
    required PlatformEndpoint endpoint,
    required KeetaCredentials credentials,
    required Map<String, Object?> params,
    required DateTime now,
    String? accessToken,
    String? device,
  }) {
    final url = '${KeetaEndpoints.baseUrl}${endpoint.path}';
    final body = <String, Object?>{
      ...params,
      'appId': credentials.appId,
      'accessToken': ?accessToken,
      'timestamp': now.millisecondsSinceEpoch ~/ 1000,
    };
    body['sig'] = sign(
      url: url,
      params: body,
      appSecret: credentials.appSecret,
    );
    return PlatformRequest(
      endpoint: endpoint,
      url: url,
      params: body,
      device: device,
    );
  }

  static String _valueString(Object? value) => switch (value) {
    null => '',
    String() => value,
    num() || bool() => value.toString(),
    _ => jsonEncode(value),
  };
}
