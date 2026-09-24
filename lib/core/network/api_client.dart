import 'package:dio/dio.dart';

import '../constants/app_constants.dart';
import 'api_exception.dart';

/// Thin wrapper around Dio so every feature repository shares one connection
/// pool and one error-translation path (DioException -> ApiException).
class ApiClient {
  ApiClient({Dio? dio}) : _dio = dio ?? _buildDio();

  final Dio _dio;

  static Dio _buildDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.apiBaseUrl,
        connectTimeout: AppConstants.requestTimeout,
        receiveTimeout: AppConstants.requestTimeout,
        sendTimeout: AppConstants.requestTimeout,
        headers: const {'Content-Type': 'application/json'},
      ),
    );
    dio.interceptors.add(_ApiLogInterceptor());
    return dio;
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(path, queryParameters: query);
      return response.data ?? const {};
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<Map<String, dynamic>> post(String path, {Object? data}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(path, data: data);
      return response.data ?? const {};
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<Map<String, dynamic>> put(String path, {Object? data}) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(path, data: data);
      return response.data ?? const {};
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// POSTs [data] and returns the decoded JSON body for **any** HTTP status,
  /// for endpoints that report failures inside the body (the platform
  /// executor envelope) — a 4xx/5xx still carries the details we need.
  Future<Map<String, dynamic>> postEnvelope(
    String path, {
    Object? data,
    Duration? timeout,
  }) async {
    try {
      final response = await _dio.post<Object?>(
        path,
        data: data,
        options: Options(
          sendTimeout: timeout,
          receiveTimeout: timeout,
          validateStatus: (_) => true,
        ),
      );
      final body = response.data;
      if (body is Map<String, dynamic>) return body;
      throw ApiException(
        'Unexpected response from $path (HTTP ${response.statusCode})',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

class _ApiLogInterceptor extends Interceptor {
  static const _yellow = '\x1B[33m';
  static const _red = '\x1B[31m';
  static const _reset = '\x1B[0m';

  bool _isStatusEdit(RequestOptions options) =>
      options.uri.path.contains('/actions/');

  bool _looksLikeError(Object? data) => data is Map && data.containsKey('error');

  void _log({
    required String link,
    required Object? body,
    required Object? responseData,
    bool isError = false,
  }) {
    final color = (isError || _looksLikeError(responseData)) ? _red : _yellow;
    print(
      'link : $link\n'
      'body : $body\n'
      '$color'
      'response : $responseData'
      '$_reset',
    );
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    final options = response.requestOptions;
    if (_isStatusEdit(options)) {
      _log(
        link: options.uri.toString(),
        body: options.data,
        responseData: response.data,
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final options = err.requestOptions;
    if (_isStatusEdit(options)) {
      _log(
        link: options.uri.toString(),
        body: options.data,
        responseData: err.response?.data ?? err.message,
        isError: true,
      );
    }
    handler.next(err);
  }
}
