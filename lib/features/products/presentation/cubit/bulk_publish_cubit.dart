import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/listing_models.dart';
import '../../data/models/product_model.dart';
import '../../data/repositories/product_publish_repository.dart';
import 'product_registry_cubit.dart';

/// What the bulk run fills in for fields a quick add can't ask per product.
final class BulkDefaults extends Equatable {
  const BulkDefaults({
    required this.keetaCategory,
    this.hungerStationCategory = '',
    this.barcodeFromSku = true,
  });

  /// Keeta needs a category; it is created on Keeta when missing.
  final String keetaCategory;

  /// HungerStation's must already exist there; blank sends none.
  final String hungerStationCategory;

  /// HungerStation requires a barcode and the ERP has none: send the product
  /// number instead. HungerStation may refuse it — that shows as a failure.
  final bool barcodeFromSku;

  @override
  List<Object?> get props => [
    keetaCategory,
    hungerStationCategory,
    barcodeFromSku,
  ];
}

enum BulkStatus { idle, running, done }

final class BulkFailure extends Equatable {
  const BulkFailure(this.productName, this.platformId, this.outcome);

  final String productName;
  final String platformId;
  final PublishOutcome outcome;

  @override
  List<Object?> get props => [productName, platformId, outcome];
}

final class BulkPublishState extends Equatable {
  const BulkPublishState({
    this.status = BulkStatus.idle,
    this.total = 0,
    this.done = 0,
    this.added = 0,
    this.skipped = 0,
    this.failures = const [],
    this.cancelled = false,
  });

  final BulkStatus status;

  /// Products being processed.
  final int total;
  final int done;

  /// Platform listings that went live (or are processing).
  final int added;

  /// Products already on every platform, left alone.
  final int skipped;
  final List<BulkFailure> failures;
  final bool cancelled;

  double get progress => total == 0 ? 0 : done / total;

  BulkPublishState copyWith({
    BulkStatus? status,
    int? total,
    int? done,
    int? added,
    int? skipped,
    List<BulkFailure>? failures,
    bool? cancelled,
  }) => BulkPublishState(
    status: status ?? this.status,
    total: total ?? this.total,
    done: done ?? this.done,
    added: added ?? this.added,
    skipped: skipped ?? this.skipped,
    failures: failures ?? this.failures,
    cancelled: cancelled ?? this.cancelled,
  );

  @override
  List<Object?> get props => [
    status,
    total,
    done,
    added,
    skipped,
    failures,
    cancelled,
  ];
}

/// Adds many Al-Bayan products to every platform they're not on yet.
///
/// - Products already on a platform are never re-sent to it.
/// - [concurrency] products run at once, each one to its platforms in
///   parallel; what each platform needs besides the product (shop, categories,
///   taxonomy) is loaded once up front and cached by the repository.
/// - Every success is written to the registry as it happens, so a run that
///   is cancelled or crashes keeps what it finished.
class BulkPublishCubit extends Cubit<BulkPublishState> {
  BulkPublishCubit({
    required ProductPublishRepository repository,
    required ProductRegistryCubit registry,
    this.concurrency = 4,
  }) : _repository = repository,
       _registry = registry,
       super(const BulkPublishState());

  final ProductPublishRepository _repository;
  final ProductRegistryCubit _registry;
  final int concurrency;

  bool _cancelRequested = false;

  /// Platforms [productSku] still needs.
  List<String> missingPlatforms(String productSku) => [
    for (final id in ProductPublishRepository.supportedPlatforms)
      if (!_registry.state.isRegistered(productSku, id)) id,
  ];

  void cancel() {
    _cancelRequested = true;
    if (state.status == BulkStatus.running) {
      emit(state.copyWith(cancelled: true));
    }
  }

  Future<void> run(List<ProductModel> products, BulkDefaults defaults) async {
    if (state.status == BulkStatus.running) return;
    _cancelRequested = false;

    final work = <(ProductModel, List<String>)>[];
    var skipped = 0;
    for (final product in products) {
      final missing = missingPlatforms(product.sku);
      if (missing.isEmpty) {
        skipped++;
      } else {
        work.add((product, missing));
      }
    }
    emit(
      BulkPublishState(
        status: BulkStatus.running,
        total: work.length,
        skipped: skipped,
      ),
    );

    ProductPublishRepository.supportedPlatforms.forEach(_repository.prewarm);

    final queue = work.iterator;
    Future<void> worker() async {
      while (!_cancelRequested && !isClosed) {
        final next = queue.moveNext() ? queue.current : null;
        if (next == null) return;
        await _publishOne(next.$1, next.$2, defaults);
      }
    }

    await Future.wait([for (var i = 0; i < concurrency; i++) worker()]);
    if (!isClosed) emit(state.copyWith(status: BulkStatus.done));
  }

  Future<void> _publishOne(
    ProductModel product,
    List<String> platforms,
    BulkDefaults defaults,
  ) async {
    final content = ListingContent.fromProduct(product).copyWith(
      barcode: defaults.barcodeFromSku && product.sku.isNotEmpty
          ? product.sku
          : product.barcode ?? '',
    );

    final outcomes = await Future.wait([
      for (final id in platforms)
        _repository
            .publish(content, _listing(id, product, defaults))
            .then((outcome) => (id, outcome)),
    ]);
    if (isClosed) return;

    final marks = <RegistryMark>[];
    final failures = <BulkFailure>[];
    for (final (id, outcome) in outcomes) {
      if (outcome.phase.isDone) {
        marks.add(
          RegistryMark(
            product.sku,
            product.name,
            id,
            outcome.platformNum ?? product.sku,
            priceMinor: (product.salePrice * 100).round(),
          ),
        );
      } else {
        failures.add(BulkFailure(product.name, id, outcome));
      }
    }
    if (marks.isNotEmpty) await _registry.markAll(marks);
    if (isClosed) return;

    emit(
      state.copyWith(
        done: state.done + 1,
        added: state.added + marks.length,
        failures: failures.isEmpty ? null : [...state.failures, ...failures],
      ),
    );
  }

  static PlatformListing _listing(
    String platformId,
    ProductModel product,
    BulkDefaults defaults,
  ) {
    final base = PlatformListing.initialFor(platformId, product);
    return switch (base) {
      // The product's own ERP category wins; the dialog value is the fallback.
      KeetaListing() => base.copyWith(
        category: product.category.trim().isNotEmpty
            ? product.category.trim()
            : defaults.keetaCategory.trim(),
      ),
      HsListing() => base.copyWith(
        category: defaults.hungerStationCategory.trim(),
      ),
    };
  }
}
