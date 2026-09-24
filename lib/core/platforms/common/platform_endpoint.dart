import 'delivery_platform.dart';
import 'http_method.dart';

/// One upstream operation, declared once as a compile-time constant.
///
/// The catalogs (`KeetaEndpoints`, `HsEndpoints`) are nothing but `const`
/// instances of this class, so declaring every API costs no allocation and
/// no startup time — an endpoint only does work when it is called.
class PlatformEndpoint {
  const PlatformEndpoint(
    this.id, {
    required this.platform,
    required this.method,
    required this.path,
    this.isRead = false,
    this.requiresAuth = true,
    this.maxBatchSize,
    this.timeout = defaultTimeout,
  });

  /// Upstream timeout the executor enforces (matches its own default).
  static const Duration defaultTimeout = Duration(seconds: 10);

  /// Stable name used in logs and errors, e.g. `keeta.order.confirm`.
  final String id;
  final DeliveryPlatform platform;
  final HttpMethod method;

  /// Relative to the platform base URL. May contain `{name}` placeholders.
  final String path;

  /// No side effects upstream: identical concurrent calls are coalesced
  /// into one request and transient failures are retried.
  final bool isRead;

  /// Needs a platform access token (false only for token endpoints).
  final bool requiresAuth;

  /// Largest list the platform accepts per call; batch helpers chunk above it.
  final int? maxBatchSize;

  final Duration timeout;

  /// Fills `{name}` placeholders from [params], URI-encoded. Single pass with
  /// no RegExp; paths without placeholders are returned as-is.
  String resolvePath([Map<String, String> params = const {}]) {
    var start = path.indexOf('{');
    if (start < 0) return path;

    final out = StringBuffer();
    var cursor = 0;
    while (start >= 0) {
      final end = path.indexOf('}', start);
      if (end < 0) break;
      final name = path.substring(start + 1, end);
      final value = params[name];
      if (value == null || value.isEmpty) {
        throw ArgumentError.value(params, 'params', 'Missing "$name" for $id');
      }
      out
        ..write(path.substring(cursor, start))
        ..write(Uri.encodeComponent(value));
      cursor = end + 1;
      start = path.indexOf('{', cursor);
    }
    out.write(path.substring(cursor));
    return out.toString();
  }

  @override
  String toString() => '$id (${method.wire} $path)';
}
