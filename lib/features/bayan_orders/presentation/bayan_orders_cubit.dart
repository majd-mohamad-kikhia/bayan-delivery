import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../orders/data/models/order_model.dart';
import '../data/bayan_order_sender.dart';
import '../data/bayan_orders_repository.dart';

final class BayanOrdersState extends Equatable {
  const BayanOrdersState({this.records = const {}, this.busy = const {}});

  /// `platform|orderId` → what happened last time it was sent.
  final Map<String, BayanOrderRecord> records;

  /// Orders being sent right now.
  final Set<String> busy;

  BayanOrderRecord? recordOf(OrderModel order) =>
      records[BayanOrderRecord.keyOf(order.platform, order.platformOrderId)];

  bool isBusy(OrderModel order) => busy.contains(
    BayanOrderRecord.keyOf(order.platform, order.platformOrderId),
  );

  @override
  List<Object?> get props => [records, busy];
}

/// Sends orders to Bayan and shows what became of them.
class BayanOrdersCubit extends Cubit<BayanOrdersState> {
  BayanOrdersCubit(this._sender) : super(const BayanOrdersState());

  final BayanOrderSender _sender;

  static String _key(OrderModel o) =>
      BayanOrderRecord.keyOf(o.platform, o.platformOrderId);

  /// Bayan books only orders that were delivered (or completed).
  static bool isSendable(OrderModel order) =>
      order.status == 'ORDER_COMPLETED' || order.status == 'ORDER_DELIVERED';

  Future<void> load() async {
    final records = await _sender.load();
    if (!isClosed) emit(BayanOrdersState(records: records, busy: state.busy));
  }

  Future<BayanOrderRecord?> send(OrderModel order, {bool force = false}) async {
    final key = _key(order);
    if (state.busy.contains(key)) return null;
    emit(BayanOrdersState(records: state.records, busy: {...state.busy, key}));
    try {
      return await _sender.send(order, force: force);
    } finally {
      if (!isClosed) {
        emit(
          BayanOrdersState(
            records: _sender.records,
            busy: {...state.busy}..remove(key),
          ),
        );
      }
    }
  }

  /// Sends every sendable order that is not booked yet; how many were booked.
  Future<({int sent, int failed})> sendAll(Iterable<OrderModel> orders) async {
    final todo = [
      for (final o in orders)
        if (isSendable(o) && !(state.records[_key(o)]?.sent ?? false)) o,
    ];
    if (todo.isEmpty) return (sent: 0, failed: 0);
    emit(
      BayanOrdersState(
        records: state.records,
        busy: {...state.busy, for (final o in todo) _key(o)},
      ),
    );
    final results = await _sender.sendMany(
      todo,
      onEach: (r) {
        if (isClosed) return;
        // One rebuild per finished order, for that order's row only.
        emit(
          BayanOrdersState(
            records: _sender.records,
            busy: {...state.busy}..remove(r.key),
          ),
        );
      },
    );
    if (!isClosed) {
      emit(BayanOrdersState(records: _sender.records));
    }
    return (
      sent: results.where((r) => r.sent).length,
      failed: results.where((r) => !r.sent).length,
    );
  }
}
