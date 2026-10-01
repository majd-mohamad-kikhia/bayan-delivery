import 'orders_strings.dart';

final class OrdersStringsEn extends OrdersStrings {
  const OrdersStringsEn();

  @override
  String get liveKanban => 'Live Kanban';
  @override
  String get orderArchive => 'Order Archive';
  @override
  String get products => 'Products';
  @override
  String get bayanErp => 'Bayan ERP';
  @override
  String get hsOutlet => 'HS Outlet';
  @override
  String get keetaShops => 'Keeta Shops';

  @override
  String get liveBoard => 'Live Board';
  @override
  String get archive => 'Archive';
  @override
  String get refresh => 'Refresh';
  @override
  String updatedAgo(String ago) => 'Updated $ago';

  @override
  String get loadingOrders => 'Loading orders…';
  @override
  String get noOrders => 'No orders';
  @override
  String get noArchivedOrders => 'No archived orders yet';
  @override
  String get actionFailed => "Couldn't update the order";

  @override
  String itemCount(int n) => '$n item${n == 1 ? '' : 's'}';
  @override
  String reason(String reason) => 'Reason: $reason';

  @override
  String get orderDetail => 'Order detail';
  @override
  String createdAgo(String ago) => 'Created $ago';
  @override
  String get customer => 'Customer';
  @override
  String get name => 'Name';
  @override
  String get phone => 'Phone';
  @override
  String get items => 'Items';
  @override
  String get unknownItem => 'Unknown item';
  @override
  String eachPrice(String price) => '$price each';
  @override
  String get payment => 'Payment';
  @override
  String get total => 'Total';
  @override
  String get subtotal => 'Subtotal';
  @override
  String get vat => 'VAT';
  @override
  String get discount => 'Discount';
  @override
  String get deliveryFee => 'Delivery fee';
  @override
  String get serviceFee => 'Service fee';
  @override
  String get cancellation => 'Cancellation';

  @override
  String get vendorDelivery => 'Vendor Delivery';
  @override
  String get logisticsDelivery => 'Logistics Delivery';

  @override
  String get cancelOrderTitle => 'Cancel Order?';
  @override
  String get cancelOrder => 'Cancel Order';
  @override
  String get rejectRefundTitle => 'Reject Refund?';
  @override
  String get rejectRefund => 'Reject Refund';
  @override
  String orderNumber(String id) => 'Order #$id';
  @override
  String get cancelReasonPrompt =>
      'Please provide a reason. This action cannot be undone.';
  @override
  String get cancelReasonHint => 'e.g. Out of stock, customer request…';
  @override
  String get keepOrder => 'Keep Order';

  @override
  String get dongleDialogTitle => 'Restaurant dongle';
  @override
  String get dongleNumber => 'Dongle number';

  @override
  String get actionAccept => 'Accept';
  @override
  String get actionConfirm => 'Confirm';
  @override
  String get actionReady => 'Mark ready';
  @override
  String get actionHandoff => 'Handoff';
  @override
  String get actionDispatch => 'Dispatch';
  @override
  String get actionCancel => 'Cancel';
  @override
  String get actionAgreeRefund => 'Agree refund';
  @override
  String get actionRejectRefund => 'Reject refund';

  @override
  String get statusNew => 'New';
  @override
  String get statusCreated => 'Created';
  @override
  String get statusConfirmed => 'Confirmed';
  @override
  String get statusAccepted => 'Accepted';
  @override
  String get statusReadyForPickup => 'Ready for Pickup';
  @override
  String get statusPickedUp => 'Picked Up';
  @override
  String get statusDispatched => 'Dispatched';
  @override
  String get statusDelivered => 'Delivered';
  @override
  String get statusCompleted => 'Completed';
  @override
  String get statusCancelled => 'Cancelled';
  @override
  String get statusRefundRequest => 'Refund Request';
  @override
  String get statusCancelRequest => 'Cancel Request';
}
