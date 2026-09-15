import 'package:equatable/equatable.dart';

/// One order, unified across platforms.
///
/// - [status] — hub `internal_event_type` (filter / kanban columns)
/// - [lastEvent] — platform-native event label when the hub provides it
/// - [availableActions] — buttons to show; never hardcode transitions
/// - [rawOrder] — platform payload (HungerStation ≠ Keeta schema)
class OrderModel extends Equatable {
  const OrderModel({
    required this.platform,
    required this.platformOrderId,
    required this.dongleNumber,
    required this.status,
    required this.availableActions,
    required this.transportType,
    required this.requiresUrgentAction,
    required this.createdAt,
    required this.updatedAt,
    required this.rawOrder,
    this.lastEvent,
  });

  final String platform;
  final String platformOrderId;
  final String dongleNumber;
  final String status;
  final String? lastEvent;
  final List<String> availableActions;
  final String? transportType;
  final bool requiresUrgentAction;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic> rawOrder;

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      platform: json['platform'] as String,
      platformOrderId: json['platformOrderId'] as String,
      dongleNumber: json['dongleNumber'] as String,
      status: json['status'] as String,
      lastEvent: json['lastEvent'] as String?,
      availableActions: (json['availableActions'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
      transportType: json['transportType'] as String?,
      requiresUrgentAction: json['requiresUrgentAction'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      rawOrder: (json['order'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  Map<String, dynamic>? get _customer {
    final c = rawOrder['customer'];
    if (c is! Map) return null;
    return c.cast<String, dynamic>();
  }

  String? get customerName {
    final customer = _customer;
    if (customer == null) return null;

    // Keeta: { name }
    final keetaName = customer['name']?.toString().trim();
    if (keetaName != null && keetaName.isNotEmpty) return keetaName;

    // HungerStation: { first_name, last_name }
    final name = '${customer['first_name'] ?? ''} ${customer['last_name'] ?? ''}'.trim();
    return name.isEmpty ? null : name;
  }

  String? get customerPhone {
    final customer = _customer;
    if (customer == null) return null;
    return (customer['phone'] ?? customer['phone_number'])?.toString();
  }

  double? get orderTotal {
    // Keeta: order.total
    final keetaTotal = rawOrder['total'];
    if (keetaTotal is num) return keetaTotal.toDouble();

    // HungerStation: payment.order_total
    final hsTotal = (rawOrder['payment'] as Map?)?['order_total'];
    return hsTotal is num ? hsTotal.toDouble() : null;
  }

  int? get itemCount {
    final items = rawOrder['items'];
    return items is List ? items.length : null;
  }

  String? get orderCode {
    // Keeta: orderViewId · HungerStation: order_code
    final code = rawOrder['order_code'] ?? rawOrder['orderViewId'] ?? platformOrderId;
    return code?.toString();
  }

  String? get cancellationReason {
    final cancellation = rawOrder['cancellation'];
    if (cancellation is! Map) return null;
    final reason = cancellation['reason'];
    if (reason == null) return null;
    final text = reason.toString().trim();
    return text.isEmpty ? null : text;
  }

  List<Map<String, dynamic>> get items {
    final raw = rawOrder['items'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  Map<String, dynamic>? get payment {
    final raw = rawOrder['payment'];
    if (raw is! Map) return null;
    return raw.cast<String, dynamic>();
  }

  String get transportTypeLabel {
    switch (transportType) {
      case 'VENDOR_DELIVERY':
        return 'Vendor Delivery';
      case 'LOGISTICS_DELIVERY':
        return 'Logistics Delivery';
      default:
        return transportType ?? '—';
    }
  }

  @override
  List<Object?> get props => [
        platform,
        platformOrderId,
        dongleNumber,
        status,
        lastEvent,
        availableActions,
        transportType,
        requiresUrgentAction,
        createdAt,
        updatedAt,
        rawOrder,
      ];
}
