import 'dart:async';

import 'package:bayan_desktop/core/network/api_client.dart';
import 'package:bayan_desktop/core/realtime/device_poller.dart';
import 'package:bayan_desktop/core/storage/app_preferences.dart';
import 'package:bayan_desktop/features/orders/data/models/order_model.dart';
import 'package:bayan_desktop/features/orders/data/repositories/orders_repository.dart';
import 'package:bayan_desktop/features/orders/presentation/bloc/orders_bloc.dart';
import 'package:bayan_desktop/features/orders/presentation/bloc/orders_event.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/realtime/scripted_server.dart';

class ControlledRepository extends OrdersRepository {
  ControlledRepository() : super(ApiClient());

  final List<Completer<List<OrderModel>>> calls = [];

  @override
  Future<List<OrderModel>> fetchOrders({
    required String dongleNumber,
    String? platform,
  }) {
    final completer = Completer<List<OrderModel>>();
    calls.add(completer);
    return completer.future;
  }

  void completeAll() {
    for (final call in calls) {
      if (!call.isCompleted) call.complete(const []);
    }
  }
}

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  late ControlledRepository repository;
  late OrdersBloc bloc;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = ControlledRepository();
    bloc = OrdersBloc(
      repository: repository,
      preferences: await AppPreferences.create(),
    );
  });

  tearDown(() async {
    repository.completeAll();
    await bloc.close();
  });

  test(
    'pushes during a fetch collapse into one follow-up; ticks do not queue',
    () async {
      bloc.add(const OrdersPushReceived());
      await settle();
      expect(repository.calls, hasLength(1));

      bloc
        ..add(const OrdersPushReceived())
        ..add(const OrdersPushReceived())
        ..add(const OrdersPollTicked());
      await settle();
      expect(
        repository.calls,
        hasLength(1),
        reason: 'still one request in flight',
      );

      repository.calls.first.complete(const []);
      await settle();
      expect(
        repository.calls,
        hasLength(2),
        reason: 'exactly one follow-up for the pushes',
      );

      repository.calls.last.complete(const []);
      await settle();
      expect(repository.calls, hasLength(2));

      bloc.add(const OrdersPollTicked());
      await settle();
      expect(repository.calls, hasLength(3));
    },
  );

  test('a device message triggers a refresh', () async {
    await bloc.close();
    final server = ScriptedServer([
      data({'orderId': '1'}),
    ]);
    final poller = DevicePoller(
      baseUrl: 'http://server:3000',
      deviceId: 'DEV-DONGLE-001',
      dio: Dio()..httpClientAdapter = server,
    );
    bloc = OrdersBloc(
      repository: repository,
      preferences: await AppPreferences.create(),
      devicePoller: poller,
    );

    poller.start();
    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while (repository.calls.isEmpty && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(repository.calls, hasLength(1));
    await poller.dispose();
  });
}
