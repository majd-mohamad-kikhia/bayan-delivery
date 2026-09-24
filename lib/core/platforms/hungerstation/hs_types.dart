/// Outlet status values (`status` field).
enum HsOutletStatus {
  open('OPEN'),
  closedToday('CLOSED_TODAY'),
  closedUntil('CLOSED_UNTIL'),

  /// Read-only: closed with no end date. Can't be sent as an update.
  closed('CLOSED'),

  /// Acknowledges a scheduled check-in (only if the feature is enabled).
  checkIn('CHECKIN');

  const HsOutletStatus(this.wire);

  final String wire;

  bool get isClosing => this == closedToday || this == closedUntil;

  static HsOutletStatus? fromWire(String? value) {
    for (final status in values) {
      if (status.wire == value) return status;
    }
    return null;
  }
}

/// `closed_reason` — required for every closing update.
enum HsClosedReason {
  tooBusyNoDrivers('TOO_BUSY_NO_DRIVERS'),
  tooBusyKitchen('TOO_BUSY_KITCHEN'),
  updatesInMenu('UPDATES_IN_MENU'),
  technicalProblem('TECHNICAL_PROBLEM'),
  closed('CLOSED'),
  other('OTHER'),
  badWeather('BAD_WEATHER'),
  holidaySpecialDay('HOLIDAY_SPECIAL_DAY');

  const HsClosedReason(this.wire);

  final String wire;
}

/// One SKU change for the catalog update endpoint. Needs at least one of
/// [price], [active], [quantity]. The final active state also depends on
/// the quantity vs. the sales buffer configured on HungerStation.
final class HsProductUpdate {
  const HsProductUpdate({
    required this.sku,
    this.price,
    this.active,
    this.quantity,
    this.maximumSalesQuantity,
  });

  final String sku;
  final num? price;
  final bool? active;
  final int? quantity;

  /// Maximum units per order.
  final int? maximumSalesQuantity;

  bool get hasChange =>
      price != null ||
      active != null ||
      quantity != null ||
      maximumSalesQuantity != null;

  Map<String, Object> toJson() => {
    'sku': sku,
    'price': ?price,
    'active': ?active,
    'quantity': ?quantity,
    'maximum_sales_quantity': ?maximumSalesQuantity,
  };
}

/// An async catalog / promotion job.
final class HsJob {
  const HsJob({required this.id, required this.status, this.raw = const {}});

  factory HsJob.fromJson(Object? json) {
    final map = json is Map<String, dynamic> ? json : const <String, dynamic>{};
    return HsJob(
      id: (map['job_id'] ?? map['id'])?.toString() ?? '',
      status: (map['job_status'] ?? map['status'])?.toString() ?? '',
      raw: map,
    );
  }

  final String id;

  /// `QUEUED`, `IN_PROGRESS`, `COMPLETED` or `FAILED`.
  final String status;
  final Map<String, dynamic> raw;

  bool get isCompleted => status == 'COMPLETED';
  bool get isFailed => status == 'FAILED';
  bool get isFinished => isCompleted || isFailed;

  /// Why HungerStation refused [sku] in this job, or null if it didn't. A
  /// `COMPLETED` job can still reject individual products — the reasons are
  /// in `result.item_level_feedback[].rejection_reasons` (e.g. `images: poor
  /// quality`), and SKUs submitted before land in `result.duplicated_products`.
  String? rejectionFor(String sku) {
    final result = raw['result'];
    if (result is! Map) return null;

    final duplicates = result['duplicated_products'];
    if (duplicates is List &&
        duplicates.any((entry) => entry == sku || '$entry'.endsWith(':$sku'))) {
      return 'SKU $sku was already submitted';
    }

    final items = result['item_level_feedback'];
    if (items is! List) return null;
    for (final item in items.whereType<Map>()) {
      if ('${item['sku']}' != sku) continue;
      final reasons = [
        for (final reason
            in (item['rejection_reasons'] as List? ?? const [])
                .whereType<Map>())
          [
            reason['rejected_data'],
            reason['rejected_reason'],
          ].whereType<String>().join(': '),
      ].where((text) => text.isNotEmpty).toList();
      if (reasons.isNotEmpty) return reasons.join(' · ');
      final status = item['status'];
      if (status is String && status.toLowerCase().contains('fail')) {
        return status;
      }
    }
    return null;
  }
}

/// Unit of a HungerStation weight value (`*_unit`, defaults to KG).
enum HsWeightUnit {
  kg('KG'),
  g('G');

  const HsWeightUnit(this.wire);

  final String wire;
}

/// A weight with its unit, for products sold by weight.
final class HsWeight {
  const HsWeight(this.value, [this.unit = HsWeightUnit.kg]);

  final double value;
  final HsWeightUnit unit;

  @override
  bool operator ==(Object other) =>
      other is HsWeight && other.value == value && other.unit == unit;

  @override
  int get hashCode => Object.hash(value, unit);
}
