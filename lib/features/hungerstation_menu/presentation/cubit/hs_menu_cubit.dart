import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/hs_menu_repository.dart';

enum HsMenuStatus { initial, loading, ready, failure }

final class HsMenuState extends Equatable {
  const HsMenuState({
    this.status = HsMenuStatus.initial,
    this.menu = const HsMenu(categories: [], products: []),
    this.selectedCategoryId,
    this.busySkus = const {},
    this.message,
    this.error,
  });

  final HsMenuStatus status;
  final HsMenu menu;
  final String? selectedCategoryId;

  /// SKUs with a request in flight (their controls are disabled).
  final Set<String> busySkus;

  /// Last error from an edit, shown once.
  final String? message;

  /// Why the menu could not be loaded.
  final String? error;

  List<HsMenuProduct> get selectedProducts => selectedCategoryId == null
      ? const []
      : menu.productsOf(selectedCategoryId!);

  HsMenuState copyWith({
    HsMenuStatus? status,
    HsMenu? menu,
    String? selectedCategoryId,
    Set<String>? busySkus,
    String? message,
    bool clearMessage = false,
    String? error,
    bool clearError = false,
  }) => HsMenuState(
    status: status ?? this.status,
    menu: menu ?? this.menu,
    selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
    busySkus: busySkus ?? this.busySkus,
    message: clearMessage ? null : (message ?? this.message),
    error: clearError ? null : (error ?? this.error),
  );

  @override
  List<Object?> get props => [
    status,
    menu,
    selectedCategoryId,
    busySkus,
    message,
    error,
  ];
}

/// The live HungerStation menu: the products it has, grouped by its categories.
class HsMenuCubit extends Cubit<HsMenuState> {
  HsMenuCubit(this._repository) : super(const HsMenuState());

  final HsMenuRepository _repository;

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      emit(state.copyWith(status: HsMenuStatus.loading, clearError: true));
    }
    try {
      final menu = await _repository.load();
      final selected =
          menu.categories.any((c) => c.id == state.selectedCategoryId)
          ? state.selectedCategoryId
          : (menu.categories.isEmpty ? null : menu.categories.first.id);
      if (isClosed) return;
      emit(
        state.copyWith(
          status: HsMenuStatus.ready,
          menu: menu,
          selectedCategoryId: selected,
          clearError: true,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      if (silent) {
        emit(state.copyWith(message: '$e'));
      } else {
        emit(state.copyWith(status: HsMenuStatus.failure, error: '$e'));
      }
    }
  }

  void selectCategory(String id) =>
      emit(state.copyWith(selectedCategoryId: id));

  void messageShown() => emit(state.copyWith(clearMessage: true));

  Future<void> _edit(String sku, Future<void> Function() change) async {
    emit(state.copyWith(busySkus: {...state.busySkus, sku}));
    try {
      await change();
      await load(silent: true);
    } catch (e) {
      if (!isClosed) emit(state.copyWith(message: '$e'));
    } finally {
      if (!isClosed) {
        emit(state.copyWith(busySkus: {...state.busySkus}..remove(sku)));
      }
    }
  }

  Future<void> setPrice(HsMenuProduct product, double price) =>
      _edit(product.sku, () => _repository.setPrice(product.sku, price));

  Future<void> setAvailable(HsMenuProduct product, bool available) => _edit(
    product.sku,
    () => _repository.setAvailable(product.sku, available),
  );
}
