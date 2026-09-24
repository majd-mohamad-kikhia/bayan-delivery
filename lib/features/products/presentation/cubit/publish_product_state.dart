import 'package:equatable/equatable.dart';

import '../../../../core/theme/platform_colors.dart';
import '../../data/models/listing_models.dart';
import '../../data/models/product_model.dart';
import '../../data/repositories/product_publish_repository.dart';

/// One platform card on the publish screen.
final class PlatformPublishDraft extends Equatable {
  const PlatformPublishDraft({
    required this.listing,
    this.enabled = false,
    this.phase = PublishPhase.idle,
    this.resultMessage,
  });

  final bool enabled;

  /// The fields this platform's add-product API takes.
  final PlatformListing listing;

  /// Where this platform is in the publish flow.
  final PublishPhase phase;

  /// Platform answer for the last attempt (error text when failed).
  final String? resultMessage;

  String get platformId => listing.platformId;

  String get label => PlatformColors.label(platformId);

  /// Selected and not yet live on the platform.
  bool get needsPublish => enabled && !phase.isDone;

  PlatformPublishDraft copyWith({
    bool? enabled,
    PlatformListing? listing,
    PublishPhase? phase,
    String? resultMessage,
  }) {
    return PlatformPublishDraft(
      enabled: enabled ?? this.enabled,
      listing: listing ?? this.listing,
      phase: phase ?? this.phase,
      resultMessage: phase != null ? resultMessage : this.resultMessage,
    );
  }

  @override
  List<Object?> get props => [enabled, listing, phase, resultMessage];
}

enum PublishProductStatus { editing, submitting, success, failure }

final class PublishProductState extends Equatable {
  const PublishProductState({
    required this.product,
    required this.content,
    this.status = PublishProductStatus.editing,
    this.platforms = const {},
    this.errorMessage,
  });

  final ProductModel product;

  /// Names, descriptions, images and barcode shared by every platform.
  final ListingContent content;
  final PublishProductStatus status;
  final Map<String, PlatformPublishDraft> platforms;
  final String? errorMessage;

  double get basePrice => product.salePrice;

  int get selectedCount => platforms.values.where((p) => p.enabled).length;

  bool get canSubmit =>
      status == PublishProductStatus.editing &&
      platforms.values.any((p) => p.needsPublish);

  Iterable<PlatformPublishDraft> _inPhase(PublishPhase phase) =>
      platforms.values.where((p) => p.enabled && p.phase == phase);

  /// e.g. "Added to Keeta, HungerStation" / "… · still processing on HungerStation".
  String get resultSummary {
    final live = _inPhase(
      PublishPhase.published,
    ).map((p) => p.label).join(', ');
    final pending = _inPhase(
      PublishPhase.processing,
    ).map((p) => p.label).join(', ');
    return [
      if (live.isNotEmpty) 'Added to $live',
      if (pending.isNotEmpty) 'still processing on $pending',
    ].join(' · ');
  }

  PublishProductState copyWith({
    ListingContent? content,
    PublishProductStatus? status,
    Map<String, PlatformPublishDraft>? platforms,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PublishProductState(
      product: product,
      content: content ?? this.content,
      status: status ?? this.status,
      platforms: platforms ?? this.platforms,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
    product,
    content,
    status,
    platforms,
    errorMessage,
  ];
}
