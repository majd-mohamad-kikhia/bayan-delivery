import 'package:dio/dio.dart';

/// Normalized error shape for the whole app — repositories throw this,
/// UI code only ever needs to read `.message`.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  factory ApiException.fromDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException('Connection timed out. Is the backend running?');
      case DioExceptionType.connectionError:
        return const ApiException(
          'Cannot reach the server. Check the backend is running and the API URL is correct.',
        );
      default:
        break;
    }

    final data = e.response?.data;
    final serverMessage = data is Map ? data['error']?.toString() : null;
    return ApiException(
      serverMessage ?? e.message ?? 'Unexpected network error',
      statusCode: e.response?.statusCode,
    );
  }

  @override
  String toString() => message;
}
