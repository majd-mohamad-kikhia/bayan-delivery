import 'package:equatable/equatable.dart';

/// Represents an account / customer returned by `GET /getCustomers`.
final class CustomerModel extends Equatable {
  const CustomerModel({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.balance,
    required this.groupId,
    required this.priceKind,
  });

  /// Unique account identifier (`Id`).
  final int id;

  /// Account name (`Name`).
  final String name;

  /// Address (`Address`).
  final String address;

  /// Phone number (`Phone`).
  final String phone;

  /// Current balance (`Balance`).
  final double balance;

  /// Group / salesman id (`Id_group`). 0 means ungrouped.
  final int groupId;

  /// Pricing tier applied to this account (`PriceKind`).
  final String priceKind;

  factory CustomerModel.fromJson(Map<String, dynamic> json) => CustomerModel(
        id: (json['Id'] as num).toInt(),
        name: (json['Name'] as String? ?? '').trim(),
        address: json['Address'] as String? ?? '',
        phone: json['Phone'] as String? ?? '',
        balance: (json['Balance'] as num? ?? 0).toDouble(),
        groupId: (json['Id_group'] as num? ?? 0).toInt(),
        priceKind: json['PriceKind'] as String? ?? '',
      );

  @override
  List<Object?> get props => [id, name, address, phone, balance, groupId, priceKind];
}
