import 'dart:async';
import 'dart:io';

import 'package:bayan_desktop/core/errors/app_error.dart';
import 'package:bayan_desktop/core/network/api_exception.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _dio(DioExceptionType type, {int? status}) {
  final options = RequestOptions(path: 'https://api.example.com/orders', method: 'GET');
  return DioException(
    requestOptions: options,
    type: type,
    response: status == null ? null : Response(requestOptions: options, statusCode: status),
  );
}

void main() {
  group('AppError.from', () {
    test('classifies Dio failures by transport and HTTP status', () {
      AppErrorKind kindOf(DioException e) =>
          AppError.from(ApiException.fromDioException(e)).kind;

      expect(kindOf(_dio(DioExceptionType.connectionError)), AppErrorKind.offline);
      expect(kindOf(_dio(DioExceptionType.receiveTimeout)), AppErrorKind.timeout);
      expect(kindOf(_dio(DioExceptionType.badResponse, status: 401)), AppErrorKind.unauthorized);
      expect(kindOf(_dio(DioExceptionType.badResponse, status: 429)), AppErrorKind.rateLimited);
      expect(kindOf(_dio(DioExceptionType.badResponse, status: 503)), AppErrorKind.server);
      expect(kindOf(_dio(DioExceptionType.badResponse, status: 422)), AppErrorKind.rejected);
    });

    test('keeps the status and endpoint in the technical detail', () {
      final error = AppError.from(
        ApiException.fromDioException(_dio(DioExceptionType.badResponse, status: 503)),
      );
      expect(error.detail, contains('HTTP 503'));
      expect(error.detail, contains('GET https://api.example.com/orders'));
    });

    test('maps plain Dart exceptions', () {
      expect(AppError.from(TimeoutException('slow')).kind, AppErrorKind.timeout);
      expect(AppError.from(const SocketException('down')).kind, AppErrorKind.offline);
      expect(AppError.from(StateError('boom')).kind, AppErrorKind.unknown);
    });

    test('passes an existing AppError through unchanged', () {
      const error = AppError(AppErrorKind.server, detail: 'x');
      expect(AppError.from(error), same(error));
    });
  });
}
