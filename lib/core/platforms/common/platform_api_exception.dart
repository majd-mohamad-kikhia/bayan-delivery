import '../../network/api_exception.dart';
import 'delivery_platform.dart';

enum PlatformErrorKind {
  /// Credentials or tokens are missing — needs setup, retrying won't help.
  notConfigured,

  /// The backend executor or the platform could not be reached / timed out.
  transport,

  /// The executor rejected the call or answered in an unexpected shape.
  executor,

  /// The platform rejected the credentials (HTTP 401, Keeta 1150001xx).
  unauthorized,

  /// The platform throttled the call (HTTP 429).
  rateLimited,

  /// The platform failed internally (HTTP 5xx, Keeta 3150001xx).
  serverError,

  /// The platform refused the request (HTTP 4xx, Keeta business errors).
  rejected,
}

/// Error from a direct platform call.
///
/// Extends [ApiException] so existing `catch` / `.message` handling in blocs
/// works unchanged. [statusCode] is the platform's HTTP status when known.
class PlatformApiException extends ApiException {
  const PlatformApiException(
    super.message, {
    required this.platform,
    required this.kind,
    super.statusCode,
    this.endpointId,
    this.code,
    this.details,
  });

  final DeliveryPlatform platform;
  final PlatformErrorKind kind;

  /// The endpoint that failed, e.g. `keeta.order.confirm`.
  final String? endpointId;

  /// Platform business error code (Keeta `code`), when one was returned.
  final int? code;

  /// Decoded platform error body, if any.
  final Object? details;

  bool get isAuthError => kind == PlatformErrorKind.unauthorized;

  /// Worth retrying for side-effect-free calls.
  bool get isTransient =>
      kind == PlatformErrorKind.transport ||
      kind == PlatformErrorKind.rateLimited ||
      kind == PlatformErrorKind.serverError;
}
