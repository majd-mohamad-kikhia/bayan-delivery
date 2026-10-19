import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/product_record.dart';
import '../../data/repositories/product_records_repository.dart';
import '../../data/repositories/product_sync_repository.dart';

final class ProductRegistryState extends Equatable {
  const ProductRegistryState({this.records = const {}, this.loaded = false});

  /// Al-Bayan product number → what it has on each platform.
  final Map<String, ProductRecord> records;
  final bool loaded;

  ProductRecord? recordOf(String bayanNum) => records[bayanNum];

  bool isRegistered(String bayanNum, String platformId) =>
      records[bayanNum]?.numFor(platformId) != null;

  /// On every supported platform.
  bool isOnAll(String bayanNum, Iterable<String> platformIds) =>
      platformIds.every((id) => isRegistered(bayanNum, id));

  @override
  List<Object?> get props => [records, loaded];
}

/// Which Al-Bayan products are already on which delivery platform.
///
/// Backed by the local `products` table and mirrored in memory, so the list
/// can ask "is this row registered?" for every row without touching the
/// database; each row listens only to its own record.
class ProductRegistryCubit extends Cubit<ProductRegistryState> {
  ProductRegistryCubit(this._repository, [this._sync])
    : super(const ProductRegistryState());

  final ProductRecordsRepository _repository;

  /// Where the price sent with each publish is remembered, so a later change
  /// in Al-Bayan can be told apart from the price already on the platform.
  final ProductSyncRepository? _sync;

  Future<void> load() async {
    final records = await _repository.all();
    if (!isClosed) emit(ProductRegistryState(records: records, loaded: true));
  }

  /// The platform answered with everything it lists: products recorded as
  /// being there that it no longer has are marked as not there. Returns how
  /// many were cleared.
  Future<int> forgetUnlisted(String platformId, Set<String> stillListed) async {
    final cleared = await _repository.clearUnlisted(platformId, stillListed);
    if (cleared > 0) await load();
    return cleared;
  }

  /// A product is now (or still) on [platformId] under [platformNum].
  Future<void> markPublished({
    required String bayanNum,
    required String name,
    required String platformId,
    required String platformNum,
    int? priceMinor,
  }) => markAll([
    RegistryMark(
      bayanNum,
      name,
      platformId,
      platformNum,
      priceMinor: priceMinor,
    ),
  ]);

  /// Many marks in one transaction and one state change — for bulk runs and
  /// the platform sync.
  Future<void> markAll(Iterable<RegistryMark> marks) async {
    final merged = <String, ProductRecord>{};
    for (final mark in marks) {
      final key = mark.bayanNum.trim();
      final base = merged[key] ?? state.records[key];
      merged[key] = _with(base, mark);
    }
    if (merged.isEmpty) return;
    // A number the platform just issued wins over a stale one stored for
    // another product, so the stored rows can change beyond [merged].
    await _repository.saveAllClaiming(merged.values);
    // The price Al-Bayan had when it went to the platform is the baseline the
    // price sync compares against.
    final sync = _sync;
    if (sync != null) {
      await sync.save([
        for (final mark in marks)
          if (mark.priceMinor != null)
            (
              bayanNum: mark.bayanNum.trim(),
              platform: mark.platformId,
              values: SyncedValues(
                priceMinor: mark.priceMinor!,
                name: merged[mark.bayanNum.trim()]!.name,
              ),
            ),
      ]);
    }
    final records = await _repository.all();
    if (isClosed) return;
    emit(ProductRegistryState(records: records, loaded: true));
  }

  static ProductRecord _with(ProductRecord? base, RegistryMark mark) {
    final name = mark.name.trim().isEmpty ? mark.bayanNum : mark.name.trim();
    final keeta = mark.platformId == 'keeta'
        ? mark.platformNum
        : base?.keetaNum;
    final hunger = mark.platformId == 'hungerstation'
        ? mark.platformNum
        : base?.hungerNum;
    final careem = mark.platformId == 'careem'
        ? mark.platformNum
        : base?.careemNum;
    return ProductRecord(
      bayanNum: mark.bayanNum.trim(),
      // Keep a real name over a placeholder that only repeats the number.
      name: base != null && base.name != base.bayanNum && name == mark.bayanNum
          ? base.name
          : name,
      keetaNum: keeta,
      hungerNum: hunger,
      careemNum: careem,
    );
  }
}

final class RegistryMark extends Equatable {
  const RegistryMark(
    this.bayanNum,
    this.name,
    this.platformId,
    this.platformNum, {
    this.priceMinor,
  });

  final String bayanNum;
  final String name;
  final String platformId;
  final String platformNum;

  /// Al-Bayan's price (minor units) at the moment it was sent, if known.
  final int? priceMinor;

  @override
  List<Object?> get props => [
    bayanNum,
    name,
    platformId,
    platformNum,
    priceMinor,
  ];
}
