import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'device_message.dart';

enum DevicePollStatus {
  /// Not started, or stopped.
  stopped,

  /// First request in flight — nothing heard from the server yet.
  connecting,

  /// Last poll succeeded (200 or 204): pushes arrive as soon as queued.
  live,

  /// Last poll failed; retrying with backoff.
  reconnecting,

  /// The server answered 404 — wrong base URL or route.
  misconfigured,
}

/// Receives what the backend queues for this device by long-polling
/// `GET {baseUrl}/poll/{deviceId}?timeout=…` (the device has no open port,
/// so the server can't push to it).
///
/// - Re-polls immediately after every 200/204 on the same keep-alive
///   socket, so a push lands as soon as the server has it and a queued
///   backlog drains back-to-back with no handshake per cycle.
/// - Own Dio instance: nothing on the hot path but the request itself, and
///   a receive timeout sized to the server hold ([pollTimeout] + 5s).
/// - [stop] and [switchDevice] abort the held request instantly.
/// - Failures back off exponentially with jitter ([minBackoff] →
///   [maxBackoff]) and reset on the first success; a server that answers
///   204 without holding can't turn this into a hot loop.
/// - Redeliveries (Keeta retries a webhook up to 3×) are dropped by message
///   id; messages that arrive before anyone listens are buffered.
class DevicePoller {
  DevicePoller({
    required this.baseUrl,
    required String deviceId,
    this.pollTimeout = const Duration(seconds: 25),
    this.minBackoff = const Duration(seconds: 1),
    this.maxBackoff = const Duration(seconds: 15),
    Dio? dio,
    math.Random? random,
  })  : assert(pollTimeout <= const Duration(seconds: 60), 'the server caps the hold at 60s'),
        _deviceId = deviceId,
        _dio = dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 8))),
        _random = random ?? math.Random() {
    _options = Options(
      receiveTimeout: pollTimeout + const Duration(seconds: 5),
      validateStatus: (_) => true,
    );
    _messages = StreamController<DeviceMessage>.broadcast(onListen: _flushBuffer);
  }

  final String baseUrl;

  /// How long the server may hold each poll open waiting for data.
  final Duration pollTimeout;
  final Duration minBackoff;
  final Duration maxBackoff;

  final Dio _dio;
  final math.Random _random;
  late final Options _options;
  late final StreamController<DeviceMessage> _messages;
  final ValueNotifier<DevicePollStatus> _status = ValueNotifier(DevicePollStatus.stopped);

  static const int _seenCapacity = 512;
  static const int _bufferCapacity = 200;

  /// A 204 faster than this means the server isn't holding the request.
  static const Duration _minHold = Duration(milliseconds: 500);

  final LinkedHashSet<String> _seen = LinkedHashSet();
  final List<DeviceMessage> _buffer = [];

  String _deviceId;
  String? _url;
  int _generation = 0;
  bool _running = false;
  CancelToken? _cancelToken;
  void Function()? _wake;
  Object? _lastError;

  /// Every payload queued for this device, in arrival order.
  Stream<DeviceMessage> get messages => _messages.stream;

  /// Drives a "live / reconnecting" indicator; notifies only on change.
  ValueListenable<DevicePollStatus> get status => _status;

  Object? get lastError => _lastError;
  String get deviceId => _deviceId;
  bool get isRunning => _running;

  void start() {
    if (_running) return;
    _running = true;
    _restart();
  }

  void stop() {
    if (!_running) return;
    _running = false;
    _interrupt();
    _status.value = DevicePollStatus.stopped;
  }

  /// Points the poller at another device id and reconnects right away.
  void switchDevice(String deviceId) {
    if (deviceId == _deviceId) return;
    _deviceId = deviceId;
    _url = null;
    if (_running) _restart();
  }

  Future<void> dispose() async {
    if (_messages.isClosed) return;
    stop();
    _status.dispose();
    _dio.close(force: true);
    await _messages.close();
  }

  void _restart() {
    _interrupt();
    _run(_generation);
  }

  /// Ends the current loop: aborts its held request or wakes its backoff.
  void _interrupt() {
    _generation++;
    _cancelToken?.cancel();
    _cancelToken = null;
    _wake?.call();
  }

  Future<void> _run(int generation) async {
    _status.value = DevicePollStatus.connecting;
    var failures = 0;

    while (generation == _generation) {
      final cancelToken = _cancelToken = CancelToken();
      final watch = Stopwatch()..start();
      Duration? pause;

      try {
        final response = await _dio.get<Object?>(
          _url ??= '$baseUrl/poll/${Uri.encodeComponent(_deviceId)}?timeout=${pollTimeout.inMilliseconds}',
          options: _options,
          cancelToken: cancelToken,
        );
        final statusCode = response.statusCode;
        // The server already dequeued it — deliver even if we were just
        // stopped or switched, never drop it.
        if (statusCode == 200 && !_messages.isClosed) _deliver(response.data);
        if (generation != _generation) return;

        switch (statusCode) {
          case 200:
            failures = 0;
            _status.value = DevicePollStatus.live;
          case 204:
            failures = 0;
            _status.value = DevicePollStatus.live;
            if (watch.elapsed < _minHold) pause = minBackoff;
          case 404:
            _lastError = 'Poll route not found: ${response.requestOptions.uri}';
            _status.value = DevicePollStatus.misconfigured;
            pause = maxBackoff;
          default:
            _lastError = 'Unexpected poll status ${response.statusCode}';
            _status.value = DevicePollStatus.reconnecting;
            pause = _backoff(++failures);
        }
      } on DioException catch (e) {
        if (generation != _generation) return;
        _lastError = e;
        _status.value = DevicePollStatus.reconnecting;
        pause = _backoff(++failures);
      }

      if (pause != null) await _sleep(pause);
    }
  }

  void _deliver(Object? body) {
    var decoded = body;
    if (decoded is String && decoded.isNotEmpty) {
      try {
        decoded = jsonDecode(decoded);
      } on FormatException {
        _lastError = 'Poll response is not JSON';
        return;
      }
    }
    if (decoded is! Map) return;

    final message = DeviceMessage.fromPollData(decoded['data'], DateTime.now());
    if (message == null || _isDuplicate(message.dedupeKey)) return;

    if (_messages.hasListener) {
      _messages.add(message);
    } else {
      if (_buffer.length == _bufferCapacity) _buffer.removeAt(0);
      _buffer.add(message);
    }
  }

  void _flushBuffer() {
    for (final message in _buffer) {
      _messages.add(message);
    }
    _buffer.clear();
  }

  bool _isDuplicate(String? key) {
    if (key == null) return false;
    if (!_seen.add(key)) return true;
    if (_seen.length > _seenCapacity) _seen.remove(_seen.first);
    return false;
  }

  /// minBackoff × 2^(failures−1), capped at maxBackoff, ±20% jitter.
  Duration _backoff(int failures) {
    final exponential = minBackoff * math.pow(2, math.min(failures - 1, 16));
    final capped = exponential > maxBackoff ? maxBackoff : exponential;
    return capped * (0.8 + _random.nextDouble() * 0.4);
  }

  Future<void> _sleep(Duration duration) {
    final completer = Completer<void>();
    final timer = Timer(duration, completer.complete);
    late final void Function() wake;
    wake = () {
      timer.cancel();
      if (!completer.isCompleted) completer.complete();
    };
    _wake = wake;
    return completer.future.whenComplete(() {
      if (identical(_wake, wake)) _wake = null;
    });
  }
}
