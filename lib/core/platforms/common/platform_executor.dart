import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../../constants/app_constants.dart';
import '../../network/api_client.dart';
import '../../network/api_exception.dart';
import 'platform_api_exception.dart';
import 'platform_endpoint.dart';
import 'platform_request.dart';

/// Runs resolved platform calls through the backend's
/// `executeApiAndSendWebhook`, which performs the real HTTP request.
///
/// The backend answers with
/// `{ success, apiSuccess, webhookSuccess, platform, result, error }`.
/// Only `apiSuccess` decides the outcome: a failed webhook forward is
/// logged, never thrown, because the platform call itself already happened.
///
/// Shares [ApiClient]'s Dio instance, so every call reuses the same
/// keep-alive connection pool to the backend.
class PlatformExecutor {
  PlatformExecutor(
    this._api, {
    String path = AppConstants.platformExecutorPath,
    String? defaultDevice,
  }) : _path = path,
       _defaultDevice =
           defaultDevice ??
           (AppConstants.platformWebhookDevice.isEmpty
               ? null
               : AppConstants.platformWebhookDevice);

  final ApiClient _api;
  final String _path;
  final String? _defaultDevice;

  /// Headroom over the platform timeout for the hop to the executor.
  static const Duration _hopMargin = Duration(seconds: 5);

  /// `"API call failed (401): {...}"` — how the executor reports non-2xx.
  static final RegExp _platformFailure = RegExp(
    r'^API call failed \((\d{3})\): ([\s\S]*)$',
  );

  Future<Object?> execute(PlatformRequest request) async {
    final endpoint = request.endpoint;
    final device = request.device ?? _defaultDevice;

    var timeout = endpoint.timeout + _hopMargin;
    if (device != null) {
      // The executor forwards to the device before it answers: up to 4
      // attempts of `timeoutMs` each, with 0.5s + 1s + 2s backoff between.
      timeout += endpoint.timeout * 4 + const Duration(milliseconds: 3500);
    }

    final Map<String, dynamic> envelope;
    try {
      envelope = await _api.postEnvelope(
        _path,
        data: request.toExecutorPayload(device: device),
        timeout: timeout,
      );
    } on ApiException catch (e) {
      throw PlatformApiException(
        e.message,
        platform: endpoint.platform,
        kind: e.statusCode == null
            ? PlatformErrorKind.transport
            : PlatformErrorKind.executor,
        statusCode: e.statusCode,
        endpointId: endpoint.id,
      );
    }
    return unwrap(envelope, endpoint);
  }

  /// Returns the platform response body, or throws a classified
  /// [PlatformApiException].
  @visibleForTesting
  static Object? unwrap(
    Map<String, dynamic> envelope,
    PlatformEndpoint endpoint,
  ) {
    final apiSuccess = envelope['apiSuccess'];
    if (apiSuccess == true) {
      if (envelope['webhookSuccess'] == false) {
        developer.log(
          '${endpoint.id}: webhook forward failed — ${envelope['error']}',
          name: 'PlatformExecutor',
        );
      }
      return envelope['result'];
    }

    final error = envelope['error']?.toString() ?? 'Platform call failed';
    PlatformApiException failure(
      String message,
      PlatformErrorKind kind, {
      int? status,
      Object? details,
    }) => PlatformApiException(
      message,
      platform: endpoint.platform,
      kind: kind,
      statusCode: status,
      endpointId: endpoint.id,
      details: details,
    );

    // Not an executeApiAndSendWebhook envelope: wrong route or a backend crash.
    if (apiSuccess != false) throw failure(error, PlatformErrorKind.executor);

    final match = _platformFailure.firstMatch(error);
    if (match == null) {
      // fetch() failure or the executor's own timeout on the platform call.
      final kind = error.startsWith('"path"')
          ? PlatformErrorKind.executor
          : PlatformErrorKind.transport;
      throw failure(error, kind);
    }

    final status = int.parse(match.group(1)!);
    final details = _tryDecode(match.group(2)!);
    throw failure(
      _messageOf(details) ?? 'HTTP $status from ${endpoint.platform.label}',
      switch (status) {
        401 => PlatformErrorKind.unauthorized,
        429 => PlatformErrorKind.rateLimited,
        >= 500 => PlatformErrorKind.serverError,
        _ => PlatformErrorKind.rejected,
      },
      status: status,
      details: details,
    );
  }

  static Object? _tryDecode(String text) {
    try {
      return jsonDecode(text);
    } on FormatException {
      return text;
    }
  }

  static String? _messageOf(Object? details) {
    if (details is Map) {
      for (final key in const [
        'message',
        'error_description',
        'detail',
        'title',
        'error',
      ]) {
        final value = details[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
    } else if (details is String) {
      final text = details.trim();
      if (text.isNotEmpty && text.length <= 300) return text;
    }
    return null;
  }
}
