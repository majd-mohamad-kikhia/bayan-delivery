import 'package:bayan_desktop/core/platforms/auth/auth_token.dart';
import 'package:bayan_desktop/core/platforms/common/platform_request.dart';
import 'package:bayan_desktop/core/platforms/hungerstation/hs_endpoints.dart';
import 'package:bayan_desktop/core/platforms/hungerstation/hs_types.dart';
import 'package:bayan_desktop/core/platforms/keeta/keeta_endpoints.dart';
import 'package:bayan_desktop/core/platforms/keeta/keeta_types.dart';
import 'package:bayan_desktop/core/storage/app_preferences.dart';
import 'package:bayan_desktop/features/products/data/models/listing_models.dart';
import 'package:bayan_desktop/features/products/data/models/product_model.dart';
import 'package:bayan_desktop/features/products/data/repositories/product_publish_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/platforms/fakes.dart';

const bread = ProductModel(
  id: '1',
  sku: 'BYN-BRD-001',
  name: 'Arabic Bread Pack',
  nameAr: 'رغيف عربي',
  category: 'Bakery',
  unit: 'Pack',
  salePrice: 4.5,
  costPrice: 2.8,
  stockQty: 240,
  isActive: true,
  barcode: '6281001001001',
);

final breadContent = ListingContent.fromProduct(bread);

