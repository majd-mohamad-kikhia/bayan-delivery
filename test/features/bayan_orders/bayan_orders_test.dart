import 'dart:async';

import 'package:bayan_desktop/core/database/app_database.dart';
import 'package:bayan_desktop/core/security/time_token.dart';
import 'package:bayan_desktop/core/storage/app_preferences.dart';
import 'package:bayan_desktop/features/bayan_orders/data/bayan_order_mapper.dart';
import 'package:bayan_desktop/features/bayan_orders/data/bayan_order_sender.dart';
import 'package:bayan_desktop/features/bayan_orders/data/bayan_orders_repository.dart';
import 'package:bayan_desktop/features/orders/data/models/order_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

OrderModel _order(String platform, String id, Map<String, dynamic> raw, {String status = 'ORDER_COMPLETED'}) =>
    OrderModel(
      platform: platform,
      platformOrderId: id,
      dongleNumber: 'D',
      status: status,
      availableActions: const [],
      transportType: null,
      requiresUrgentAction: false,
      createdAt: DateTime(2026, 10, 18),
      updatedAt: DateTime(2026, 10, 18),
      rawOrder: raw,
    );

/// Keeta, as the official spec shapes it: minor units, add-ons in `groups`.
OrderModel _keeta({String id = '7001'}) => _order('keeta', id, {
  'orderViewId': id,
  'products': [
    {
      'name': 'Burger',
      'count': 2,
      'skuOpenItemCode': '6',
      'priceWithoutGroup': {'unitPrice': 1750, 'originUnitPrice': 2500},
      'groups': [
        {
          'shopProductGroupSkuList': [
            {'spuName': 'Cheese', 'groupSkuOpenItemCode': '21', 'price': 300, 'count': 1, 'groupSkuCount': 2},
          ],
        },
      ],
    },
    {
      'name': 'Fries',
      'count': 1,
      'spuOpenItemCode': '9',
      'priceWithoutGroup': {'unitPrice': 800, 'originUnitPrice': 800},
    },
  ],
});

OrderModel _hs({String id = 'hs-1'}) => _order('hungerstation', id, {
  'order_code': 'AB12',
  'items': [
    {
      'name': 'Burger',
      'sku': '6',
      'discount': 3.5,
      'pricing': {'quantity': 2, 'unit_price': 25.0},
      'options': [
        {'name': 'Cheese', 'sku': '21', 'quantity': 1, 'unit_price': 3.0},
      ],
    },
  ],
});

