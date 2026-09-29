import 'package:equatable/equatable.dart';

enum ErpStockLevel { available, low, out }

/// Represents a product returned by `GET /getProducts`.
final class ErpProductModel extends Equatable {
  const ErpProductModel({
    required this.id,
    required this.name,
    required this.shortName,
    required this.quantity,
    required this.price1,
    required this.price2,
    required this.price3,
    required this.price4,
    required this.price5,
    required this.currency,
    required this.parentId,
  });

  /// Quantities below this (but above zero) are reported as [ErpStockLevel.low].
  static const double lowStockThreshold = 10;

  /// Unique product identifier (`Id`).
  final int id;

  /// Product name (`Name`).
  final String name;

  /// Short / scientific name (`SName`).
  final String shortName;

  /// Available stock quantity (`Quantity`).
  final double quantity;

  /// Price tier 1–5 (`Price1`…`Price5`).
  final double price1;
  final double price2;
  final double price3;
  final double price4;
  final double price5;

  /// Currency code (`CURRENCY`). 0 = default.
  final int currency;

  /// Parent group identifier (`parent`).
  final int parentId;

  List<double> get priceTiers => [price1, price2, price3, price4, price5];

  /// Index of the first non-zero price tier, or -1 when the product is unpriced.
  int get primaryTierIndex => priceTiers.indexWhere((p) => p > 0);

  double get primaryPrice {
    final index = primaryTierIndex;
    return index < 0 ? 0 : priceTiers[index];
  }

  ErpStockLevel get stockLevel {
    if (quantity <= 0) return ErpStockLevel.out;
    if (quantity < lowStockThreshold) return ErpStockLevel.low;
    return ErpStockLevel.available;
  }

  /// [query] must already be trimmed and lower-cased.
  bool matches(String query) =>
      query.isEmpty ||
      name.toLowerCase().contains(query) ||
      shortName.toLowerCase().contains(query) ||
      '$id'.contains(query);

  factory ErpProductModel.fromJson(Map<String, dynamic> json) => ErpProductModel(
        id: (json['Id'] as num).toInt(),
        name: (json['Name'] as String? ?? '').trim(),
        shortName: (json['SName'] as String? ?? '').trim(),
        quantity: (json['Quantity'] as num? ?? 0).toDouble(),
        price1: (json['Price1'] as num? ?? 0).toDouble(),
        price2: (json['Price2'] as num? ?? 0).toDouble(),
        price3: (json['Price3'] as num? ?? 0).toDouble(),
        price4: (json['Price4'] as num? ?? 0).toDouble(),
        price5: (json['Price5'] as num? ?? 0).toDouble(),
        currency: (json['CURRENCY'] as num? ?? 0).toInt(),
        parentId: (json['parent'] as num? ?? 0).toInt(),
      );

  @override
  List<Object?> get props =>
      [id, name, shortName, quantity, price1, price2, price3, price4, price5, currency, parentId];
}
