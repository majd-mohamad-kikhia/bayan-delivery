import 'package:equatable/equatable.dart';

/// Represents a warehouse / store returned by `GET /getStores`.
final class StoreModel extends Equatable {
  const StoreModel({required this.id, required this.name});

  /// Unique store identifier (`Id`).
  final int id;

  /// Store name (`Name`).
  final String name;

  factory StoreModel.fromJson(Map<String, dynamic> json) => StoreModel(
        id: (json['Id'] as num).toInt(),
        name: (json['Name'] as String? ?? '').trim(),
      );

  @override
  List<Object?> get props => [id, name];
}
