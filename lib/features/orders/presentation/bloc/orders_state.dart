import 'package:equatable/equatable.dart';

import '../../../../core/constants/app_constants.dart';
import '../../data/models/order_model.dart';
import '../config/platform_board_config.dart';

enum OrdersStatus { initial, loading, success, failure }

final class OrdersState extends Equatable {
  const OrdersState({
    this.status = OrdersStatus.initial,
    this.orders = const [],
    this.errorMessage,
    this.platformFilter = 'keeta',
    this.showHistory = false,
    this.dongleNumber = AppConstants.defaultDongleNumber,
    this.pendingActionIds = const {},
    this.actionError,
    this.lastSyncedAt,
  });

  final OrdersStatus status;
  final List<OrderModel> orders;
  final String? errorMessage;
  final String platformFilter;
  final bool showHistory;
  final String dongleNumber;
  final Set<String> pendingActionIds;
  final String? actionError;

  /// Set after every successful fetch — drives the "Updated Xs ago" display.
  final DateTime? lastSyncedAt;

  PlatformBoardConfig get board => PlatformBoards.of(platformFilter);

  List<OrderModel> get visibleOrders =>
      orders.where((o) => showHistory == board.isTerminal(o.status)).toList();

  bool isActionPending(String platform, String platformOrderId) =>
      pendingActionIds.contains('$platform:$platformOrderId');

  OrdersState copyWith({
    OrdersStatus? status,
    List<OrderModel>? orders,
    String? errorMessage,
    bool clearError = false,
    String? platformFilter,
    bool? showHistory,
    String? dongleNumber,
    Set<String>? pendingActionIds,
    String? actionError,
    bool clearActionError = false,
    DateTime? lastSyncedAt,
  }) {
    return OrdersState(
      status: status ?? this.status,
      orders: orders ?? this.orders,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      platformFilter: platformFilter ?? this.platformFilter,
      showHistory: showHistory ?? this.showHistory,
      dongleNumber: dongleNumber ?? this.dongleNumber,
      pendingActionIds: pendingActionIds ?? this.pendingActionIds,
      actionError: clearActionError ? null : (actionError ?? this.actionError),
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }

  @override
  List<Object?> get props => [
        status,
        orders,
        errorMessage,
        platformFilter,
        showHistory,
        dongleNumber,
        pendingActionIds,
        actionError,
        lastSyncedAt,
      ];
}
