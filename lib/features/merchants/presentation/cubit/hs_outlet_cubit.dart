import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/storage/app_preferences.dart';
import '../../data/models/hs_vendor_status_model.dart';
import '../../data/repositories/merchants_repository.dart';

enum HsOutletLoadStatus { initial, loading, success, failure }

final class HsOutletState extends Equatable {
  const HsOutletState({
    this.status = HsOutletLoadStatus.initial,
    this.vendorStatus,
    this.dongleNumber = '',
    this.isUpdating = false,
    this.errorMessage,
    this.actionError,
  });

  final HsOutletLoadStatus status;
  final HsVendorStatusModel? vendorStatus;
  final String dongleNumber;
  final bool isUpdating;
  final String? errorMessage;
  final String? actionError;

  HsOutletState copyWith({
    HsOutletLoadStatus? status,
    HsVendorStatusModel? vendorStatus,
    String? dongleNumber,
    bool? isUpdating,
    String? errorMessage,
    bool clearError = false,
    String? actionError,
    bool clearActionError = false,
  }) {
    return HsOutletState(
      status: status ?? this.status,
      vendorStatus: vendorStatus ?? this.vendorStatus,
      dongleNumber: dongleNumber ?? this.dongleNumber,
      isUpdating: isUpdating ?? this.isUpdating,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      actionError: clearActionError ? null : (actionError ?? this.actionError),
    );
  }

  @override
  List<Object?> get props => [
        status,
        vendorStatus,
        dongleNumber,
        isUpdating,
        errorMessage,
        actionError,
      ];
}

class HsOutletCubit extends Cubit<HsOutletState> {
  HsOutletCubit({
    required MerchantsRepository repository,
    required AppPreferences preferences,
  })  : _repository = repository,
        _preferences = preferences,
        super(HsOutletState(dongleNumber: preferences.dongleNumber));

  final MerchantsRepository _repository;
  final AppPreferences _preferences;

  Future<void> load({String? dongleNumber}) async {
    final dongle = dongleNumber ?? _preferences.dongleNumber;
    emit(state.copyWith(
      status: HsOutletLoadStatus.loading,
      dongleNumber: dongle,
      clearError: true,
    ));
    try {
      final vendor = await _repository.fetchHsVendorStatus(dongleNumber: dongle);
      emit(state.copyWith(
        status: HsOutletLoadStatus.success,
        vendorStatus: vendor,
        clearError: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: HsOutletLoadStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> updateStatus({
    required String status,
    String? closedReason,
    DateTime? closedUntil,
  }) async {
    final vendor = state.vendorStatus;
    if (vendor == null || state.isUpdating) return;

    emit(state.copyWith(isUpdating: true, clearActionError: true));
    try {
      final updated = await _repository.updateHsVendorStatus(
        dongleNumber: state.dongleNumber,
        vendorId: vendor.vendorId,
        status: status,
        closedReason: closedReason,
        closedUntil: closedUntil,
      );
      emit(state.copyWith(vendorStatus: updated, isUpdating: false));
    } catch (e) {
      emit(state.copyWith(actionError: e.toString(), isUpdating: false));
    }
  }

  void clearActionError() => emit(state.copyWith(clearActionError: true));
}
