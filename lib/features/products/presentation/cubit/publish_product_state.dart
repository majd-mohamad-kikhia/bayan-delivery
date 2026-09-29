import 'package:equatable/equatable.dart';

import '../../data/models/listing_models.dart';
import '../../data/models/product_model.dart';
import '../../data/repositories/product_publish_repository.dart';

/// One platform card on the publish screen.
final class PlatformPublishDraft extends Equatable {
  const PlatformPublishDraft({
    required this.listing,
    this.enabled = false,
    this.phase = PublishPhase.idle,
    this.result,
  });

  final bool enabled;

  /// The fields this platform's add-product API takes.
  final PlatformListing listing;

  /// Where this platform is in the publish flow.
  final PublishPhase phase;

  /// Platform answer for the last attempt.
  final PublishOutcome? result;

  String get platformId => listing.platformId;

  /// Selected and not yet live on the platform.
  bool get needsPublish => enabled && !phase.isDone;

  PlatformPublishDraft copyWith({
    bool? enabled,
    PlatformListing? listing,
    PublishPhase? phase,
    PublishOutcome? result,
  }) {
    return PlatformPublishDraft(
      enabled: enabled ?? this.enabled,
      listing: listing ?? this.listing,
      phase: phase ?? this.phase,
      result: phase != null ? result : this.result,
    );
  }

  @override
  List<Object?> get props => [enabled, listing, phase, result];
}

/// Why the last submit didn't go through; the page words it.
sealed class PublishProductError extends Equatable {
  const PublishProductError();
}

final class NoPlatformSelected extends PublishProductError {
  const NoPlatformSelected();

  @override
  List<Object?> get props => const [];
}

final class PlatformPublishFailed extends PublishProductError {
  const PlatformPublishFailed(this.platformId, this.outcome);

  final String platformId;
  final PublishOutcome outcome;

  @override
  List<Object?> get props => [platformId, outcome];
}

final class PlatformsPublishFailed extends PublishProductError {
  const PlatformsPublishFailed(this.count);

  final int count;

  @override
  List<Object?> get props => [count];
}

enum PublishProductStatus { editing, submitting, success, failure }

final class PublishProductState extends Equatable {
  const PublishProductState({
    required this.product,
    required this.content,
    this.status = PublishProductStatus.editing,
    this.platforms = const {},
    this.error,
  });

  final ProductModel product;

  /// Names, descriptions, images and barcode shared by every platform.
  final ListingContent content;
  final PublishProductStatus status;
  final Map<String, PlatformPublishDraft> platforms;
  final PublishProductError? error;

  double get basePrice => product.salePrice;

  int get selectedCount => platforms.values.where((p) => p.enabled).length;

  bool get canSubmit =>
      status == PublishProductStatus.editing &&
      platforms.values.any((p) => p.needsPublish);

  List<String> _inPhase(PublishPhase phase) => [
    for (final p in platforms.values)
      if (p.enabled && p.phase == phase) p.platformId,
  ];

  /// Selected platforms the product is now live on.
  List<String> get publishedPlatformIds => _inPhase(PublishPhase.published);

  /// Selected platforms still processing the product.
  List<String> get processingPlatformIds => _inPhase(PublishPhase.processing);

  PublishProductState copyWith({
    ListingContent? content,
    PublishProductStatus? status,
    Map<String, PlatformPublishDraft>? platforms,
    PublishProductError? error,
    bool clearError = false,
  }) {
    return PublishProductState(
      product: product,
      content: content ?? this.content,
      status: status ?? this.status,
      platforms: platforms ?? this.platforms,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [product, content, status, platforms, error];
}
