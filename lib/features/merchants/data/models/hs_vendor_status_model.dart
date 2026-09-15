import 'package:equatable/equatable.dart';

/// HungerStation vendor open/close status (section 8).
class HsVendorStatusModel extends Equatable {
  const HsVendorStatusModel({
    required this.chainId,
    required this.vendorId,
    required this.status,
    this.closedReason,
    this.closedUntil,
  });

  final String chainId;
  final String vendorId;

  /// OPEN | CLOSED_TODAY | CLOSED_UNTIL | CLOSED | CHECKIN
  final String status;
  final String? closedReason;
  final DateTime? closedUntil;

  bool get isOpen => status.toUpperCase() == 'OPEN';

  factory HsVendorStatusModel.fromJson(Map<String, dynamic> json) {
    DateTime? until;
    final rawUntil = json['closed_until'];
    if (rawUntil is String && rawUntil.isNotEmpty) {
      until = DateTime.tryParse(rawUntil);
    }

    return HsVendorStatusModel(
      chainId: json['chainId']?.toString() ?? '',
      vendorId: json['vendorId']?.toString() ?? '',
      status: json['status']?.toString() ?? 'CLOSED',
      closedReason: json['closed_reason']?.toString(),
      closedUntil: until,
    );
  }

  @override
  List<Object?> get props => [chainId, vendorId, status, closedReason, closedUntil];
}

/// Allowed closed_reason values for HungerStation status updates.
abstract final class HsClosedReasons {
  static const values = [
    'TOO_BUSY_NO_DRIVERS',
    'TOO_BUSY_KITCHEN',
    'UPDATES_IN_MENU',
    'TECHNICAL_PROBLEM',
    'CLOSED',
    'OTHER',
    'BAD_WEATHER',
    'HOLIDAY_SPECIAL_DAY',
  ];

  static String label(String value) {
    switch (value) {
      case 'TOO_BUSY_NO_DRIVERS':
        return 'Too busy — no drivers';
      case 'TOO_BUSY_KITCHEN':
        return 'Too busy — kitchen';
      case 'UPDATES_IN_MENU':
        return 'Menu updates';
      case 'TECHNICAL_PROBLEM':
        return 'Technical problem';
      case 'CLOSED':
        return 'Closed';
      case 'OTHER':
        return 'Other';
      case 'BAD_WEATHER':
        return 'Bad weather';
      case 'HOLIDAY_SPECIAL_DAY':
        return 'Holiday / special day';
      default:
        return value;
    }
  }
}
