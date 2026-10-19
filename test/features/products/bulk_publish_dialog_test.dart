import 'dart:async';

import 'package:bayan_desktop/core/database/app_database.dart';
import 'package:bayan_desktop/core/storage/app_preferences.dart';
import 'package:bayan_desktop/features/products/data/models/product_model.dart';
import 'package:bayan_desktop/features/products/data/repositories/product_publish_repository.dart';
import 'package:bayan_desktop/features/products/data/repositories/product_records_repository.dart';
import 'package:bayan_desktop/features/products/presentation/cubit/product_registry_cubit.dart';
import 'package:bayan_desktop/features/products/presentation/widgets/bulk_publish_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'product_registry_test.dart' show InstantRepository, product;

void main() {
  setUpAll(sqfliteFfiInit);

  testWidgets('dialog: form → animated progress → done, with no layout errors', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});

    final database = await tester.runAsync(
      () => AppDatabase.open(factory: databaseFactoryFfi, path: inMemoryDatabasePath),
    );
    final registry = ProductRegistryCubit(ProductRecordsRepository(database!.db));
    final repository = InstantRepository(failing: {'hungerstation'});
    final prefs = await tester.runAsync(AppPreferences.create);
    addTearDown(() => tester.runAsync(database.close));

    final products = <ProductModel>[product('1'), product('2')];

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<ProductPublishRepository>.value(value: repository),
          RepositoryProvider<AppPreferences>.value(value: prefs!),
        ],
        child: BlocProvider.value(
          value: registry,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => showBulkPublishDialog(context, products: products),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Form step.
    expect(find.text('Add to all platforms'), findsOneWidget);
    expect(find.text('Add 2 products'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
      reason: 'a Keeta category is required',
    );

    await tester.enterText(find.byType(TextField).first, 'Grocery');
    await tester.pump();
    await tester.tap(find.text('Add 2 products'));

    // Let the run finish (real async work: SQLite writes).
    for (var i = 0; i < 40 && find.text('Close').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(milliseconds: 600));

    // Done step: HungerStation failed for both products, Keeta added both.
    expect(find.text('Close'), findsOneWidget);
    expect(find.text('Finished with issues'), findsOneWidget);
    expect(find.text('Needs attention'), findsOneWidget);
    expect(find.text('Added'), findsOneWidget);
    expect(find.text('Failed'), findsOneWidget);
    expect(registry.state.isRegistered('1', 'keeta'), isTrue);
    expect(registry.state.isRegistered('1', 'hungerstation'), isFalse);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 3));
    expect(find.text('Finished with issues'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    unawaited(registry.close());
  });
}