void main() {
  final seed = AuthToken(
    accessToken: 'access',
    refreshToken: 'refresh',
    expiresAt: DateTime.now().add(const Duration(days: 60)),
  );

  late FakeExecutor executor;

  Future<ProductPublishRepository> build(
    Object? Function(PlatformRequest request) handler, {
    Duration hsJobTimeout = const Duration(seconds: 5),
  }) async {
    executor = FakeExecutor(handler);
    final apis = await buildApis(
      executor,
      prefs: const {...keetaPrefs, ...hsPrefs, 'keeta_shop_id': 466663},
      keetaSeed: seed,
    );
    return ProductPublishRepository(
      apis: apis,
      preferences: await AppPreferences.create(),
      hsJobTimeout: hsJobTimeout,
    );
  }

  group('Keeta', () {
    Object? keetaServer(PlatformRequest request) => switch (request.endpoint) {
      KeetaEndpoints.categoryList => keetaOk([
        {'id': 5, 'name': 'BAKERY', 'nameTranslation': 'مخبوزات'},
      ]),
      KeetaEndpoints.createProducts => keetaOk([
        {'id': 9001, 'openItemCode': 'BYN-BRD-001'},
      ]),
      _ => keetaOk([]),
    };

    test('sends the SPU exactly as the spec defines it', () async {
      final repository = await build(keetaServer);

      final outcome = await repository.publish(
        breadContent.copyWith(
          descriptionEn: 'Fresh daily',
          descriptionAr: 'طازج يومياً',
        ),
        const KeetaListing(
          price: 5,
          available: false,
          category: 'bakery',
          signature: true,
          pickup: true,
          pickupPrice: 4.25,
          allergens: {KeetaAllergen.grains, KeetaAllergen.sesameSeeds},
          nutrition: {KeetaNutrient.calories: 250},
          servingSize: 2,
        ),
      );

      expect(outcome.phase, PublishPhase.published);
      final create = executor
          .requestsTo(KeetaEndpoints.createProducts.id)
          .single;
      expect(create.params['shopId'], 466663);
      expect(create.params['spuList'], [
        {
          'name': 'Arabic Bread Pack',
          'sourceLanguageType': 'en',
          'nameTranslation': 'رغيف عربي',
          'targetLanguageType': 'ar',
          'nameTranslateType': 1,
          'description': 'Fresh daily',
          'descSourceLanguageType': 'en',
          'descriptionTranslation': 'طازج يومياً',
          'descTargetLanguageType': 'ar',
          'descriptionTranslateType': 1,
          'status': 0,
          'isSpecialty': 1,
          'openItemCode': 'BYN-BRD-001',
          'shopCategoryList': [
            {'id': 5},
          ],
          'availableTime': {'code': 0},
          'userGetModeList': ['delivery', 'pickup'],
          'skuList': [
            {
              'price': '5.00',
              'pickPrice': '4.25',
              'openItemCode': 'BYN-BRD-001',
              'allergens': ['Grains', 'Sesame seeds'],
              'nutritionalInfo': {'calories_kcal': 250},
              'servingSize': 2,
            },
          ],
        },
      ]);
      expect(executor.requests, hasLength(2), reason: 'no images to bind');
    });

    test('daily hours become availableTime code 1 for all 7 days', () async {
      final repository = await build(keetaServer);

      await repository.publish(
        breadContent,
        const KeetaListing(
          price: 4.5,
          category: 'Bakery',
          limitedHours: true,
          sellingHours: KeetaSellingHours(360, 660),
        ),
      );

      final create = executor
          .requestsTo(KeetaEndpoints.createProducts.id)
          .single;
      final spu = (create.params['spuList']! as List).single as Map;
      expect(spu['availableTime'], {
        'code': 1,
        'values': List.filled(7, '06:00-11:00'),
      });
    });

    test('images are bound to the new SPU after creating it', () async {
      final repository = await build(keetaServer);

      final outcome = await repository.publish(
        breadContent.copyWith(imageUrls: ['https://cdn.example.com/bread.jpg']),
        const KeetaListing(price: 4.5, category: 'Bakery'),
      );

      expect(outcome.phase, PublishPhase.published);
      expect(outcome.message, 'Added to Keeta');
      final bind = executor
          .requestsTo(KeetaEndpoints.bindProductPictures.id)
          .single;
      expect(bind.params['spuPictureList'], [
        {
          'spuId': 9001,
          'urlList': ['https://cdn.example.com/bread.jpg'],
        },
      ]);
    });

    test('invalid input fails before any request', () async {
      final repository = await build(keetaServer);

      final noPickupPrice = await repository.publish(
        breadContent,
        const KeetaListing(price: 4.5, category: 'Bakery', pickup: true),
      );
      final badHours = await repository.publish(
        breadContent,
        const KeetaListing(price: 4.5, category: 'Bakery', limitedHours: true),
      );
      final badImage = await repository.publish(
        breadContent.copyWith(imageUrls: ['ftp://x/bread.jpg']),
        const KeetaListing(price: 4.5, category: 'Bakery'),
      );

      expect(noPickupPrice.message, 'Pickup price must be greater than 0');
      expect(badHours.message, contains('selling hours'));
      expect(badImage.message, contains('Image URLs'));
      expect(executor.requests, isEmpty);
    });

    test(
      'a missing category is created once for concurrent publishes',
      () async {
        final repository = await build(
          (request) => switch (request.endpoint) {
            KeetaEndpoints.categoryList => keetaOk(const []),
            KeetaEndpoints.createCategory => keetaOk({
              'id': 77,
              'name': 'Specials',
            }),
            _ => keetaOk([]),
          },
        );

        final outcomes = await Future.wait([
          repository.publish(
            breadContent,
            const KeetaListing(price: 4.5, category: 'Specials'),
          ),
          repository.publish(
            const ListingContent(sku: 'BYN-2', nameEn: 'Rice'),
            const KeetaListing(price: 42, category: 'specials'),
          ),
        ]);

        expect(
          outcomes.map((o) => o.phase),
          everyElement(PublishPhase.published),
        );
        expect(
          executor.requestsTo(KeetaEndpoints.categoryList.id),
          hasLength(1),
        );
        final creates = executor.requestsTo(KeetaEndpoints.createCategory.id);
        expect(creates, hasLength(1));
        expect(
          creates.single.params,
          containsPair('shopCategory', {
            'name': 'Specials',
            'sourceLanguageType': 'en',
            'type': 0,
          }),
        );
      },
    );

    test('a rejected SPU in errorList is reported as a failure', () async {
      final repository = await build(
        (request) => switch (request.endpoint) {
          KeetaEndpoints.categoryList => keetaOk([
            {'id': 5, 'name': 'Bakery'},
          ]),
          _ => {
            'code': 0,
            'message': 'Partial Failure',
            'data': [],
            'errorList': [
              {
                'openItemCode': 'BYN-BRD-001',
                'code': 115000201,
                'message': 'Duplicate product name',
              },
            ],
          },
        },
      );

      final outcome = await repository.publish(
        breadContent,
        const KeetaListing(price: 4.5, category: 'Bakery'),
      );
      expect(outcome.phase, PublishPhase.failed);
      expect(outcome.message, 'Duplicate product name');
    });

    test(
      'prewarm loads the categories so the publish is one request',
      () async {
        final repository = await build(keetaServer);

        repository.prewarm('keeta');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(executor.requests.map((r) => r.endpoint), [
          KeetaEndpoints.categoryList,
        ]);
        expect(await repository.categoryNames('keeta'), ['BAKERY']);

        await repository.publish(
          breadContent,
          const KeetaListing(price: 4.5, category: 'Bakery'),
        );
        expect(executor.requests.map((r) => r.endpoint), [
          KeetaEndpoints.categoryList,
          KeetaEndpoints.createProducts,
        ]);
      },
    );
  });

  group('HungerStation', () {
    Object? hsServer(
      PlatformRequest request, {
      Map<String, Object?> job = const {
        'job_id': 'job-1',
        'job_status': 'COMPLETED',
      },
    }) => switch (request.endpoint) {
      HsEndpoints.token => {'access_token': 'jwt', 'expires_in': 7200},
      HsEndpoints.categories => {
        'categories': [
          {
            'global_id': 'cat-bakery',
            'details': {
              'name': {'en_SA': 'Bakery', 'ar_SA': 'مخبوزات'},
            },
            'active': true,
          },
          {
            'global_id': 'cat-old',
            'details': {
              'name': {'en_SA': 'Retired'},
            },
            'active': false,
          },
        ],
      },
      HsEndpoints.addProducts => {'job_id': 'job-1', 'job_status': 'QUEUED'},
      HsEndpoints.catalogJob => job,
      _ => {'job_id': 'job-2', 'job_status': 'QUEUED'},
    };

    List<Object?> addedProducts() =>
        executor
                .requestsTo(HsEndpoints.addProducts.id)
                .single
                .params['products']!
            as List;

    test(
      'sends the product as the spec defines it, then availability and stock',
      () async {
        final repository = await build(hsServer);

        final outcome = await repository.publish(
          breadContent.copyWith(
            descriptionEn: 'Fresh daily',
            imageUrls: ['https://cdn.example.com/bread.png'],
          ),
          const HsListing(
            price: 4.5,
            available: false,
            category: 'bakery',
            quantity: 240,
            maxPerOrder: 5,
          ),
        );

        expect(outcome.phase, PublishPhase.published);
        expect(
          executor
              .requestsTo(HsEndpoints.addProducts.id)
              .single
              .params['vendors'],
          ['vendor-1'],
        );
        expect(addedProducts(), [
          {
            'sku': 'BYN-BRD-001',
            'title': {'en_SA': 'Arabic Bread Pack', 'ar_SA': 'رغيف عربي'},
            'description': {'en_SA': 'Fresh daily'},
            'barcodes': ['6281001001001'],
            'images': ['https://cdn.example.com/bread.png'],
            'categories': ['cat-bakery'],
            'price': 4.5,
          },
        ]);
        expect(
          executor.requestsTo(HsEndpoints.updateProducts.id).single.params,
          {
            'products': [
              {
                'sku': 'BYN-BRD-001',
                'active': false,
                'quantity': 240,
                'maximum_sales_quantity': 5,
              },
            ],
          },
        );
        expect(await repository.categoryNames('hungerstation'), ['Bakery']);
      },
    );

    test(
      'sold by weight sends weight_specifications and needs no barcode',
      () async {
        final repository = await build(hsServer);

        final outcome = await repository.publish(
          const ListingContent(sku: 'BYN-DATES', nameEn: 'Dates'),
          const HsListing(
            price: 30,
            soldByWeight: true,
            baseWeight: HsWeight(1),
            averageWeightPerPiece: HsWeight(250, HsWeightUnit.g),
            minimumStartingWeight: HsWeight(0.5),
          ),
        );

        expect(outcome.phase, PublishPhase.published);
        expect(addedProducts(), [
          {
            'sku': 'BYN-DATES',
            'title': {'en_SA': 'Dates'},
            'price': 30,
            'is_sold_by_weight': true,
            'weight_specifications': {
              'base_weight': 1,
              'base_weight_unit': 'KG',
              'average_weight_per_piece': 250,
              'average_weight_per_piece_unit': 'G',
              'minimum_starting_weight': 0.5,
              'minimum_starting_weight_unit': 'KG',
            },
          },
        ]);
      },
    );

    test('a barcode is required unless sold by weight', () async {
      final repository = await build(hsServer);

      final outcome = await repository.publish(
        const ListingContent(sku: 'X', nameEn: 'No barcode'),
        const HsListing(price: 10),
      );
      expect(outcome.phase, PublishPhase.failed);
      expect(outcome.message, contains('barcode'));
      expect(executor.requests, isEmpty);
    });

    test('a completed job that rejected the product is a failure', () async {
      final repository = await build(
        (request) => hsServer(
          request,
          job: {
            'job_id': 'job-1',
            'job_status': 'COMPLETED',
            'result': {
              'item_level_feedback': [
                {
                  'sku': 'BYN-BRD-001',
                  'status': 'Product creation failed',
                  'rejection_reasons': [
                    {
                      'rejected_data': 'images',
                      'rejected_reason': 'poor quality',
                    },
                  ],
                },
              ],
            },
          },
        ),
      );

      final outcome = await repository.publish(
        breadContent,
        const HsListing(price: 4.5),
      );
      expect(outcome.phase, PublishPhase.failed);
      expect(
        outcome.message,
        'HungerStation rejected it — images: poor quality',
      );
      expect(executor.requestsTo(HsEndpoints.updateProducts.id), isEmpty);
    });

    test(
      'an unknown or inactive category fails before adding anything',
      () async {
        final repository = await build(hsServer);

        final outcome = await repository.publish(
          breadContent,
          const HsListing(price: 4.5, category: 'Retired'),
        );
        expect(outcome.message, contains('"Retired"'));
        expect(executor.requestsTo(HsEndpoints.addProducts.id), isEmpty);
      },
    );

    test(
      'a job still in progress at the timeout is reported as processing',
      () async {
        final repository = await build(
          (request) => hsServer(
            request,
            job: const {'job_id': 'job-1', 'job_status': 'IN_PROGRESS'},
          ),
          hsJobTimeout: Duration.zero,
        );

        final outcome = await repository.publish(
          breadContent,
          const HsListing(price: 4.5),
        );
        expect(outcome.phase, PublishPhase.processing);
        expect(executor.requestsTo(HsEndpoints.updateProducts.id), isEmpty);
      },
    );
  });
}
