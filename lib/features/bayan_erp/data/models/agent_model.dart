import 'package:equatable/equatable.dart';

/// Represents a registered client / agent returned by `GET /getAgent`.
final class AgentModel extends Equatable {
  const AgentModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    this.birthday,
    this.totalPoints,
    required this.gender,
  });

  /// Unique client identifier (`ID`).
  final int id;

  /// Client name (`Name`).
  final String name;

  /// Phone number (`phone`).
  final String phone;

  /// Address (`address`).
  final String address;

  /// Date of birth (`birthday`). May be null if not set.
  final DateTime? birthday;

  /// Loyalty points total (`totalpoint`). Null when programme is inactive.
  final double? totalPoints;

  /// Gender code (`gender`). 1 = Male, 2 = Female, other = Unknown.
  final int gender;

  String get genderLabel => switch (gender) {
        1 => 'Male',
        2 => 'Female',
        _ => '—',
      };

  factory AgentModel.fromJson(Map<String, dynamic> json) => AgentModel(
        id: (json['ID'] as num).toInt(),
        name: (json['Name'] as String? ?? '').trim(),
        phone: json['phone'] as String? ?? '',
        address: json['address'] as String? ?? '',
        birthday: _parseDate(json['birthday'] as String?),
        totalPoints: (json['totalpoint'] as num?)?.toDouble(),
        gender: (json['gender'] as num? ?? 0).toInt(),
      );

  static DateTime? _parseDate(String? raw) {
    if (raw == null) return null;
    final dt = DateTime.tryParse(raw);
    // The API sends 1900-01-01 as a sentinel "no date" value.
    if (dt == null || dt.year <= 1900) return null;
    return dt;
  }

  @override
  List<Object?> get props => [id, name, phone, address, birthday, totalPoints, gender];
}
