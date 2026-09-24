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
}
