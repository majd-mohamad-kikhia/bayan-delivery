import 'package:equatable/equatable.dart';

/// One row of the local `products` table: an Al-Bayan product and the
/// numbers it has on each delivery platform.
///
/// All numbers are text: Al-Bayan and HungerStation use codes like
/// `BYN-BRD-001`, Keeta numbers are large integers, and text keeps leading
/// zeros and any future format intact.
final class ProductRecord extends Equatable {
  const ProductRecord({
    required this.bayanNum,
    required this.name,
    this.keetaNum,
    this.hungerNum,
    this.careemNum,
  });

  factory ProductRecord.fromRow(Map<String, Object?> row) => ProductRecord(
    bayanNum: row['bayan_num']! as String,
    name: row['name']! as String,
    keetaNum: row['keeta_num'] as String?,
    hungerNum: row['hunger_num'] as String?,
    careemNum: row['careem_num'] as String?,
  );

  /// Al-Bayan product number — unique, the key of the table.
  final String bayanNum;
  final String name;

  /// The product's number on Keeta / HungerStation / Careem; null when it
  /// isn't on that platform.
  final String? keetaNum;
  final String? hungerNum;
  final String? careemNum;

  Map<String, Object?> toRow() => {
    'bayan_num': bayanNum,
    'name': name,
    'keeta_num': keetaNum,
    'hunger_num': hungerNum,
    'careem_num': careemNum,
  };

  /// The number on [platformId] (`keeta`, `hungerstation`, `careem`).
  String? numFor(String platformId) => switch (platformId) {
    'keeta' => keetaNum,
    'hungerstation' => hungerNum,
    'careem' => careemNum,
    _ => null,
  };

  @override
  List<Object?> get props => [bayanNum, name, keetaNum, hungerNum, careemNum];
}
