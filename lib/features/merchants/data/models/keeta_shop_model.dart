import 'package:equatable/equatable.dart';

class KeetaShopModel extends Equatable {
  const KeetaShopModel({
    required this.id,
    required this.name,
    this.address,
    this.longitude,
    this.latitude,
  });

  final int id;
  final String name;
  final String? address;
  final String? longitude;
  final String? latitude;

  factory KeetaShopModel.fromJson(Map<String, dynamic> json) {
    return KeetaShopModel(
      id: (json['id'] as num).toInt(),
      name: json['name']?.toString() ?? 'Shop ${json['id']}',
      address: json['address']?.toString(),
      longitude: json['longitude']?.toString(),
      latitude: json['latitude']?.toString(),
    );
  }

  @override
  List<Object?> get props => [id, name, address, longitude, latitude];
}
