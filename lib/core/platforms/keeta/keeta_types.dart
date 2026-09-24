import '../common/platform_api_exception.dart';

/// `cancelCode` for `/order/cancel`.
enum KeetaCancelCode {
  /// Requires a `cancelReason` text.
  other(500000),
  insufficientIngredients(500001),
  storeTemporarilyClosed(500002),
  staffShortage(500003);

  const KeetaCancelCode(this.code);

  final int code;

  bool get requiresReason => this == other;
}

/// `rejectCode` for `/order/reject` (refusing a customer refund request).
enum KeetaRefundRejectCode {
  /// Requires a `rejectReason` text.
  other(100000),
  mealAlreadyPrepared(100001),
  deliveryAlreadyStarted(100002);

  const KeetaRefundRejectCode(this.code);

  final int code;

  bool get requiresReason => this == other;
}

/// `partRefundType` for `/order/refund/part/apply`.
enum KeetaPartialRefundReason {
  /// Requires a `partRefundReason` text.
  other(200000),
  slowPreparation(200001),
  insufficientIngredients(200002),
  missingOrIncompleteDelivery(200003),
  wrongItemPrepared(200004);

  const KeetaPartialRefundReason(this.code);

  final int code;

  bool get requiresReason => this == other;
}

/// Webhook `eventId`s Keeta pushes to the backend.
enum KeetaWebhookEvent {
  orderCreated(1001),
  orderAccepted(1002),
  orderCompleted(1003),
  orderCancelled(1004),
  refundRequested(1005),
  deliveryStatusUpdated(1006),
  partialRefundRequested(1007),
  shopBusinessHoursChanged(1101),
  shopStatusChanged(1102),
  productPicturesBound(1201);

  const KeetaWebhookEvent(this.id);

  final int id;

  static KeetaWebhookEvent? fromId(int? id) {
    for (final event in values) {
      if (event.id == id) return event;
    }
    return null;
  }
}

/// Store status codes in Keeta store payloads and webhook 1102.
abstract final class KeetaShopStatus {
  /// Orders accepted while also inside business hours.
  static const int operating = 3;

  /// Hidden from customers; orders blocked regardless of hours.
  static const int suspended = 4;
}

/// Keeta `code` ranges (API Request Protocol §3).
abstract final class KeetaErrorCodes {
  /// e.g. 115000110 "The sig calculation error…".
  static bool isSignatureOrToken(int code) =>
      code >= 115000100 && code <= 115000199;

  static bool isBusinessParameter(int code) =>
      code >= 115000200 && code <= 115000399;

  static bool isServerError(int code) => code >= 315000100 && code <= 315000199;

  static PlatformErrorKind kindOf(int code) {
    if (isSignatureOrToken(code)) return PlatformErrorKind.unauthorized;
    if (isServerError(code)) return PlatformErrorKind.serverError;
    return PlatformErrorKind.rejected;
  }
}

/// Map keys of `businessHourOfTheWeek`.
enum KeetaWeekday { mon, tue, wed, thu, fri, sat, sun }

/// One opening window. Integers in the same unit `/effective/get` returns
/// (Keeta's sample uses `3000`–`17400`); pass through what you read.
final class KeetaTimeRange {
  const KeetaTimeRange(this.startTime, this.endTime);

  /// Whole-day closure: both 0.
  static const closed = KeetaTimeRange(0, 0);

  final int startTime;
  final int endTime;

  bool get isClosed => startTime == 0 && endTime == 0;

  Map<String, int> toJson() => {'startTime': startTime, 'endTime': endTime};
}

/// Exceptional hours (holidays, events) overriding the weekly schedule.
final class KeetaSpecialHours {
  const KeetaSpecialHours({
    required this.startDate,
    required this.endDate,
    required this.hours,
  });

  final DateTime startDate;
  final DateTime endDate;
  final List<KeetaTimeRange> hours;

  Map<String, Object> toJson() => {
    'startDate': startDate.millisecondsSinceEpoch,
    'endDate': endDate.millisecondsSinceEpoch,
    'businessHour': [for (final range in hours) range.toJson()],
  };
}

/// A line of a partial refund.
final class KeetaRefundItem {
  const KeetaRefundItem({
    required this.orderProductId,
    required this.refundCount,
  });

  final int orderProductId;
  final int refundCount;

  Map<String, int> toJson() => {
    'orderProductId': orderProductId,
    'refundCount': refundCount,
  };
}

/// Allergen declarations for a SKU (`allergens`). Required in Saudi Arabia
/// (SFDA) — Menu API Integration Guide §4.4.
enum KeetaAllergen {
  celery('Celery'),
  sulfite('Sulfite'),
  milk('Milk'),
  nuts('Nuts'),
  peanuts('Peanuts'),
  fish('Fish'),
  grains('Grains'),
  soybeans('Soybeans'),
  lupins('Lupins'),
  molluscs('Molluscs'),
  sesameSeeds('Sesame seeds'),
  mustard('Mustard'),
  eggs('Eggs'),
  crustaceans('Crustaceans');

  const KeetaAllergen(this.wire);

  /// Exact string Keeta expects — also a fine display label.
  final String wire;
}

/// Keys of a SKU's `nutritionalInfo` (positive integers) — Menu API
/// Integration Guide §4.3.
enum KeetaNutrient {
  calories('calories_kcal', 'Calories', 'kcal'),
  protein('protein_g', 'Protein', 'g'),
  totalFat('totalFat_g', 'Total fat', 'g'),
  saturatedFat('saturatedFat_g', 'Saturated fat', 'g'),
  transFat('transFat_g', 'Trans fat', 'g'),
  cholesterol('cholesterol_mg', 'Cholesterol', 'mg'),
  carbohydrates('carbohydrates_g', 'Carbohydrates', 'g'),
  fiber('fiber_g', 'Fiber', 'g'),
  totalSugar('totalSugar_g', 'Total sugars', 'g'),
  addedSugar('addedSugar_g', 'Added sugar', 'g'),
  salt('salt_g', 'Salt', 'g'),
  sodium('sodium_mg', 'Sodium', 'mg');

  const KeetaNutrient(this.wire, this.label, this.unit);

  final String wire;
  final String label;
  final String unit;
}

/// One daily selling window, e.g. breakfast only. Sent as
/// `availableTime: {code: 1, values: ["06:00-11:00" × 7]}`.
final class KeetaSellingHours {
  const KeetaSellingHours(this.startMinute, this.endMinute);

  /// Parses `HH:mm` pairs; null when either is invalid or they're equal.
  static KeetaSellingHours? tryParse(String start, String end) {
    final from = _minutes(start);
    final to = _minutes(end);
    if (from == null || to == null || from == to) return null;
    return KeetaSellingHours(from, to);
  }

  final int startMinute;
  final int endMinute;

  String get start => _format(startMinute);
  String get end => _format(endMinute);

  /// `06:00-11:00`
  String get wire => '$start-$end';

  static int? _minutes(String text) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(text.trim());
    if (match == null) return null;
    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    if (hour > 23 || minute > 59) return null;
    return hour * 60 + minute;
  }

  static String _format(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is KeetaSellingHours &&
      other.startMinute == startMinute &&
      other.endMinute == endMinute;

  @override
  int get hashCode => Object.hash(startMinute, endMinute);
}
