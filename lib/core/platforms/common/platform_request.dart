import 'platform_endpoint.dart';

/// A fully-resolved upstream call — exactly the input of the backend's
/// `executeApiAndSendWebhook({ platform, path, method, params, headers,
/// device, timeoutMs })`.
final class PlatformRequest {
  const PlatformRequest({
    required this.endpoint,
    required this.url,
    this.params = const {},
    this.headers = const {},
    this.device,
  });

  final PlatformEndpoint endpoint;

  /// Absolute URL; the executor calls it as-is.
  final String url;

  /// JSON body, or the query string for GET.
  final Map<String, Object?> params;

  final Map<String, String> headers;

  /// Webhook URL or device id the executor forwards the result to.
  final String? device;

  Map<String, Object?> toExecutorPayload({String? device}) {
    final target = device ?? this.device;
    return {
      'platform': endpoint.platform.id,
      'method': endpoint.method.wire,
      'path': url,
      'params': params,
      if (headers.isNotEmpty) 'headers': headers,
      'device': ?target,
      'timeoutMs': endpoint.timeout.inMilliseconds,
    };
  }
}
