import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/listing_models.dart';
import '../../data/models/product_model.dart';
import '../../data/repositories/product_publish_repository.dart';
import 'publish_product_state.dart';

final class PublishProductCubit extends Cubit<PublishProductState> {
  PublishProductCubit({
    required ProductModel product,
    required ProductPublishRepository repository,
  }) : _repository = repository,
       super(
         PublishProductState(
           product: product,
           content: ListingContent.fromProduct(product),
           platforms: {
             for (final id in ProductPublishRepository.supportedPlatforms)
               id: PlatformPublishDraft(
                 listing: PlatformListing.initialFor(id, product),
               ),
           },
         ),
       );

  final ProductPublishRepository _repository;

  /// Category suggestions for [platformId] (cached by the repository).
  Future<List<String>> categoryNames(String platformId) =>
      _repository.categoryNames(platformId);

  void togglePlatform(String platformId, bool enabled) {
    final current = state.platforms[platformId];
    if (current == null) return;
    // Load what this platform needs while the user fills the form.
    if (enabled) _repository.prewarm(platformId);
    _put(current.copyWith(enabled: enabled), clearError: true);
  }

  /// Edits the names / descriptions / images / barcode sent to every platform.
  void updateContent(ListingContent Function(ListingContent content) change) {
    emit(state.copyWith(content: change(state.content)));
  }

  /// Edits one platform's settings. [change] receives that platform's own
  /// listing type (`KeetaListing`, `HsListing`).
  void updateListing<T extends PlatformListing>(
    String platformId,
    T Function(T listing) change,
  ) {
    final current = state.platforms[platformId];
    if (current == null || current.listing is! T) return;
    _put(current.copyWith(listing: change(current.listing as T)));
  }

  void selectAllPlatforms() {
    state.platforms.keys.forEach(_repository.prewarm);
    emit(
      state.copyWith(
        platforms: {
          for (final e in state.platforms.entries)
            e.key: e.value.copyWith(enabled: true),
        },
        clearError: true,
      ),
    );
  }

  void clearPlatforms() {
    emit(
      state.copyWith(
        platforms: {
          for (final e in state.platforms.entries)
            e.key: e.value.copyWith(enabled: false),
        },
      ),
    );
  }

  /// Publishes to every selected platform **in parallel**; each card
  /// updates the moment its own platform answers. Platforms already live
  /// are skipped, so after a partial failure the same button retries only
  /// what failed.
  Future<void> submit() async {
    if (state.status == PublishProductStatus.submitting) return;

    final targets = state.platforms.values
        .where((p) => p.needsPublish)
        .toList();
    if (targets.isEmpty) {
      emit(
        state.copyWith(
          status: PublishProductStatus.failure,
          errorMessage: 'Select at least one platform',
        ),
      );
      emit(state.copyWith(status: PublishProductStatus.editing));
      return;
    }

    final content = state.content;
    emit(
      state.copyWith(
        status: PublishProductStatus.submitting,
        platforms: {
          for (final e in state.platforms.entries)
            e.key: e.value.needsPublish
                ? e.value.copyWith(phase: PublishPhase.publishing)
                : e.value,
        },
        clearError: true,
      ),
    );

    await Future.wait([
      for (final draft in targets)
        _repository
            .publish(content, draft.listing)
            .then((outcome) => _record(draft.platformId, outcome)),
    ]);
    if (isClosed) return;

    final failed = state.platforms.values
        .where((p) => p.enabled && p.phase == PublishPhase.failed)
        .toList();
    if (failed.isEmpty) {
      emit(state.copyWith(status: PublishProductStatus.success));
      return;
    }

    final first = failed.first;
    emit(
      state.copyWith(
        status: PublishProductStatus.failure,
        errorMessage: failed.length == 1
            ? '${first.label}: ${first.resultMessage}'
            : '${failed.length} platforms failed — see details, then retry.',
      ),
    );
    emit(state.copyWith(status: PublishProductStatus.editing));
  }

  void _record(String platformId, PublishOutcome outcome) {
    if (isClosed) return;
    final current = state.platforms[platformId];
    if (current == null) return;
    _put(
      current.copyWith(phase: outcome.phase, resultMessage: outcome.message),
    );
  }

  void _put(PlatformPublishDraft draft, {bool clearError = false}) {
    final next = Map<String, PlatformPublishDraft>.of(state.platforms)
      ..[draft.platformId] = draft;
    emit(state.copyWith(platforms: next, clearError: clearError));
  }
}
