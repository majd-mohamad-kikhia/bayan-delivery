import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/audio/order_alert.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/realtime/device_poller.dart';
import '../../../../core/storage/app_preferences.dart';
import '../../data/models/order_model.dart';
import '../../data/repositories/orders_repository.dart';
import 'orders_event.dart';
import 'orders_state.dart';

class OrdersBloc extends Bloc<OrdersEvent, OrdersState> {
  OrdersBloc({
    required OrdersRepository repository,
    required AppPreferences preferences,
    DevicePoller? devicePoller,
  }) : _repository = repository,
       _preferences = preferences,
       _devicePoller = devicePoller,
       super(
         OrdersState(
           dongleNumber: preferences.dongleNumber,
           alertMuted: preferences.orderAlertMuted,
         ),
       ) {
    on<OrdersRequested>(_onRequested);
    on<OrdersPollTicked>(_onPollTicked);
    on<OrdersPushReceived>(_onPushReceived);
    on<OrdersPlatformFilterChanged>(_onFilterChanged);
    on<OrdersHistoryToggled>(_onHistoryToggled);
    on<OrdersAlertMuteToggled>((event, emit) {
      final muted = !state.alertMuted;
      _preferences.setOrderAlertMuted(muted);
      emit(state.copyWith(alertMuted: muted));
    });
    on<OrdersDateFilterChanged>(_onDateFilterChanged);
    on<OrdersDongleChanged>(_onDongleChanged);
    on<OrderActionRequested>(_onActionRequested);
    on<OrderActionErrorCleared>(_onActionErrorCleared);
    on<NewOrderAlertDismissed>(
      (event, emit) => emit(state.copyWith(newOrderAlerts: const [])),
    );

    _pollTimer = Timer.periodic(AppConstants.pollInterval, (_) {
      if (!isClosed) add(const OrdersPollTicked());
    });
    // Keeps ringing until the first column is empty: an order nobody has
    // accepted must not be missed, and Keeta cancels it after about 5 minutes.
    _alertTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!isClosed && !state.alertMuted && state.pendingNewOrders > 0) {
        unawaited(OrderAlert.play());
      }
    });
    _pushSubscription = devicePoller?.messages.listen((_) {
      if (!isClosed) add(const OrdersPushReceived());
    });
  }

  final OrdersRepository _repository;
  final AppPreferences _preferences;
  final DevicePoller? _devicePoller;
  late final Timer _pollTimer;
  late final Timer _alertTimer;
  StreamSubscription<Object?>? _pushSubscription;

  /// Order keys already seen, per fetch scope (dongle + platform tab). A
  /// scope's first fetch only records what's there — so switching tabs
  /// never replays orders as "new" — and later fetches alert on the rest.
  final Map<String, Set<String>> _knownOrderKeys = {};

  String get _scope => '${state.dongleNumber}|${state.platformFilter}';
  bool _backgroundFetchInFlight = false;
  bool _backgroundFetchQueued = false;

  Future<void> _onRequested(
    OrdersRequested event,
    Emitter<OrdersState> emit,
  ) async {
    emit(state.copyWith(status: OrdersStatus.loading));
    await _emitCached(emit);
    await _fetch(emit);
  }

  /// Shows what's stored on this device right away; the network fetch that
  /// follows replaces it. Seeds the known-order set so cached orders don't
  /// ring the new-order alert when the fetch lands.
  Future<void> _emitCached(Emitter<OrdersState> emit) async {
    try {
      final cached = await _repository.cachedOrders(
        dongleNumber: state.dongleNumber,
        platform: state.fetchPlatform,
      );
      if (cached.isEmpty || emit.isDone) return;
      _knownOrderKeys.putIfAbsent(
        _scope,
        () => {for (final o in cached) '${o.platform}:${o.platformOrderId}'},
      );
      emit(
        state.copyWith(
          status: OrdersStatus.success,
          orders: cached,
          lastSyncedAt: await _repository.cachedSyncedAt(
            dongleNumber: state.dongleNumber,
          ),
        ),
      );
    } catch (_) {
      // A broken cache must never block the live fetch.
    }
  }

  Future<void> _onPollTicked(
    OrdersPollTicked event,
    Emitter<OrdersState> emit,
  ) => _backgroundFetch(emit, queueIfBusy: false);

  Future<void> _onPushReceived(
    OrdersPushReceived event,
    Emitter<OrdersState> emit,
  ) => _backgroundFetch(emit, queueIfBusy: true);

  /// One background fetch at a time. A tick that lands mid-fetch is dropped
  /// (the fetch in flight is just as fresh); a push that lands mid-fetch
  /// queues exactly one follow-up, since the data changed after that fetch
  /// started. A burst of pushes therefore costs at most two requests, and a
  /// slow backend never piles up concurrent ones.
  Future<void> _backgroundFetch(
    Emitter<OrdersState> emit, {
    required bool queueIfBusy,
  }) async {
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
    final scope =
        _scope; // the filter may change while the request is in flight
    try {
      final orders = await _repository.fetchOrders(
        dongleNumber: state.dongleNumber,
        platform: state.fetchPlatform,
      );
      final known = _knownOrderKeys[scope];
      final newOrders = known == null
          ? const <OrderModel>[]
          : [
              for (final o in orders)
                if (o.status == 'NEW_ORDER' &&
                    !known.contains('${o.platform}:${o.platformOrderId}'))
                  o,
            ];
      (_knownOrderKeys[scope] ??= {}).addAll([
        for (final o in orders) '${o.platform}:${o.platformOrderId}',
      ]);
      if (newOrders.isNotEmpty) unawaited(OrderAlert.play());
      emit(
        state.copyWith(
          status: OrdersStatus.success,
          orders: orders,
          clearError: true,
          lastSyncedAt: DateTime.now(),
          newOrderAlerts: newOrders.isEmpty
              ? null
              : [...state.newOrderAlerts, ...newOrders],
        ),
      );
    } catch (e) {
      emit(
        silent
            ? state.copyWith(error: AppError.from(e))
            : state.copyWith(
                status: OrdersStatus.failure,
                error: AppError.from(e),
              ),
      );
    }
  }

  Future<void> _onFilterChanged(
    OrdersPlatformFilterChanged event,
    Emitter<OrdersState> emit,
  ) async {
    if (event.platform == state.platformFilter) return;
    emit(
      state.copyWith(
        platformFilter: event.platform,
        status: OrdersStatus.loading,
      ),
    );
    await _fetch(emit);
  }

  /// Applies the new day range and re-reads the orders, with a spinner that
  /// stays long enough to be seen even when the backend answers instantly.
  Future<void> _onDateFilterChanged(
    OrdersDateFilterChanged event,
    Emitter<OrdersState> emit,
  ) async {
    if (event.filter == state.dateFilter) return;
    emit(state.copyWith(dateFilter: event.filter, isDateLoading: true));
    await Future.wait([
      _fetch(emit, silent: true),
      Future<void>.delayed(const Duration(milliseconds: 450)),
    ]);
    if (!emit.isDone) emit(state.copyWith(isDateLoading: false));
  }

  void _onHistoryToggled(
    OrdersHistoryToggled event,
    Emitter<OrdersState> emit,
  ) {
    emit(state.copyWith(showHistory: !state.showHistory));
  }

  Future<void> _onDongleChanged(
    OrdersDongleChanged event,
    Emitter<OrdersState> emit,
  ) async {
    await _preferences.setDongleNumber(event.dongleNumber);
    _devicePoller?.switchDevice(event.dongleNumber);
    emit(
      state.copyWith(
        dongleNumber: event.dongleNumber,
        status: OrdersStatus.loading,
      ),
    );
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
        payload: event.payload,
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
      emit(state.copyWith(actionError: AppError.from(e)));
    } finally {
      final updated = {...state.pendingActionIds}..remove(key);
      emit(state.copyWith(pendingActionIds: updated));
    }
  }

  void _onActionErrorCleared(
    OrderActionErrorCleared event,
    Emitter<OrdersState> emit,
  ) {
    emit(state.copyWith(clearActionError: true));
  }

  @override
  Future<void> close() {
    _pollTimer.cancel();
    _alertTimer.cancel();
    _pushSubscription?.cancel();
    return super.close();
  }
}
