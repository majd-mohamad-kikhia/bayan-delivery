import 'package:dio/dio.dart';

import '../errors/app_error_kind.dart';

/// Normalized error shape for the whole app — repositories throw this.
/// [message] is readable English for logs and technical details; the UI
/// shows friendly localized text chosen from [errorKind].
class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode,
    this.errorKind = AppErrorKind.unknown,
    this.endpoint,
  });

  final String message;
  final int? statusCode;
  final AppErrorKind errorKind;

  /// `METHOD url` of the failed request, when known.
  final String? endpoint;

  factory ApiException.fromDioException(DioException e) {
    final endpoint = '${e.requestOptions.method} ${e.requestOptions.uri}';
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(
          'Connection timed out. Is the backend running?',
          errorKind: AppErrorKind.timeout,
          endpoint: endpoint,
        );
      case DioExceptionType.connectionError:
        return ApiException(
          'Cannot reach the server. Check the backend is running and the API URL is correct.',
          errorKind: AppErrorKind.offline,
          endpoint: endpoint,
        );
      default:
        break;
    }

    final status = e.response?.statusCode;
    final data = e.response?.data;
    final serverMessage = data is Map ? data['error']?.toString() : null;
    return ApiException(
      serverMessage ?? e.message ?? 'Unexpected network error',
      statusCode: status,
      errorKind: _kindForStatus(status),
      endpoint: endpoint,
    );
  }

  static AppErrorKind _kindForStatus(int? status) => switch (status) {
        null => AppErrorKind.unknown,
        401 || 403 => AppErrorKind.unauthorized,
        429 => AppErrorKind.rateLimited,
        >= 500 => AppErrorKind.server,
        >= 400 => AppErrorKind.rejected,
        _ => AppErrorKind.unknown,
      };

  @override
  String toString() => message;
}
