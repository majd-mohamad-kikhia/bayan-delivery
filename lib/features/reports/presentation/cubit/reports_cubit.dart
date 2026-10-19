import 'dart:async';
import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/storage/app_preferences.dart';
import '../../../orders/presentation/utils/orders_date_filter.dart';
import '../../data/report_models.dart';
import '../../data/reports_repository.dart';

enum ReportsStatus { loading, ready, failure }

final class ReportsState extends Equatable {
  const ReportsState({
    this.status = ReportsStatus.loading,
    this.overview,
    this.filter = const OrdersDateFilter(OrdersDatePreset.last7Days),
    this.platform = 'all',
    this.refreshing = false,
    this.error,
  });

  final ReportsStatus status;
  final ReportOverview? overview;
  final OrdersDateFilter filter;

  /// `all`, `keeta` or `hungerstation`.
  final String platform;

  /// A reload is running while the previous numbers stay on screen.
  final bool refreshing;
  final String? error;

  ReportsState copyWith({
    ReportsStatus? status,
    ReportOverview? overview,
    OrdersDateFilter? filter,
    String? platform,
    bool? refreshing,
    String? error,
    bool clearError = false,
  }) => ReportsState(
    status: status ?? this.status,
    overview: overview ?? this.overview,
    filter: filter ?? this.filter,
    platform: platform ?? this.platform,
    refreshing: refreshing ?? this.refreshing,
    error: clearError ? null : (error ?? this.error),
  );

  // The overview is replaced as a whole, so identity is enough.
  @override
  List<Object?> get props => [
    status,
    identityHashCode(overview),
    filter,
    platform,
    refreshing,
    error,
  ];
}

class ReportsCubit extends Cubit<ReportsState> {
  ReportsCubit(this._repository, this._dongleNumber, this._preferences)
    : super(_restore(_preferences)) {
    // Cheap to repeat: the backend answers from its cache until an order changes.
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => load(silent: true),
    );
  }

  final ReportsRepository _repository;
  final String _dongleNumber;
  final AppPreferences _preferences;

  static const defaultFilter = OrdersDateFilter(OrdersDatePreset.last7Days);

  /// What was chosen last time, so leaving the page and coming back (or
  /// restarting the app) shows the same days and platform.
  static ReportsState _restore(AppPreferences preferences) {
    Object? json;
    try {
      final saved = preferences.reportsFilter;
      json = saved == null ? null : jsonDecode(saved);
    } catch (_) {
      json = null;
    }
    final platform = preferences.reportsPlatform;
    return ReportsState(
      filter: OrdersDateFilter.fromJson(json, fallback: defaultFilter),
      platform: const {'all', 'keeta', 'hungerstation'}.contains(platform)
          ? platform
          : 'all',
    );
  }

  late final Timer _timer;
  int _requestId = 0;

  @override
  Future<void> close() {
    _timer.cancel();
    return super.close();
  }

  /// First and last day of the chosen range (local days).
  static ({DateTime from, DateTime to}) rangeOf(
    OrdersDateFilter filter,
    DateTime now,
  ) {
    final range = filter.range(now);
    if (range != null) return (from: range.start, to: range.end);
    final today = DateTime(now.year, now.month, now.day);
    return (
      from: DateTime(today.year, today.month, today.day - 364),
      to: today,
    ); // "all time" = a year
  }

  Future<void> load({bool silent = false}) async {
    final id = ++_requestId;
    emit(
      silent
          ? state.copyWith(refreshing: true)
          : state.copyWith(
              status: state.overview == null
                  ? ReportsStatus.loading
                  : state.status,
              refreshing: true,
            ),
    );
    try {
      final range = rangeOf(state.filter, DateTime.now());
      final overview = await _repository.overview(
        dongleNumber: _dongleNumber,
        from: range.from,
        to: range.to,
        platform: state.platform == 'all' ? null : state.platform,
      );
      // A newer choice is already loading: drop this answer.
      if (id != _requestId || isClosed) return;
      emit(
        state.copyWith(
          status: ReportsStatus.ready,
          overview: overview,
          refreshing: false,
          clearError: true,
        ),
      );
    } catch (e) {
      if (id != _requestId || isClosed) return;
      emit(
        state.overview != null
            // Keep the last good numbers, but say so when the user asked for
            // something new (a quiet background refresh stays quiet).
            ? state.copyWith(
                refreshing: false,
                error: silent ? null : '$e',
                clearError: silent,
              )
            : state.copyWith(
                status: ReportsStatus.failure,
                refreshing: false,
                error: '$e',
              ),
      );
    }
  }

  Future<void> setFilter(OrdersDateFilter filter) {
    emit(state.copyWith(filter: filter));
    _preferences.setReportsFilter(jsonEncode(filter.toJson()));
    return load();
  }

  Future<void> setPlatform(String platform) {
    if (platform == state.platform) return Future.value();
    emit(state.copyWith(platform: platform));
    _preferences.setReportsPlatform(platform);
    return load();
  }
}