void main() {
  setUpAll(sqfliteFfiInit);

  group('mapper', () {
    test('Keeta: lines, add-on lines, discounts and total', () {
      final draft = BayanOrderMapper.build(_keeta(), account: 120);
      expect(draft.ok, isTrue);
      final order = draft.order!;
      expect(order['headers'], {
        'AccNum': 120,
        // 2×25 − 15 promotion + 2×3 cheese + 8 fries
        'TotalValue': 49,
        'Remark': 'keeta #7001',
      });
      expect(order['items'], [
        {'Item': 0, 'MatNum': 6, 'Quantity': 2, 'Price': 25, 'Value': 50, 'DisItem': 15, 'RemarkI': ''},
        {'Item': 1, 'MatNum': 21, 'Quantity': 2, 'Price': 3, 'Value': 6, 'DisItem': 0, 'RemarkI': ''},
        {'Item': 2, 'MatNum': 9, 'Quantity': 1, 'Price': 8, 'Value': 8, 'DisItem': 0, 'RemarkI': ''},
      ]);
    });

    test('Keeta (mock shape): add-ons from subProductList, priced per unit', () {
      final draft = BayanOrderMapper.build(
        _order('keeta', '1', {
          'products': [
            {
              'name': 'Burger',
              'count': 1,
              'skuOpenItemCode': '6',
              'priceWithoutGroup': {'unitPrice': 2500, 'originUnitPrice': 2500},
              'subProductList': [
                {'name': 'Cheese', 'openItemCode': '21', 'count': 2, 'price': 800},
              ],
            },
          ],
        }),
        account: 1,
      );
      final items = draft.order!['items']! as List;
      expect(items.last, containsPair('Price', 4));
      expect(items.last, containsPair('Quantity', 2));
      expect(draft.total, 33);
    });

    test('HungerStation: item, option line, line discount', () {
      final draft = BayanOrderMapper.build(_hs(), account: 7);
      expect(draft.order!['headers'], containsPair('TotalValue', 49.5));
      expect(draft.order!['items'], [
        {'Item': 0, 'MatNum': 6, 'Quantity': 2, 'Price': 25, 'Value': 50, 'DisItem': 3.5, 'RemarkI': ''},
        {'Item': 1, 'MatNum': 21, 'Quantity': 1, 'Price': 3, 'Value': 3, 'DisItem': 0, 'RemarkI': ''},
      ]);
    });

    test('an item with no Bayan number refuses the whole order', () {
      final draft = BayanOrderMapper.build(
        _order('hungerstation', 'x', {
          'items': [
            {'name': 'Good', 'sku': '6', 'pricing': {'quantity': 1, 'unit_price': 5}},
            {'name': 'Mystery', 'sku': 'HS-77', 'pricing': {'quantity': 1, 'unit_price': 5}},
          ],
        }),
        account: 1,
      );
      expect(draft.ok, isFalse);
      expect(draft.problems, ['Mystery: no Bayan number']);
    });

    test('no account, or no items, is refused', () {
      expect(BayanOrderMapper.build(_keeta(), account: 0).ok, isFalse);
      expect(BayanOrderMapper.build(_order('keeta', '1', {}), account: 1).problems, ['The order has no items']);
    });
  });

  group('sender', () {
    late AppDatabase database;
    late AppPreferences prefs;
    late List<({String path, Map body})> posts;
    Object? Function()? answer;
    Completer<void>? gate;

    BayanOrderSender sender() => BayanOrderSender(
      post: (path, body) async {
        posts.add((path: path, body: body as Map));
        await gate?.future;
        return answer?.call() ?? {'ok': true};
      },
      repository: BayanOrdersRepository(database.db),
      preferences: prefs,
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await AppPreferences.create();
      await prefs.setBayanOrderKey('abcd1234');
      await prefs.setBayanAccount('keeta', 120);
      await prefs.setBayanAccount('hungerstation', 121);
      database = await AppDatabase.open(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
      posts = [];
      answer = null;
      gate = null;
    });

    tearDown(() => database.close());

    test('posts the order with a time-token Hash, and remembers it was sent', () async {
      final s = sender();
      final record = await s.send(_keeta());
      expect(record.sent, isTrue);
      expect(record.total, 49);

      final post = posts.single;
      expect(post.path, '/addOrderInternal');
      final hash = post.body['Hash']! as String;
      expect(hash.runes.length, TimeToken.length);
      expect(
        TimeToken.positions.map((p) => hash[p]).join(),
        TimeToken.marker('abcd1234'),
      );
      expect((post.body['Order']! as Map)['headers'], containsPair('AccNum', 120));

      // Remembered across a restart.
      final again = sender();
      await again.load();
      expect(again.isSent(_keeta()), isTrue);
    });

    test('an order already sent is never sent again (unless forced)', () async {
      final s = sender();
      await s.send(_keeta());
      await s.send(_keeta());
      expect(posts, hasLength(1));
      await s.send(_keeta(), force: true);
      expect(posts, hasLength(2));
    });

    test('two requests for one order at once make one post', () async {
      gate = Completer();
      final s = sender();
      final a = s.send(_keeta());
      final b = s.send(_keeta());
      await Future<void>.delayed(Duration.zero);
      gate!.complete();
      final results = await Future.wait([a, b]);
      expect(posts, hasLength(1));
      expect(identical(results[0], results[1]), isTrue);
    });

    test('failures keep their reason and can be retried', () async {
      final s = sender();
      answer = () => {'success': false, 'message': 'Account 120 does not exist'};
      var record = await s.send(_keeta());
      expect(record.sent, isFalse);
      expect(record.error, 'Account 120 does not exist');

      answer = null;
      record = await s.send(_keeta());
      expect(record.sent, isTrue);
      expect(posts, hasLength(2));
    });

    test('nothing is posted without a key, an account, or a mappable order', () async {
      await prefs.setBayanOrderKey('short');
      var record = await sender().send(_keeta());
      expect(record.error, contains('order key'));

      await prefs.setBayanOrderKey('abcd1234');
      await prefs.setBayanAccount('keeta', null);
      record = await sender().send(_keeta(id: '2'));
      expect(record.error, contains('account'));

      await prefs.setBayanAccount('keeta', 120);
      record = await sender().send(_order('keeta', '3', {'products': [{'name': 'X', 'count': 1}]}));
      expect(record.error, 'X: no Bayan number');
      expect(posts, isEmpty);
    });

    test('sendMany skips booked orders, bounds concurrency, and one failure does not stop the rest', () async {
      final s = sender();
      await s.send(_keeta(id: 'done'));
      posts.clear();

      var running = 0;
      var peak = 0;
      final failing = _order('keeta', 'bad', {'products': [{'name': 'X', 'count': 1}]});
      final sender2 = BayanOrderSender(
        post: (path, body) async {
          running++;
          peak = peak > running ? peak : running;
          await Future<void>.delayed(const Duration(milliseconds: 5));
          running--;
          return {'ok': true};
        },
        repository: BayanOrdersRepository(database.db),
        preferences: prefs,
      );
      await sender2.load();

      final results = await sender2.sendMany([
        _keeta(id: 'done'),
        failing,
        for (var i = 0; i < 12; i++) _keeta(id: 'o$i'),
      ]);
      expect(results, hasLength(13), reason: 'the booked one was skipped');
      expect(results.where((r) => r.sent), hasLength(12));
      expect(results.where((r) => !r.sent).single.orderId, 'bad');
      expect(peak, lessThanOrEqualTo(BayanOrderSender.defaultConcurrency));
      expect(peak, greaterThan(1));
    });
  });
}
