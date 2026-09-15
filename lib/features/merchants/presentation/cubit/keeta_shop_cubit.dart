import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/storage/app_preferences.dart';
import '../../data/models/keeta_shop_model.dart';
import '../../data/models/keeta_shop_status_model.dart';
import '../../data/repositories/merchants_repository.dart';

enum KeetaShopLoadStatus { initial, loading, success, failure }

final class KeetaShopState extends Equatable {
  const KeetaShopState({
    this.status = KeetaShopLoadStatus.initial,
    this.shops = const [],
    this.selectedShopId,
    this.shopStatus,
    this.dongleNumber = '',
    this.isUpdatingStatus = false,
    this.errorMessage,
    this.actionError,
  });

  final KeetaShopLoadStatus status;
  final List<KeetaShopModel> shops;
  final int? selectedShopId;
  final KeetaShopStatusModel? shopStatus;
  final String dongleNumber;
  final bool isUpdatingStatus;
  final String? errorMessage;
  final String? actionError;

  KeetaShopModel? get selectedShop {
    final id = selectedShopId;
    if (id == null) return null;
    for (final shop in shops) {
      if (shop.id == id) return shop;
    }
    return shops.isEmpty ? null : shops.first;
  }

  KeetaShopState copyWith({
    KeetaShopLoadStatus? status,
    List<KeetaShopModel>? shops,
    int? selectedShopId,
    KeetaShopStatusModel? shopStatus,
    bool clearShopStatus = false,
    String? dongleNumber,
    bool? isUpdatingStatus,
    String? errorMessage,
    bool clearError = false,
    String? actionError,
    bool clearActionError = false,
  }) {
    return KeetaShopState(
      status: status ?? this.status,
      shops: shops ?? this.shops,
      selectedShopId: selectedShopId ?? this.selectedShopId,
      shopStatus: clearShopStatus ? null : (shopStatus ?? this.shopStatus),
      dongleNumber: dongleNumber ?? this.dongleNumber,
      isUpdatingStatus: isUpdatingStatus ?? this.isUpdatingStatus,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      actionError: clearActionError ? null : (actionError ?? this.actionError),
    );
  }

  @override
  List<Object?> get props => [
        status,
        shops,
        selectedShopId,
        shopStatus,
        dongleNumber,
        isUpdatingStatus,
        errorMessage,
        actionError,
      ];
}

class KeetaShopCubit extends Cubit<KeetaShopState> {
  KeetaShopCubit({
    required MerchantsRepository repository,
    required AppPreferences preferences,
  })  : _repository = repository,
        _preferences = preferences,
        super(KeetaShopState(
          selectedShopId: preferences.keetaShopId,
          dongleNumber: preferences.dongleNumber,
        ));

  final MerchantsRepository _repository;
  final AppPreferences _preferences;

  Future<void> load({String? dongleNumber}) async {
    final dongle = dongleNumber ?? _preferences.dongleNumber;
    emit(state.copyWith(
      status: KeetaShopLoadStatus.loading,
      dongleNumber: dongle,
      clearError: true,
    ));
    try {
      final shops = await _repository.fetchKeetaShops(dongleNumber: dongle);
      final preferredId = state.selectedShopId;
      final selectedId = shops.any((s) => s.id == preferredId)
          ? preferredId
          : (shops.isEmpty ? null : shops.first.id);

      emit(state.copyWith(
        status: KeetaShopLoadStatus.success,
        shops: shops,
        selectedShopId: selectedId,
        clearError: true,
      ));

      if (selectedId != null) {
        await selectShop(selectedId);
      }
    } catch (e) {
      emit(state.copyWith(
        status: KeetaShopLoadStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> selectShop(int shopId) async {
    emit(state.copyWith(
      selectedShopId: shopId,
      clearShopStatus: true,
      clearActionError: true,
    ));
    await _preferences.setKeetaShopId(shopId);
    await refreshStatus();
  }

  Future<void> refreshStatus() async {
    final shopId = state.selectedShopId;
    if (shopId == null) return;
    try {
      final status = await _repository.fetchKeetaShopStatus(
        dongleNumber: state.dongleNumber,
        shopId: shopId,
      );
      emit(state.copyWith(shopStatus: status, clearError: true));
    } catch (e) {
      emit(state.copyWith(actionError: e.toString()));
    }
  }

  Future<void> setAvailable({required bool available}) async {
    final shopId = state.selectedShopId;
    if (shopId == null || state.isUpdatingStatus) return;

    emit(state.copyWith(isUpdatingStatus: true, clearActionError: true));
    try {
      await _repository.updateKeetaShopStatus(
        dongleNumber: state.dongleNumber,
        shopId: shopId,
        available: available,
      );
      await refreshStatus();
    } catch (e) {
      emit(state.copyWith(actionError: e.toString()));
    } finally {
      emit(state.copyWith(isUpdatingStatus: false));
    }
  }

  void clearActionError() => emit(state.copyWith(clearActionError: true));
}
