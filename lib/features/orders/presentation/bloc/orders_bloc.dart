import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/realtime/device_poller.dart';
import '../../../../core/storage/app_preferences.dart';
import '../../data/repositories/orders_repository.dart';
import 'orders_event.dart';
import 'orders_state.dart';

class OrdersBloc extends Bloc<OrdersEvent, OrdersState> {
  OrdersBloc({
    required OrdersRepository repository,
    required AppPreferences preferences,
    DevicePoller? devicePoller,
  })  : _repository = repository,
        _preferences = preferences,
        _devicePoller = devicePoller,
        super(OrdersState(dongleNumber: preferences.dongleNumber)) {
    on<OrdersRequested>(_onRequested);
    on<OrdersPollTicked>(_onPollTicked);
    on<OrdersPushReceived>(_onPushReceived);
    on<OrdersPlatformFilterChanged>(_onFilterChanged);
    on<OrdersHistoryToggled>(_onHistoryToggled);
    on<OrdersDongleChanged>(_onDongleChanged);
    on<OrderActionRequested>(_onActionRequested);
    on<OrderActionErrorCleared>(_onActionErrorCleared);

    _pollTimer = Timer.periodic(AppConstants.pollInterval, (_) {
      if (!isClosed) add(const OrdersPollTicked());
    });
    _pushSubscription = devicePoller?.messages.listen((_) {
      if (!isClosed) add(const OrdersPushReceived());
    });
  }

  final OrdersRepository _repository;
  final AppPreferences _preferences;
  final DevicePoller? _devicePoller;
  late final Timer _pollTimer;
  StreamSubscription<Object?>? _pushSubscription;
  bool _backgroundFetchInFlight = false;
  bool _backgroundFetchQueued = false;

  Future<void> _onRequested(OrdersRequested event, Emitter<OrdersState> emit) async {
    emit(state.copyWith(status: OrdersStatus.loading));
    await _fetch(emit);
  }

  Future<void> _onPollTicked(OrdersPollTicked event, Emitter<OrdersState> emit) =>
      _backgroundFetch(emit, queueIfBusy: false);

  Future<void> _onPushReceived(OrdersPushReceived event, Emitter<OrdersState> emit) =>
      _backgroundFetch(emit, queueIfBusy: true);

  /// One background fetch at a time. A tick that lands mid-fetch is dropped
  /// (the fetch in flight is just as fresh); a push that lands mid-fetch
  /// queues exactly one follow-up, since the data changed after that fetch
  /// started. A burst of pushes therefore costs at most two requests, and a
  /// slow backend never piles up concurrent ones.
  Future<void> _backgroundFetch(Emitter<OrdersState> emit, {required bool queueIfBusy}) async {
    if (_backgroundFetchInFlight) {
      if (queueIfBusy) _backgroundFetchQueued = true;
      return;
    }
    _backgroundFetchInFlight = true;
    try {
      do {
        _backgroundFetchQueued = false;
        await _fetch(emit, silent: true);
      } while (_backgroundFetchQueued && !emit.isDone);
    } finally {
      _backgroundFetchInFlight = false;
    }
  }

  Future<void> _fetch(Emitter<OrdersState> emit, {bool silent = false}) async {
    try {
      final orders = await _repository.fetchOrders(
        dongleNumber: state.dongleNumber,
        platform: state.platformFilter,
      );
      emit(state.copyWith(
        status: OrdersStatus.success,
        orders: orders,
        clearError: true,
        lastSyncedAt: DateTime.now(),
      ));
    } catch (e) {
      emit(
        silent
            ? state.copyWith(errorMessage: e.toString())
            : state.copyWith(status: OrdersStatus.failure, errorMessage: e.toString()),
      );
    }
  }

  Future<void> _onFilterChanged(
    OrdersPlatformFilterChanged event,
    Emitter<OrdersState> emit,
  ) async {
    if (event.platform == state.platformFilter) return;
    emit(state.copyWith(platformFilter: event.platform, status: OrdersStatus.loading));
    await _fetch(emit);
  }

  void _onHistoryToggled(OrdersHistoryToggled event, Emitter<OrdersState> emit) {
    emit(state.copyWith(showHistory: !state.showHistory));
  }

  Future<void> _onDongleChanged(OrdersDongleChanged event, Emitter<OrdersState> emit) async {
    await _preferences.setDongleNumber(event.dongleNumber);
    _devicePoller?.switchDevice(event.dongleNumber);
    emit(state.copyWith(dongleNumber: event.dongleNumber, status: OrdersStatus.loading));
    await _fetch(emit);
  }

  Future<void> _onActionRequested(
    OrderActionRequested event,
    Emitter<OrdersState> emit,
  ) async {
    final key = '${event.platform}:${event.platformOrderId}';
    emit(
      state.copyWith(
        pendingActionIds: {...state.pendingActionIds, key},
        clearActionError: true,
      ),
    );

    try {
      final updated = await _repository.performAction(
        platform: event.platform,
        platformOrderId: event.platformOrderId,
        action: event.action,
        dongleNumber: state.dongleNumber,
        reason: event.reason,
      );
      // Action response already has the new status — merge it, skip full refetch.
      final orders = [
        for (final order in state.orders)
          if (order.platform == updated.platform &&
              order.platformOrderId == updated.platformOrderId)
            updated
          else
            order,
      ];
      final hasUpdated = orders.any(
        (o) =>
            o.platform == updated.platform &&
            o.platformOrderId == updated.platformOrderId,
      );
      emit(
        state.copyWith(
          orders: hasUpdated ? orders : [...state.orders, updated],
          lastSyncedAt: DateTime.now(),
          clearError: true,
        ),
      );
    } catch (e) {
      emit(state.copyWith(actionError: e.toString()));
    } finally {
      final updated = {...state.pendingActionIds}..remove(key);
      emit(state.copyWith(pendingActionIds: updated));
    }
  }

  void _onActionErrorCleared(OrderActionErrorCleared event, Emitter<OrdersState> emit) {
    emit(state.copyWith(clearActionError: true));
  }

  @override
  Future<void> close() {
    _pollTimer.cancel();
    _pushSubscription?.cancel();
    return super.close();
  }
}
