import 'package:dio/dio.dart';

import '../constants/app_constants.dart';
import 'api_exception.dart';

/// Dedicated Dio client for the Bayan Accounting & Warehouses local ERP API.
///
/// Targets [AppConstants.bayanErpBaseUrl] (default: `http://127.0.0.1:3003`).
/// All endpoints return either a JSON array or a single JSON object; both are
/// normalised to `List<Map<String, dynamic>>` by [getList].
class BayanErpClient {
  BayanErpClient({Dio? dio}) : _dio = dio ?? _buildDio();

  /// Every endpoint is a read-only GET, so repeating one after a timeout or a
  /// dropped connection is safe.
  static const int _maxAttempts = 2;

  final Dio _dio;

  static Dio _buildDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.bayanErpBaseUrl,
        connectTimeout: AppConstants.erpConnectTimeout,
        receiveTimeout: AppConstants.erpReceiveTimeout,
      ),
    );
    dio.interceptors.add(_ErpLogInterceptor());
    return dio;
  }

  /// Issues a GET request and returns a guaranteed non-null list of maps.
  ///
  /// Handles three response shapes:
  ///   - `[{...}, ...]` → returned as-is
  ///   - `{...}`        → wrapped in a single-element list
  ///   - anything else  → empty list (no throw)
  Future<List<Map<String, dynamic>>> getList(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    for (var attempt = 1; ; attempt++) {
      try {
        final response = await _dio.get<Object?>(path, queryParameters: query);
        final body = response.data;
        if (body is List) return body.cast<Map<String, dynamic>>();
        if (body is Map<String, dynamic>) return [body];
        return const [];
      } on DioException catch (e) {
        if (attempt >= _maxAttempts || !_isTransient(e)) {
          throw ApiException.fromDioException(e);
        }
      }
    }
  }

  static bool _isTransient(DioException e) => switch (e.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.connectionError =>
          true,
        _ => false,
      };
}

// ─── Private log interceptor ─────────────────────────────────────────────────

class _ErpLogInterceptor extends Interceptor {
  static const _cyan = '\x1B[36m';
  static const _red = '\x1B[31m';
  static const _reset = '\x1B[0m';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    print('$_cyan[ERP] ▶ ${options.method} ${options.uri}$_reset');
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    final data = response.data;
    final count = data is List ? '${data.length} items' : 'object';
    print('$_cyan[ERP] ✓ ${response.statusCode} — $count$_reset');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    print('$_red[ERP] ✗ ${err.requestOptions.uri} — ${err.type.name}: ${err.message}$_reset');
    handler.next(err);
  }
}
