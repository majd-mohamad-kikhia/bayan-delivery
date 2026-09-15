import 'package:equatable/equatable.dart';

class KeetaTimePeriod extends Equatable {
  const KeetaTimePeriod({required this.startTime, required this.endTime});

  final String startTime;
  final String endTime;

  factory KeetaTimePeriod.fromJson(Map<String, dynamic> json) {
    return KeetaTimePeriod(
      startTime: json['startTime']?.toString() ?? '',
      endTime: json['endTime']?.toString() ?? '',
    );
  }

  @override
  List<Object?> get props => [startTime, endTime];
}

class KeetaWeekDayHours extends Equatable {
  const KeetaWeekDayHours({
    required this.dayOfWeek,
    required this.timePeriods,
  });

  final String dayOfWeek;
  final List<KeetaTimePeriod> timePeriods;

  factory KeetaWeekDayHours.fromJson(Map<String, dynamic> json) {
    final periods = (json['timePeriods'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => KeetaTimePeriod.fromJson(e.cast<String, dynamic>()))
        .toList();
    return KeetaWeekDayHours(
      dayOfWeek: json['dayOfWeek']?.toString() ?? '',
      timePeriods: periods,
    );
  }

  @override
  List<Object?> get props => [dayOfWeek, timePeriods];
}

class KeetaShopStatusModel extends Equatable {
  const KeetaShopStatusModel({
    required this.shopId,
    required this.status,
    required this.weekHours,
    this.merchantSourceAppId,
  });

  final String shopId;

  /// AVAILABLE or UNAVAILABLE
  final String status;
  final List<KeetaWeekDayHours> weekHours;
  final int? merchantSourceAppId;

  bool get isAvailable => status.toUpperCase() == 'AVAILABLE';

  factory KeetaShopStatusModel.fromJson(Map<String, dynamic> json) {
    final services = json['services'] as List? ?? const [];
    final weekHours = <KeetaWeekDayHours>[];

    for (final service in services.whereType<Map>()) {
      final hours = service['serviceHours'] as Map?;
      final week = hours?['weekHours'] as List? ?? const [];
      for (final day in week.whereType<Map>()) {
        weekHours.add(KeetaWeekDayHours.fromJson(day.cast<String, dynamic>()));
      }
    }

    return KeetaShopStatusModel(
      shopId: json['shopId']?.toString() ?? '',
      status: json['status']?.toString() ?? 'UNAVAILABLE',
      weekHours: weekHours,
      merchantSourceAppId: (json['merchantSourceAppId'] as num?)?.toInt(),
    );
  }

  @override
  List<Object?> get props => [shopId, status, weekHours, merchantSourceAppId];
}
