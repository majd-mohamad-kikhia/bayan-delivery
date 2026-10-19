import 'package:equatable/equatable.dart';

import '../utils/orders_date_filter.dart';

sealed class OrdersEvent extends Equatable {
  const OrdersEvent();

  @override
  List<Object?> get props => [];
}

/// Full load — shows a full-page spinner if there's no data yet.
final class OrdersRequested extends OrdersEvent {
  const OrdersRequested();
}

/// Background refresh from the poll timer — keeps showing stale data if it
/// fails, so one flaky request doesn't blank out a working board.
final class OrdersPollTicked extends OrdersEvent {
  const OrdersPollTicked();
}

/// The backend pushed something for this device (via long-polling) —
/// refresh now instead of waiting for the next tick.
final class OrdersPushReceived extends OrdersEvent {
  const OrdersPushReceived();
}

final class OrdersPlatformFilterChanged extends OrdersEvent {
  const OrdersPlatformFilterChanged(this.platform);

  final String platform;

  @override
  List<Object?> get props => [platform];
}

/// The worker picked which days of orders to show.
final class OrdersDateFilterChanged extends OrdersEvent {
  const OrdersDateFilterChanged(this.filter);

  final OrdersDateFilter filter;

  @override
  List<Object?> get props => [filter];
}

/// Silence (or bring back) the repeating new-order sound.
final class OrdersAlertMuteToggled extends OrdersEvent {
  const OrdersAlertMuteToggled();
}

final class OrdersHistoryToggled extends OrdersEvent {
  const OrdersHistoryToggled();
}

final class OrdersDongleChanged extends OrdersEvent {
  const OrdersDongleChanged(this.dongleNumber);

  final String dongleNumber;

  @override
  List<Object?> get props => [dongleNumber];
}

final class OrderActionRequested extends OrdersEvent {
  const OrderActionRequested({
    required this.platform,
    required this.platformOrderId,
    required this.action,
    this.reason,
    this.payload,
  });

  final String platform;
  final String platformOrderId;
  final String action;
  final String? reason;

  /// Extra data some actions need (courier details, refund items).
  final Map<String, Object?>? payload;

  @override
  List<Object?> get props => [
    platform,
    platformOrderId,
    action,
    reason,
    payload,
  ];
}

/// Dismisses the action-error banner once the user has seen it.
final class OrderActionErrorCleared extends OrdersEvent {
  const OrderActionErrorCleared();
}

/// The worker acknowledged the new-order alert dialog.
final class NewOrderAlertDismissed extends OrdersEvent {
  const NewOrderAlertDismissed();
}
