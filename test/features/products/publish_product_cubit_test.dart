import 'dart:async';

import 'package:bayan_desktop/core/platforms/keeta/keeta_types.dart';
import 'package:bayan_desktop/features/products/data/models/listing_models.dart';
import 'package:bayan_desktop/features/products/data/repositories/product_publish_repository.dart';
import 'package:bayan_desktop/features/products/data/sample_products.dart';
import 'package:bayan_desktop/features/products/presentation/cubit/publish_product_cubit.dart';
import 'package:bayan_desktop/features/products/presentation/cubit/publish_product_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// Each publish waits until the test answers it.
class ManualRepository implements ProductPublishRepository {
  final Map<String, Completer<PublishOutcome>> pending = {};
  final List<String> prewarmed = [];
  final List<(ListingContent, PlatformListing)> calls = [];

  @override
  Duration get hsJobTimeout => Duration.zero;

  @override
  void prewarm(String platformId) => prewarmed.add(platformId);

  @override
  Future<List<String>> categoryNames(String platformId) async => const [];

  @override
  Future<PublishOutcome> publish(
    ListingContent content,
    PlatformListing listing,
  ) {
    calls.add((content, listing));
    return (pending[listing.platformId] = Completer()).future;
  }

  void answer(String platformId, PublishOutcome outcome) =>
      pending[platformId]!.complete(outcome);
}

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  late ManualRepository repository;
  late PublishProductCubit cubit;

  setUp(() {
    repository = ManualRepository();
    cubit = PublishProductCubit(
      product: sampleProducts.first,
      repository: repository,
    );
  });

  tearDown(() => cubit.close());

  PublishPhase phaseOf(String id) => cubit.state.platforms[id]!.phase;

  test('starts from the Al-Bayan product', () {
    final product = sampleProducts.first;
    final state = cubit.state;
    expect(state.content.nameEn, product.name);
    expect(state.content.barcode, product.barcode);
    expect(state.platforms.keys, ['keeta', 'hungerstation']);
    final keeta = state.platforms['keeta']!.listing as KeetaListing;
    expect(keeta.price, product.salePrice);
    expect(keeta.category, product.category);
    final hs = state.platforms['hungerstation']!.listing as HsListing;
    expect(hs.quantity, product.stockQty.floor());
  });

  test('selecting a platform prewarms it', () {
    cubit.togglePlatform('keeta', true);
    cubit.selectAllPlatforms();
    expect(repository.prewarmed, ['keeta', 'keeta', 'hungerstation']);
  });

  test('form edits reach the publish call', () async {
    cubit
      ..togglePlatform('keeta', true)
      ..updateContent((c) => c.copyWith(descriptionEn: 'Fresh'))
      ..updateListing<KeetaListing>(
        'keeta',
        (l) => l.copyWith(
          price: 5,
          allergens: {KeetaAllergen.grains},
          pickup: true,
          pickupPrice: () => 4,
        ),
      )
      // Wrong listing type for the platform: ignored.
      ..updateListing<HsListing>('keeta', (l) => l.copyWith(price: 99));

    unawaited(cubit.submit());
    await settle();

    final (content, listing) = repository.calls.single;
    expect(content.descriptionEn, 'Fresh');
    listing as KeetaListing;
    expect(listing.price, 5);
    expect(listing.allergens, {KeetaAllergen.grains});
    expect(listing.pickupPrice, 4);
    repository.answer(
      'keeta',
      const PublishOutcome(PublishPhase.published, 'ok'),
    );
  });

  test(
    'publishes in parallel, updates each card independently, retries only failures',
    () async {
      cubit
        ..togglePlatform('keeta', true)
        ..togglePlatform('hungerstation', true);

      final submit = cubit.submit();
      await settle();

      expect(
        repository.calls.map((c) => c.$2.platformId),
        ['keeta', 'hungerstation'],
        reason: 'both started at once',
      );
      expect(cubit.state.status, PublishProductStatus.submitting);

      repository.answer(
        'keeta',
        const PublishOutcome(PublishPhase.published, 'Added to Keeta'),
      );
      await settle();
      expect(phaseOf('keeta'), PublishPhase.published);
      expect(phaseOf('hungerstation'), PublishPhase.publishing);

      repository.answer(
        'hungerstation',
        const PublishOutcome.failed('No vendor'),
      );
      await submit;
      expect(phaseOf('hungerstation'), PublishPhase.failed);
      expect(cubit.state.status, PublishProductStatus.editing);
      expect(cubit.state.errorMessage, 'HungerStation: No vendor');
      expect(cubit.state.canSubmit, isTrue);

      final retry = cubit.submit();
      await settle();
      expect(repository.calls.map((c) => c.$2.platformId), [
        'keeta',
        'hungerstation',
        'hungerstation',
      ]);

      repository.answer(
        'hungerstation',
        const PublishOutcome(PublishPhase.processing, 'still processing'),
      );
      await retry;
      expect(cubit.state.status, PublishProductStatus.success);
      expect(
        cubit.state.resultSummary,
        'Added to Keeta · still processing on HungerStation',
      );
    },
  );

  test('a second submit while publishing is ignored', () async {
    cubit.togglePlatform('keeta', true);
    unawaited(cubit.submit());
    await settle();
    await cubit.submit();
    expect(repository.calls, hasLength(1));
    repository.answer(
      'keeta',
      const PublishOutcome(PublishPhase.published, 'ok'),
    );
  });
}
