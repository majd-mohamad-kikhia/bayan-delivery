import 'package:bayan_desktop/features/products/data/models/listing_models.dart';
import 'package:bayan_desktop/features/products/data/repositories/product_publish_repository.dart';
import 'package:bayan_desktop/features/products/data/sample_products.dart';
import 'package:bayan_desktop/features/products/presentation/pages/publish_product_page.dart';
import 'package:bayan_desktop/features/products/presentation/widgets/add_product/add_product_field.dart';
import 'package:bayan_desktop/features/products/presentation/widgets/add_product/listing_form_fields.dart';
import 'package:bayan_desktop/features/products/presentation/widgets/add_product/platform_targets_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'publish_product_cubit_test.dart' show ManualRepository;

Finder fieldLabelled(String label) => find.descendant(
  of: find.widgetWithText(AddProductField, label),
  matching: find.byType(TextField),
);

Finder switchLabelled(String label) => find.descendant(
  of: find.widgetWithText(ListingSwitch, label),
  matching: find.byType(Switch),
);

Finder get platformsScroll => find
    .descendant(
      of: find.byType(PlatformTargetsPanel),
      matching: find.byType(Scrollable),
    )
    .first;

void main() {
  Future<ManualRepository> pumpPage(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repository = ManualRepository();
    await tester.pumpWidget(
      RepositoryProvider<ProductPublishRepository>.value(
        value: repository,
        child: MaterialApp(
          home: Scaffold(
            body: PublishProductPage(
              product: sampleProducts.first,
              onClose: () {},
            ),
          ),
        ),
      ),
    );
    return repository;
  }

  for (final size in const [Size(1440, 1000), Size(900, 900)]) {
    testWidgets('lays out every platform form at ${size.width.toInt()}px', (
      tester,
    ) async {
      final repository = await pumpPage(tester, size);

      expect(find.text('Listing details'), findsOneWidget);
      expect(fieldLabelled('Name (English) *'), findsOneWidget);
      expect(
        fieldLabelled('Delivery price (SAR) *'),
        findsNothing,
        reason: 'forms are only built for selected platforms',
      );

      await tester.tap(find.text('Select all'));
      await tester.pumpAndSettle();
      expect(repository.prewarmed, ['keeta', 'hungerstation']);

      expect(fieldLabelled('Delivery price (SAR) *'), findsOneWidget);
      expect(fieldLabelled('Menu category *'), findsOneWidget);
      expect(find.text('Sesame seeds'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Nutrition facts'),
        200,
        scrollable: platformsScroll,
      );
      await tester.ensureVisible(find.text('Nutrition facts'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nutrition facts'));
      await tester.pumpAndSettle();
      expect(fieldLabelled('Calories (kcal)'), findsOneWidget);

      await tester.scrollUntilVisible(
        switchLabelled('Priced by weight'),
        200,
        scrollable: platformsScroll,
      );
      await tester.ensureVisible(switchLabelled('Priced by weight'));
      await tester.pumpAndSettle();
      await tester.tap(switchLabelled('Priced by weight'));
      await tester.pumpAndSettle();
      expect(fieldLabelled('Base weight the price is for *'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('what is typed in the forms is what gets published', (
    tester,
  ) async {
    final repository = await pumpPage(tester, const Size(1440, 1000));

    await tester.tap(find.text('Select all'));
    await tester.pumpAndSettle();

    await tester.enterText(fieldLabelled('Name (English) *'), 'Bread');
    await tester.enterText(fieldLabelled('Delivery price (SAR) *'), '6.5');
    await tester.tap(find.text('Add to platforms').last);
    await tester.pump();

    final byPlatform = {
      for (final (content, listing) in repository.calls)
        listing.platformId: (content, listing),
    };
    expect(byPlatform.keys, ['keeta', 'hungerstation']);
    expect(byPlatform['keeta']!.$1.nameEn, 'Bread');
    expect((byPlatform['keeta']!.$2 as KeetaListing).price, 6.5);
    expect(
      (byPlatform['hungerstation']!.$2 as HsListing).price,
      sampleProducts.first.salePrice,
    );
  });
}
