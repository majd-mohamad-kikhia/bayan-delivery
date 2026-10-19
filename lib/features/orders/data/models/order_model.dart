import 'dart:convert';

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

  factory OrderModel.fromDb(Map<String, Object?> row) {
    return OrderModel(
      platform: row['platform'] as String,
      platformOrderId: row['platform_order_id'] as String,
      dongleNumber: row['dongle_number'] as String,
      status: row['status'] as String,
      lastEvent: row['last_event'] as String?,
      availableActions: (jsonDecode(row['available_actions'] as String) as List)
          .map((e) => e.toString())
          .toList(),
      transportType: row['transport_type'] as String?,
      requiresUrgentAction: (row['requires_urgent_action'] as int) == 1,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      rawOrder: (jsonDecode(row['order_json'] as String) as Map)
          .cast<String, dynamic>(),
    );
  }

  Map<String, Object?> toDb({required DateTime syncedAt}) => {
    'platform': platform,
    'platform_order_id': platformOrderId,
    'dongle_number': dongleNumber,
    'status': status,
    'last_event': lastEvent,
    'transport_type': transportType,
    'requires_urgent_action': requiresUrgentAction ? 1 : 0,
    'available_actions': jsonEncode(availableActions),
    'order_json': jsonEncode(rawOrder),
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'synced_at': syncedAt.toUtc().toIso8601String(),
  };

  /// Keeta `deliveryMode` 9001: the restaurant delivers this order itself.
  bool get isSelfDelivery => rawOrder['deliveryMode']?.toString() == '9001';

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
    final name =
        '${customer['first_name'] ?? ''} ${customer['last_name'] ?? ''}'.trim();
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

    // HungerStation: payment.order_total (Keeta's real orders: via [payment])
    final total = payment?['order_total'];
    return total is num ? total.toDouble() : null;
  }

  int? get itemCount {
    final items = rawOrder['items'];
    return items is List ? items.length : null;
  }

  String? get orderCode {
    // Keeta: orderViewId · HungerStation: order_code
    final code =
        rawOrder['order_code'] ?? rawOrder['orderViewId'] ?? platformOrderId;
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

  /// HungerStation's `payment`, or Keeta's `feeDtl.customerFee` shaped the
  /// same way so one payment section serves both.
  Map<String, dynamic>? get payment {
    final raw = rawOrder['payment'];
    if (raw is Map) return raw.cast<String, dynamic>();
    return _keetaPayment;
  }

  /// Keeta amounts are whole numbers in the smallest unit (4600 = 46.00).
  Map<String, dynamic>? get _keetaPayment {
    final fee = (rawOrder['feeDtl'] as Map?)?['customerFee'];
    if (fee is! Map) return null;
    double major(String key) => ((fee[key] as num?) ?? 0) / 100;
    return {
      'sub_total': major('productPrice'),
      'discount': major('discounts'),
      'delivery_fee': major('shippingFee'),
      'service_fee': major('platformFee'),
      'order_total': major('payTotal'),
    };
  }

  /// Everything the customer saved on this order, as a positive amount.
  /// Keeta: all promotions (`discounts`). HungerStation: the order voucher
  /// plus the per-item promotions.
  double get discountTotal {
    if (rawOrder['payment'] is! Map) {
      return ((payment?['discount'] as num?) ?? 0).abs().toDouble();
    }
    final voucher = ((payment?['discount'] as num?) ?? 0).abs();
    final onItems = items.fold<num>(
      0,
      (sum, i) => sum + ((i['discount'] as num?) ?? 0),
    );
    return (voucher + onItems).toDouble();
  }

  /// Named promotions applied, with what each one took off.
  List<({String name, double amount})> get promotions {
    final result = <({String name, double amount})>[];

    // Keeta
    final keeta = rawOrder['orderPromotionDtlList'];
    if (keeta is List) {
      for (final p in keeta.whereType<Map>()) {
        final name = (p['promotionRuleDesc'] ?? p['typeName'] ?? '').toString();
        final amount = ((p['reduceFee'] as num?) ?? 0) / 100;
        if (name.isNotEmpty && amount > 0) {
          result.add((name: name, amount: amount));
        }
      }
    }

    // HungerStation: item promotions (the order voucher is `payment.discount`,
    // already shown as the Discount row)
    for (final item in items) {
      final promos = item['promotion'];
      if (promos is! List) continue;
      for (final p in promos.whereType<Map>()) {
        final amount = ((p['discount_amount'] as num?) ?? 0).toDouble();
        if (amount > 0) {
          result.add((
            name: '${p['name'] ?? ''} · ${item['name'] ?? ''}',
            amount: amount,
          ));
        }
      }
    }
    return result;
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
    // `updatedAt` changes with every event, so it stands in for the
    // payload: comparing `rawOrder` deeply on each 4s poll would cost
    // O(total payload size) just to learn nothing changed.
    updatedAt,
  ];
}
