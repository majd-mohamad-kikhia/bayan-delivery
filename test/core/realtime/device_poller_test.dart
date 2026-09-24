import 'package:bayan_desktop/core/platforms/keeta/keeta_types.dart';
import 'package:bayan_desktop/core/realtime/device_message.dart';
import 'package:bayan_desktop/core/realtime/device_poller.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'scripted_server.dart';

Map<String, Object> keetaPush(String messageId) => {
  'sig': 'x',
  'eventId': 1001,
  'appId': 1,
  'messageId': messageId,
  'shopId': 145541,
  'message': '{"orderViewId":553440887574627,"shopId":145541,"status":10}',
  'timestamp': 1749008143,
};

Future<void> until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 3));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('condition not met in time');
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
}

void main() {
  late ScriptedServer server;
  late DevicePoller poller;

  DevicePoller build(List<ResponseBody Function(RequestOptions)> script) {
    server = ScriptedServer(script);
    return poller = DevicePoller(
      baseUrl: 'http://server:3000',
      deviceId: 'DEV-DONGLE-001',
      minBackoff: const Duration(milliseconds: 1),
      maxBackoff: const Duration(milliseconds: 5),
      dio: Dio()..httpClientAdapter = server,
    );
  }

  tearDown(() => poller.dispose());

  test('delivers data, re-polls immediately and drops redeliveries', () async {
    build([
      data({'orderId': '12345', 'status': 'confirmed'}),
      data(keetaPush('m-1')),
      data(keetaPush('m-1')),
      data(const {}),
      status(204),
    ]);
    final received = <DeviceMessage>[];
    poller.messages.listen(received.add);

    poller.start();
    await until(() => server.requests.length == 6);

    expect(
      server.requests.first.toString(),
      'http://server:3000/poll/DEV-DONGLE-001?timeout=25000',
    );
    expect(
      received,
      hasLength(2),
      reason: 'duplicate m-1 and the empty heartbeat are dropped',
    );
    expect(received.first.payload, {'orderId': '12345', 'status': 'confirmed'});
    expect(received.last.keeta?.event, KeetaWebhookEvent.orderCreated);
    expect(received.last.keeta?.orderViewId, 553440887574627);
    expect(poller.status.value, DevicePollStatus.live);
  });

  test('backs off on errors, flags a wrong route, and recovers', () async {
    build([networkDown(), status(500), status(404), status(204)]);
    final seen = <DevicePollStatus>[];
    poller.status.addListener(() => seen.add(poller.status.value));

    poller.start();
    await until(() => server.requests.length == 5);

    expect(seen, [
      DevicePollStatus.connecting,
      DevicePollStatus.reconnecting,
      DevicePollStatus.misconfigured,
      DevicePollStatus.live,
    ]);
  });

  test('stop aborts the held request at once', () async {
    build([]);
    poller.start();
    await until(() => server.requests.length == 1);

    poller.stop();
    expect(poller.status.value, DevicePollStatus.stopped);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(server.requests, hasLength(1));
  });

  test('switchDevice reconnects immediately with the new id', () async {
    build([]);
    poller.start();
    await until(() => server.requests.length == 1);

    poller.switchDevice('DEV-DONGLE-002');
    await until(() => server.requests.length == 2);
    expect(server.requests.last.path, '/poll/DEV-DONGLE-002');
  });

  test('buffers messages that arrive before anyone listens', () async {
    build([
      data({'n': 1}),
      data({'n': 2}),
    ]);
    poller.start();
    await until(() => server.requests.length == 3);

    final received = await poller.messages.take(2).toList();
    expect(received.map((m) => m.payload), [
      {'n': 1},
      {'n': 2},
    ]);
  });

  test('unwraps executor results forwarded as { timestamp, result }', () {
    final message = DeviceMessage.fromPollData({
      'timestamp': '2026-09-21T12:00:00Z',
      'result': {'code': 0},
    }, DateTime.now());
    expect(message?.payload, {'code': 0});
  });
}
