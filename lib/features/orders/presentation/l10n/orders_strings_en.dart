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
  String get allPlatforms => 'All';
  @override
  String get sidebarCollapse => 'Collapse';
  @override
  String get sidebarExpand => 'Expand menu';
  @override
  String get columnPreparing => 'Preparing';
  @override
  String get columnEndProcess => 'End process';
  @override
  String get columnAttention => 'Needs attention';
  @override
  String get newOrderTitle => 'NEW ORDER!';
  @override
  String newOrdersCount(int n) => '$n NEW ORDERS!';
  @override
  String get newOrderDismiss => 'OK, got it';
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
  String get dateFilterTitle => 'Show orders from';

  @override
  String get dateToday => 'Today';

  @override
  String get dateYesterday => 'Yesterday';

  @override
  String get dateLast7Days => 'Last 7 days';

  @override
  String get dateThisMonth => 'This month';

  @override
  String get dateAll => 'All time';

  @override
  String get dateCustom => 'Custom range';

  @override
  String get dateCustomHelp => 'Pick the first and last day';

  @override
  String get addOns => 'Add-ons';

  @override
  String get itemSubtotal => 'Item';
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
  String get menus => 'Menus';

  @override
  String get reports => 'Reports';

  @override
  String get actionSelfDispatch => 'Our courier';

  @override
  String get actionSelfDeliver => 'Delivered';

  @override
  String get actionCourier => 'Courier';

  @override
  String get actionPartialRefund => 'Partial refund';

  @override
  String get selfDeliveryBadge => 'Our delivery';

  @override
  String get courierDialogTitle => 'Courier details';

  @override
  String get courierDispatchSubtitle => 'Who is taking this order out?';

  @override
  String get courierDeliverSubtitle => 'Confirm the order reached the customer';

  @override
  String get courierUpdateSubtitle =>
      'Update the courier shown to the customer';

  @override
  String get courierName => 'Courier name';

  @override
  String get courierPhone => 'Phone';

  @override
  String get courierPlate => 'Plate number';

  @override
  String get courierVehicle => 'Vehicle';

  @override
  String get vehicleWalking => 'On foot';

  @override
  String get vehicleBicycle => 'Bicycle';

  @override
  String get vehicleMotorcycle => 'Motorcycle';

  @override
  String get vehicleCar => 'Car';

  @override
  String get courierConfirmDispatch => 'Out for delivery';

  @override
  String get courierConfirmDeliver => 'Mark delivered';

  @override
  String get courierConfirmUpdate => 'Save courier';

  @override
  String get courierNeedsOne => 'Fill in at least one courier detail';

  @override
  String get refundTitle => 'Partial refund';

  @override
  String get refundSubtitle => 'Refund only the items that went wrong';

  @override
  String get refundLoading => 'Checking what can be refunded…';

  @override
  String get refundNothing => 'Nothing in this order can be refunded';

  @override
  String get refundAlready => 'refunded';

  @override
  String get refundReason => 'Reason';

  @override
  String get refundReasonOther => 'Other reason';

  @override
  String get refundReasonSlow => 'Slow preparation';

  @override
  String get refundReasonIngredients => 'Insufficient ingredients';

  @override
  String get refundReasonMissing => 'Missing or incomplete delivery';

  @override
  String get refundReasonWrong => 'Wrong item prepared';

  @override
  String get refundDescribe => 'Describe the reason';

  @override
  String get refundTotal => 'Refund total';

  @override
  String get refundApply => 'Refund';

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
