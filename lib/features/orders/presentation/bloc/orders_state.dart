import 'package:equatable/equatable.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_error.dart';
import '../../data/models/order_model.dart';
import '../config/platform_board_config.dart';
import '../utils/orders_date_filter.dart';

enum OrdersStatus { initial, loading, success, failure }

final class OrdersState extends Equatable {
  const OrdersState({
    this.status = OrdersStatus.initial,
    this.orders = const [],
    this.error,
    this.platformFilter = 'all',
    this.showHistory = false,
    this.dateFilter = OrdersDateFilter.today,
    this.isDateLoading = false,
    this.alertMuted = false,
    this.dongleNumber = AppConstants.defaultDongleNumber,
    this.pendingActionIds = const {},
    this.actionError,
    this.lastSyncedAt,
    this.newOrderAlerts = const [],
  });

  final OrdersStatus status;
  final List<OrderModel> orders;
  final AppError? error;
  final String platformFilter;
  final bool showHistory;

  /// Days of orders on the board; today by default.
  final OrdersDateFilter dateFilter;

  /// True while the orders are re-read after the day range changed.
  final bool isDateLoading;

  /// The repeating new-order sound is off; the flashing light stays.
  final bool alertMuted;
  final String dongleNumber;
  final Set<String> pendingActionIds;
  final AppError? actionError;

  /// Set after every successful fetch — drives the "Updated Xs ago" display.
  final DateTime? lastSyncedAt;

  /// Orders that arrived since the worker last dismissed the alert dialog.
  final List<OrderModel> newOrderAlerts;

  /// What to ask the backend for: null = every platform (the "All" tab).
  String? get fetchPlatform => platformFilter == 'all' ? null : platformFilter;

  PlatformBoardConfig get board => PlatformBoards.of(platformFilter);

  List<OrderModel> get visibleOrders {
    final now = DateTime.now();
    return orders
        .where(
          (o) =>
              showHistory == board.isTerminal(o.status) &&
              dateFilter.matches(o.createdAt, now),
        )
        .toList();
  }

  /// Orders waiting in the first column of the current tab (new, not yet
  /// accepted), for the chosen days. While this is above zero the app keeps
  /// sounding and flashing.
  int get pendingNewOrders {
    final now = DateTime.now();
    return orders
        .where(
          (o) =>
              o.status == 'NEW_ORDER' && dateFilter.matches(o.createdAt, now),
        )
        .length;
  }

  bool isActionPending(String platform, String platformOrderId) =>
      pendingActionIds.contains('$platform:$platformOrderId');

  OrdersState copyWith({
    OrdersStatus? status,
    List<OrderModel>? orders,
    AppError? error,
    bool clearError = false,
    String? platformFilter,
    bool? showHistory,
    OrdersDateFilter? dateFilter,
    bool? isDateLoading,
    bool? alertMuted,
    String? dongleNumber,
    Set<String>? pendingActionIds,
    AppError? actionError,
    bool clearActionError = false,
    DateTime? lastSyncedAt,
    List<OrderModel>? newOrderAlerts,
  }) {
    return OrdersState(
      status: status ?? this.status,
      orders: orders ?? this.orders,
      error: clearError ? null : (error ?? this.error),
      platformFilter: platformFilter ?? this.platformFilter,
      showHistory: showHistory ?? this.showHistory,
      dateFilter: dateFilter ?? this.dateFilter,
      isDateLoading: isDateLoading ?? this.isDateLoading,
      alertMuted: alertMuted ?? this.alertMuted,
      dongleNumber: dongleNumber ?? this.dongleNumber,
      pendingActionIds: pendingActionIds ?? this.pendingActionIds,
      actionError: clearActionError ? null : (actionError ?? this.actionError),
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      newOrderAlerts: newOrderAlerts ?? this.newOrderAlerts,
    );
  }

  @override
  List<Object?> get props => [
    status,
    orders,
    error,
    platformFilter,
    showHistory,
    dateFilter,
    isDateLoading,
    alertMuted,
    dongleNumber,
    pendingActionIds,
    actionError,
    lastSyncedAt,
    newOrderAlerts,
  ];
}
