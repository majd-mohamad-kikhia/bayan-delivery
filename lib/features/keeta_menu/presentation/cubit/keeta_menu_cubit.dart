import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/keeta_menu_repository.dart';

enum KeetaMenuStatus { initial, loading, ready, failure }

final class KeetaMenuState extends Equatable {
  const KeetaMenuState({
    this.status = KeetaMenuStatus.initial,
    this.menu = const KeetaMenu(categories: [], products: []),
    this.selectedCategoryId,
    this.busyIds = const {},
    this.message,
    this.error,
  });

  final KeetaMenuStatus status;

  /// What is on Keeta right now.
  final KeetaMenu menu;
  final int? selectedCategoryId;

  /// Product ids with a request in flight (their controls are disabled).
  final Set<int> busyIds;

  /// Last error from an edit, shown once.
  final String? message;

  /// Why the menu could not be loaded.
  final String? error;

  List<MenuProduct> get selectedProducts => selectedCategoryId == null
      ? const []
      : menu.productsOf(selectedCategoryId!);

  KeetaMenuState copyWith({
    KeetaMenuStatus? status,
    KeetaMenu? menu,
    int? selectedCategoryId,
    Set<int>? busyIds,
    String? message,
    bool clearMessage = false,
    String? error,
    bool clearError = false,
  }) => KeetaMenuState(
    status: status ?? this.status,
    menu: menu ?? this.menu,
    selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
    busyIds: busyIds ?? this.busyIds,
    message: clearMessage ? null : (message ?? this.message),
    error: clearError ? null : (error ?? this.error),
  );

  @override
  List<Object?> get props => [
    status,
    menu,
    selectedCategoryId,
    busyIds,
    message,
    error,
  ];
}

/// The live Keeta menu: exactly the categories and products Keeta has.
class KeetaMenuCubit extends Cubit<KeetaMenuState> {
  KeetaMenuCubit(this._repository) : super(const KeetaMenuState());

  final KeetaMenuRepository _repository;

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      emit(state.copyWith(status: KeetaMenuStatus.loading, clearError: true));
    }
    try {
      final menu = await _repository.load();
      final selected =
          menu.categories.any((c) => c.id == state.selectedCategoryId)
          ? state.selectedCategoryId
          : (menu.categories.isEmpty ? null : menu.categories.first.id);
      emit(
        state.copyWith(
          status: KeetaMenuStatus.ready,
          menu: menu,
          selectedCategoryId: selected,
          clearError: true,
        ),
      );
    } catch (e) {
      if (silent) {
        emit(state.copyWith(message: '$e'));
      } else {
        emit(state.copyWith(status: KeetaMenuStatus.failure, error: '$e'));
      }
    }
  }

  void selectCategory(int id) => emit(state.copyWith(selectedCategoryId: id));

  void messageShown() => emit(state.copyWith(clearMessage: true));

  /// Runs [change] for [productId], then reloads. Failures become [message].
  Future<void> _edit(int productId, Future<void> Function() change) async {
    emit(state.copyWith(busyIds: {...state.busyIds, productId}));
    try {
      await change();
      await load(silent: true);
    } catch (e) {
      emit(state.copyWith(message: '$e'));
    } finally {
      emit(state.copyWith(busyIds: {...state.busyIds}..remove(productId)));
    }
  }

  Future<void> updateProduct(
    MenuProduct product, {
    String? name,
    String? description,
    double? price,
  }) => _edit(
    product.id,
    () => _repository.updateProduct(
      product,
      name: name,
      description: description,
      price: price,
    ),
  );

  Future<void> setAvailable(MenuProduct product, bool available) =>
      _edit(product.id, () => _repository.setAvailable(product.id, available));

  Future<void> deleteProduct(MenuProduct product) =>
      _edit(product.id, () => _repository.deleteProduct(product.id));

  Future<void> renameCategory(MenuCategory category, String name) async {
    try {
      await _repository.renameCategory(category, name);
      await load(silent: true);
    } catch (e) {
      emit(state.copyWith(message: '$e'));
    }
  }

  Future<void> deleteCategory(MenuCategory category) async {
    try {
      await _repository.deleteCategory(category.id);
      await load(silent: true);
    } catch (e) {
      emit(state.copyWith(message: '$e'));
    }
  }

  /// Moves a category and tells Keeta; the list updates at once and is
  /// restored from Keeta if the call fails.
  Future<void> moveCategory(int oldIndex, int newIndex) async {
    final categories = [...state.menu.categories];
    if (newIndex > oldIndex) newIndex -= 1;
    categories.insert(newIndex, categories.removeAt(oldIndex));
    emit(
      state.copyWith(
        menu: KeetaMenu(categories: categories, products: state.menu.products),
      ),
    );
    try {
      await _repository.reorderCategories([for (final c in categories) c.id]);
    } catch (e) {
      emit(state.copyWith(message: '$e'));
      await load(silent: true);
    }
  }

  Future<void> moveProduct(int oldIndex, int newIndex) async {
    final categoryId = state.selectedCategoryId;
    if (categoryId == null) return;
    final inCategory = [...state.menu.productsOf(categoryId)];
    if (newIndex > oldIndex) newIndex -= 1;
    inCategory.insert(newIndex, inCategory.removeAt(oldIndex));

    // Rebuild the full list with this category's products in the new order.
    final queue = [...inCategory];
    final products = [
      for (final p in state.menu.products)
        if (p.categoryIds.contains(categoryId)) queue.removeAt(0) else p,
    ];
    emit(
      state.copyWith(
        menu: KeetaMenu(categories: state.menu.categories, products: products),
      ),
    );
    try {
      await _repository.reorderProducts(categoryId, [
        for (final p in inCategory) p.id,
      ]);
    } catch (e) {
      emit(state.copyWith(message: '$e'));
      await load(silent: true);
    }
  }
}
