import 'package:bayan_desktop/features/hungerstation_menu/data/hs_menu_repository.dart';
import 'package:bayan_desktop/features/hungerstation_menu/presentation/cubit/hs_menu_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

final _categories = [
  {
    'global_id': 'c1',
    'details': {
      'name': {'en_SA': 'Burgers', 'ar_SA': 'برجر'},
    },
  },
  {
    'global_id': 'c2',
    'details': {
      'name': {'en_SA': 'Drinks', 'ar_SA': 'مشروبات'},
    },
  },
  {
    'global_id': 'c3',
    'details': {
      'name': {'en_SA': 'Empty', 'ar_SA': 'فارغ'},
    },
  },
];

final _products = [
  {
    'sku': '2',
    'title': {'en_SA': 'Beef Burger', 'ar_SA': 'برجر لحم'},
    'price': 25,
    'categories': ['c1'],
  },
  {
    'sku': '3',
    'title': {'ar_SA': 'كولا'},
    'price': '5.50',
    'active': false,
    'categories': [
      {'global_id': 'c2'},
    ],
  },
  {'sku': '4', 'title': 'Loose item', 'price': {'amount': 7}},
  {'title': 'no sku'},
];

class _FakeRepo implements HsMenuRepository {
  final calls = <String>[];
  Object? failure;

  @override
  Future<HsMenu> load() async => HsMenuRepository.parse(_categories, _products);

  @override
  Future<void> setPrice(String sku, double price) async {
    calls.add('price $sku $price');
    if (failure != null) throw failure!;
  }

  @override
  Future<void> setAvailable(String sku, bool available) async {
    calls.add('active $sku $available');
  }
}

void main() {
  test('parse: titles by locale, prices in every shape, only categories that hold products', () {
    final menu = HsMenuRepository.parse(_categories, _products);

    expect(menu.products.map((p) => p.sku), ['2', '3', '4']);
    final burger = menu.products.first;
    expect(burger.name, 'Beef Burger');
    expect(burger.altName, 'برجر لحم');
    expect(burger.price, 25);
    expect(burger.active, isTrue);

    final cola = menu.products[1];
    expect(cola.name, 'كولا');
    expect(cola.altName, isEmpty);
    expect(cola.price, 5.5);
    expect(cola.active, isFalse);
    expect(cola.categoryIds, ['c2']);

    expect(menu.products[2].price, 7);

    // "Empty" holds nothing; the product with no category gets its own entry.
    expect(menu.categories.map((c) => c.name), ['Burgers', 'Drinks', 'Uncategorized']);
    expect(menu.productsOf('c1').map((p) => p.sku), ['2']);
    expect(menu.productsOf(HsMenuCategory.uncategorizedId).map((p) => p.sku), ['4']);
  });

  test('the cubit loads, selects the first category, and edits then reloads', () async {
    final repo = _FakeRepo();
    final cubit = HsMenuCubit(repo);
    await cubit.load();
    expect(cubit.state.status, HsMenuStatus.ready);
    expect(cubit.state.selectedCategoryId, 'c1');
    expect(cubit.state.selectedProducts.single.sku, '2');

    await cubit.setPrice(cubit.state.selectedProducts.single, 22);
    expect(repo.calls, ['price 2 22.0']);
    expect(cubit.state.busySkus, isEmpty);

    repo.failure = StateError('HungerStation said no');
    await cubit.setPrice(cubit.state.selectedProducts.single, 1);
    expect(cubit.state.message, contains('said no'));
    expect(cubit.state.busySkus, isEmpty);
    await cubit.close();
  });
}
