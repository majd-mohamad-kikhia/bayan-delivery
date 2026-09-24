import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Answers each poll from [script] in order; once the script runs out the
/// request is held forever (like a server with nothing queued).
class ScriptedServer implements HttpClientAdapter {
  ScriptedServer(this.script);

  final List<ResponseBody Function(RequestOptions options)> script;
  final List<Uri> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? _,
    Future<void>? cancelFuture,
  ) {
    requests.add(options.uri);
    final index = requests.length - 1;
    if (index >= script.length) return Completer<ResponseBody>().future;
    try {
      return Future.value(script[index](options));
    } catch (e) {
      return Future.error(e);
    }
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody Function(RequestOptions) data(Object? payload) =>
    (_) => ResponseBody.fromString(
      jsonEncode({'data': payload}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

ResponseBody Function(RequestOptions) status(int code) =>
    (_) => ResponseBody.fromString('', code);

ResponseBody Function(RequestOptions) networkDown() =>
    (options) => throw DioException.connectionError(
      requestOptions: options,
      reason: 'down',
    );
