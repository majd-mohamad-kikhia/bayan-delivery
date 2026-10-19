import 'package:equatable/equatable.dart';

/// One selectable extra ("more potato") inside an [AddOnGroup].
final class AddOnOption extends Equatable {
  const AddOnOption({
    required this.sku,
    required this.name,
    required this.price,
  });

  /// Al-Bayan id — the option's `openItemCode` on the platform.
  final String sku;
  final String name;
  final double price;

  @override
  List<Object?> get props => [sku, name, price];
}

/// A set of extras offered with a product — a Keeta choice group.
final class AddOnGroup extends Equatable {
  const AddOnGroup({required this.name, required this.options});

  final String name;
  final List<AddOnOption> options;

  @override
  List<Object?> get props => [name, options];
}

class ProductModel {
  const ProductModel({
    required this.id,
    required this.sku,
    required this.name,
    required this.nameAr,
    required this.category,
    required this.unit,
    required this.salePrice,
    required this.costPrice,
    required this.stockQty,
    required this.isActive,
    this.barcode,
    this.taxRate = 15,
    this.addOnGroups = const [],
  });

  final String id;
  final String sku;
  final String name;
  final String nameAr;
  final String category;
  final String unit;
  final double salePrice;
  final double costPrice;
  final double stockQty;
  final bool isActive;
  final String? barcode;
  final double taxRate;

  /// Extras offered with this product (Keeta choice groups).
  final List<AddOnGroup> addOnGroups;
}
