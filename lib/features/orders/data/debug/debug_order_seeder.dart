import 'dart:math';

import 'package:dio/dio.dart';

import '../../../../core/constants/app_constants.dart';

/// Debug-only: adds one test order through the local Keeta / HungerStation
/// mocks. It reaches the backend the way the real platform delivers it:
/// Keeta pushes a webhook (the mock does it), HungerStation is polled (the
/// backend is asked to poll right away). Mirrors the backend's
/// `scripts/seed-mock-orders.js`.
///
/// The mocks are expected on the API host: Keeta :4000, HungerStation :4008.
class DebugOrderSeeder {
  DebugOrderSeeder({Dio? dio, Random? random})
    : _dio =
          dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 5))),
      _random = random ?? Random();

  final Dio _dio;
  final Random _random;

  // Must match the dev rows in the backend's configuration.
  static const int _keetaShopId = 145541;
  static const String _hsChainId = '550e8400-e29b-41d4-a716-446655440000';
  static const String _hsVendorId = '00000000-0000-0000-0000-000000000001';

  String get _host => Uri.parse(AppConstants.apiBaseUrl).host;
  String get _backend => AppConstants.apiBaseUrl;
  String get _keetaMock => 'http://$_host:4000';
  String get _hsMock => 'http://$_host:4008';

  /// Returns the new order id. The Keeta mock pushes the "new order"
  /// webhook to the backend itself, as the real platform would.
  ///
  /// [menu] is what the order is made from (see `savedMenuForMockOrders`).
  Future<String> addKeetaOrder({Map<String, Object?>? menu}) async {
    final id = 'keeta-dbg-${DateTime.now().millisecondsSinceEpoch}';
    await _dio.post(
      '$_keetaMock/_test/seed-order',
      data: {
        'orderViewId': id,
        'lastEvent': 'CREATED',
        'shopId': _keetaShopId,
        'menu': ?menu,
      },
    );
    return id;
  }

  Future<String> addHungerStationOrder({Map<String, Object?>? menu}) async {
    final id = 'hs-dbg-${DateTime.now().millisecondsSinceEpoch}';
    await _dio.post(
      '$_hsMock/_test/seed-order',
      data: {
        'orderId': id,
        'chainId': _hsChainId,
        'vendorId': _hsVendorId,
        'status': 'RECEIVED',
        'transportType': _random.nextBool()
            ? 'LOGISTICS_DELIVERY'
            : 'VENDOR_DELIVERY',
        'menu': ?menu,
      },
    );
    // The poll window's end time is truncated to whole seconds; wait so the
    // new order falls inside it.
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    await _dio.post('$_backend/api/hungerstation/poll');
    return id;
  }
}
