import 'package:equatable/equatable.dart';

/// Represents a salesman / delivery agent returned by `GET /getSalesman`.
final class SalesmanModel extends Equatable {
  const SalesmanModel({
    required this.id,
    required this.name,
    required this.phone,
  });

  /// Unique salesman identifier (`Id`).
  final int id;

  /// Salesman name (`Name`).
  final String name;

  /// Phone number (`Phone`).
  final String phone;

  factory SalesmanModel.fromJson(Map<String, dynamic> json) => SalesmanModel(
        id: (json['Id'] as num).toInt(),
        name: (json['Name'] as String? ?? '').trim(),
        phone: json['Phone'] as String? ?? '',
      );

  @override
  List<Object?> get props => [id, name, phone];
}
