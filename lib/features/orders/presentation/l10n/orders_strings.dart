import 'package:flutter/widgets.dart';

import '../../../../core/localization/locale_context.dart';
import 'orders_strings_ar.dart';
import 'orders_strings_en.dart';

/// Text for the orders feature (board, cards, dialogs, sidebar).
abstract class OrdersStrings {
  const OrdersStrings();

  // ── Navigation ─────────────────────────────────────────────────────────
  String get liveKanban;
  String get orderArchive;
  String get products;
  String get bayanErp;
  String get hsOutlet;
  String get keetaShops;

  // ── Board header ───────────────────────────────────────────────────────
  String get liveBoard;
  String get archive;
  String get refresh;
  String updatedAgo(String ago);

  // ── Board ──────────────────────────────────────────────────────────────
  String get loadingOrders;
  String get noOrders;
  String get noArchivedOrders;
  String get actionFailed;

  // ── Order card ─────────────────────────────────────────────────────────
  String itemCount(int n);
  String reason(String reason);

  // ── Order detail ───────────────────────────────────────────────────────
  String get orderDetail;
  String createdAgo(String ago);
  String get customer;
  String get name;
  String get phone;
  String get items;
  String get unknownItem;
  String eachPrice(String price);
  String get payment;
  String get total;
  String get subtotal;
  String get vat;
  String get discount;
  String get deliveryFee;
  String get serviceFee;
  String get cancellation;

  // ── Transport ──────────────────────────────────────────────────────────
  String get vendorDelivery;
  String get logisticsDelivery;

  String transportTypeLabel(String type) => switch (type) {
        'VENDOR_DELIVERY' => vendorDelivery,
        'LOGISTICS_DELIVERY' => logisticsDelivery,
        _ => type,
      };

  // ── Cancel / reject dialog ─────────────────────────────────────────────
  String get cancelOrderTitle;
  String get cancelOrder;
  String get rejectRefundTitle;
  String get rejectRefund;
  String orderNumber(String id);
  String get cancelReasonPrompt;
  String get cancelReasonHint;
  String get keepOrder;

  // ── Dongle ─────────────────────────────────────────────────────────────
  String get dongleDialogTitle;
  String get dongleNumber;

  // ── Actions ────────────────────────────────────────────────────────────
  String get actionAccept;
  String get actionConfirm;
  String get actionReady;
  String get actionHandoff;
  String get actionDispatch;
  String get actionCancel;
  String get actionAgreeRefund;
  String get actionRejectRefund;

  String actionLabel(String action, {required String platform}) =>
      switch (action) {
        'accept' => platform == 'keeta' ? actionConfirm : actionAccept,
        'ready' => actionReady,
        'collect' => actionHandoff,
        'dispatch' => actionDispatch,
        'cancel' => actionCancel,
        'agree' => actionAgreeRefund,
        'reject' => actionRejectRefund,
        _ => action,
      };

  // ── Statuses ───────────────────────────────────────────────────────────
  String get statusNew;
  String get statusCreated;
  String get statusConfirmed;
  String get statusAccepted;
  String get statusReadyForPickup;
  String get statusPickedUp;
  String get statusDispatched;
  String get statusDelivered;
  String get statusCompleted;
  String get statusCancelled;
  String get statusRefundRequest;
  String get statusCancelRequest;

  /// Keeta names the first two steps Created / Confirmed, so a few codes
  /// resolve differently per platform.
  String statusLabel(String status, {required String platform}) =>
      switch (status) {
        'NEW_ORDER' => platform == 'keeta' ? statusCreated : statusNew,
        'CREATED' => statusCreated,
        'ORDER_ACCEPTED' => platform == 'keeta' ? statusConfirmed : statusAccepted,
        'CONFIRMED' => statusConfirmed,
        'ORDER_READY' || 'READY_FOR_PICKUP' => statusReadyForPickup,
        'ORDER_PICKED_UP' || 'PICKED_UP' => statusPickedUp,
        'ORDER_DISPATCHED' || 'DISPATCHED' => statusDispatched,
        'ORDER_DELIVERED' || 'DELIVERED' => statusDelivered,
        'ORDER_COMPLETED' || 'CONCLUDED' => statusCompleted,
        'ORDER_CANCELLED' || 'CANCELLED' => statusCancelled,
        'REFUND_REQUESTED' || 'USER_REFUND_REQUEST' => statusRefundRequest,
        'CANCELLATION_REQUESTED' => statusCancelRequest,
        _ => status,
      };
}

extension OrdersStringsContext on BuildContext {
  OrdersStrings get ordersStrings =>
      isArabic ? const OrdersStringsAr() : const OrdersStringsEn();
}
