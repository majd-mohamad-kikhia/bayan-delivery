import 'dart:async';
import 'dart:math' as math;

import '../../../core/security/time_token.dart';
import '../../../core/storage/app_preferences.dart';
import '../../orders/data/models/order_model.dart';
import 'bayan_order_mapper.dart';
import 'bayan_orders_repository.dart';

/// POSTs [body] to Bayan and returns what it answered. Never repeated.
typedef BayanPost = Future<Object?> Function(String path, Object body);

/// Books platform orders in Bayan (`POST /addOrderInternal`).
///
/// Built for volume and for safety:
/// * an order is sent **once**: the ledger (read into memory at start) answers
///   "already sent" without touching the database or the network, and a
///   second request for an order that is in flight shares the first;
/// * one request per order, no retry (a lost answer must not become a second
///   invoice), failures keep their reason and may be sent again by hand;
/// * [sendMany] runs a bounded number at a time and reports each order on
///   its own, so one bad order never stops the rest.
class BayanOrderSender {
  BayanOrderSender({
    required BayanPost post,
    required BayanOrdersRepository repository,
    required AppPreferences preferences,
    DateTime Function()? clock,
  }) : _post = post,
       _repository = repository,
       _preferences = preferences,
       _clock = clock ?? DateTime.now;

  static const path = '/addOrderInternal';
  static const defaultConcurrency = 4;

  final BayanPost _post;
  final BayanOrdersRepository _repository;
  final AppPreferences _preferences;
  final DateTime Function() _clock;

  Map<String, BayanOrderRecord> _records = {};
  final Map<String, Future<BayanOrderRecord>> _inFlight = {};

  Future<Map<String, BayanOrderRecord>> load() async =>
      _records = await _repository.all();

  Map<String, BayanOrderRecord> get records => _records;

  BayanOrderRecord? recordOf(OrderModel order) =>
      _records[BayanOrderRecord.keyOf(order.platform, order.platformOrderId)];

  /// Whether Bayan has this order already.
  bool isSent(OrderModel order) => recordOf(order)?.sent ?? false;

  /// Sends [order] unless it is already booked (or [force]).
  Future<BayanOrderRecord> send(OrderModel order, {bool force = false}) {
    final key = BayanOrderRecord.keyOf(order.platform, order.platformOrderId);
    final existing = _records[key];
    if (existing != null && existing.sent && !force) {
      return Future.value(existing);
    }
    // The callback must not return the removed future: whenComplete would
    // then wait for the very future it is completing.
    return _inFlight[key] ??= _run(order).whenComplete(() {
      _inFlight.remove(key);
    });
  }

  /// Sends every order of [orders] that is not booked yet, a few at a time.
  /// The result is in the same order as the orders that were actually sent.
  Future<List<BayanOrderRecord>> sendMany(
    Iterable<OrderModel> orders, {
    int concurrency = defaultConcurrency,
    void Function(BayanOrderRecord record)? onEach,
  }) async {
    final todo = [
      for (final o in orders)
        if (!isSent(o)) o,
    ];
    final results = List<BayanOrderRecord?>.filled(todo.length, null);
    var next = 0;
    Future<void> worker() async {
      while (next < todo.length) {
        final i = next++;
        final record = await send(todo[i]);
        results[i] = record;
        onEach?.call(record);
      }
    }

    await Future.wait([
      for (var i = 0; i < math.min(concurrency, todo.length); i++) worker(),
    ]);
    return [for (final r in results) ?r];
  }

  Future<BayanOrderRecord> _run(OrderModel order) async {
    final attemptedAt = _clock();
    BayanOrderRecord outcome({
      double? total,
      String? response,
      String? error,
    }) => BayanOrderRecord(
      platform: order.platform,
      orderId: order.platformOrderId,
      status: error == null ? BayanSendStatus.sent : BayanSendStatus.failed,
      total: total,
      response: response,
      error: error,
      attemptedAt: attemptedAt,
    );

    BayanOrderRecord result;
    final key = _preferences.bayanOrderKey;
    final account = _preferences.bayanAccount(order.platform);
    if (!TimeToken.isValidKey(key)) {
      result = outcome(error: 'The Bayan order key is not set (8 characters)');
    } else if (account == null) {
      result = outcome(error: 'No Bayan account number for ${order.platform}');
    } else {
      final draft = BayanOrderMapper.build(order, account: account);
      if (!draft.ok) {
        result = outcome(error: draft.problems.join('; '));
      } else {
        try {
          final body = await _post(path, {
            'Hash': TimeToken.encrypt(key),
            'Order': draft.order,
          });
          final refusal = _refusal(body);
          result = refusal == null
              ? outcome(total: draft.total, response: _short(body))
              : outcome(total: draft.total, error: refusal);
        } on Object catch (e) {
          result = outcome(total: draft.total, error: '$e');
        }
      }
    }

    _records = {..._records, result.key: result};
    await _repository.save(result);
    return result;
  }

  /// Bayan's answer is not documented: only an explicit `success: false` (or
  /// an `error` field) counts as a refusal; any 2xx otherwise is a success.
  static String? _refusal(Object? body) {
    if (body is! Map) return null;
    final success = body['success'] ?? body['Success'];
    final error = body['error'] ?? body['Error'];
    if (success == false || (error != null && '$error'.isNotEmpty)) {
      return '${body['message'] ?? body['Message'] ?? error ?? 'Bayan refused the order'}';
    }
    return null;
  }

  static String? _short(Object? body) {
    if (body == null) return null;
    final text = '$body';
    return text.length <= 200 ? text : text.substring(0, 200);
  }
}
