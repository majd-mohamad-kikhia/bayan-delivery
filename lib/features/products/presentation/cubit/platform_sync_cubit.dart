import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../bayan_erp/data/models/erp_product_model.dart';
import '../../data/platform_sync_service.dart';
import 'auto_publisher.dart';

final class PlatformSyncState extends Equatable {
  const PlatformSyncState({
    this.running = false,
    this.lastRun,
    this.log = const [],
    this.newProducts = const [],
    this.catalog = const [],
    this.lastSent = 0,
    this.lastFailed = 0,
    this.autoAdd = true,
    this.autoLog = const [],
    this.lastAdded = 0,
    this.autoNote,
    this.error,
  });

  final bool running;
  final DateTime? lastRun;

  /// Everything sent (or attempted) recently, newest first.
  final List<SyncChange> log;

  /// Al-Bayan items that are on no platform yet.
  final List<ErpProductModel> newProducts;

  /// The catalog the last good run read: names groups and holds add-ons when
  /// these items are added to the platforms.
  final List<ErpProductModel> catalog;
  final int lastSent;
  final int lastFailed;

  /// New Al-Bayan products are put on the platforms automatically.
  final bool autoAdd;

  /// What the automatic add did recently, newest first.
  final List<AutoAddEntry> autoLog;

  /// Products the last run put on the platforms.
  final int lastAdded;

  /// Why the last run added nothing (a platform could not be reached).
  final String? autoNote;

  /// The last run could not even read Al-Bayan.
  final String? error;

  PlatformSyncState copyWith({
    bool? running,
    DateTime? lastRun,
    List<SyncChange>? log,
    List<ErpProductModel>? newProducts,
    List<ErpProductModel>? catalog,
    int? lastSent,
    int? lastFailed,
    bool? autoAdd,
    List<AutoAddEntry>? autoLog,
    int? lastAdded,
    String? autoNote,
    bool clearAutoNote = false,
    String? error,
    bool clearError = false,
  }) => PlatformSyncState(
    running: running ?? this.running,
    lastRun: lastRun ?? this.lastRun,
    log: log ?? this.log,
    newProducts: newProducts ?? this.newProducts,
    catalog: catalog ?? this.catalog,
    lastSent: lastSent ?? this.lastSent,
    lastFailed: lastFailed ?? this.lastFailed,
    autoAdd: autoAdd ?? this.autoAdd,
    autoLog: autoLog ?? this.autoLog,
    lastAdded: lastAdded ?? this.lastAdded,
    autoNote: clearAutoNote ? null : (autoNote ?? this.autoNote),
    error: clearError ? null : (error ?? this.error),
  );

  @override
  List<Object?> get props => [
    running,
    lastRun,
    log,
    newProducts,
    catalog,
    lastSent,
    lastFailed,
    autoAdd,
    autoLog,
    lastAdded,
    autoNote,
    error,
  ];
}

/// Runs [PlatformSyncService] in the background for the whole life of the
/// app (every [AppConstants.erpSyncInterval]), or on demand.
class PlatformSyncCubit extends Cubit<PlatformSyncState> {
  PlatformSyncCubit(
    this._service, {
    AutoPublisher? autoPublisher,
    bool autoAdd = true,
    void Function(bool enabled)? onAutoAddChanged,
    Duration? every,
    Duration? firstRunAfter,
  }) : _auto = autoPublisher,
       _onAutoAddChanged = onAutoAddChanged,
       _every = every ?? AppConstants.erpSyncInterval,
       _firstRunAfter = firstRunAfter ?? const Duration(seconds: 8),
       super(PlatformSyncState(autoAdd: autoAdd));

  static const _logLimit = 80;

  final PlatformSyncService _service;
  final AutoPublisher? _auto;
  final void Function(bool enabled)? _onAutoAddChanged;
  final Duration _every;
  final Duration _firstRunAfter;
  Timer? _first;
  Timer? _timer;

  /// Starts the schedule: a first run shortly after launch, then periodically.
  void start() {
    _first = Timer(_firstRunAfter, runNow);
    _timer = Timer.periodic(_every, (_) => runNow());
  }

  @override
  Future<void> close() {
    _first?.cancel();
    _timer?.cancel();
    return super.close();
  }

  /// Switches the automatic add of new products on or off (remembered).
  void setAutoAdd(bool enabled) {
    _onAutoAddChanged?.call(enabled);
    emit(state.copyWith(autoAdd: enabled));
    if (enabled) runNow();
  }

  Future<void> runNow() async {
    if (state.running || isClosed) return;
    emit(state.copyWith(running: true));
    SyncReport report;
    try {
      report = await _service.run();
    } catch (e) {
      report = SyncReport(at: DateTime.now(), error: '$e');
    }
    if (isClosed) return;

    // New products go to the platforms next, without a button.
    var auto = const AutoAddReport();
    if (state.autoAdd &&
        _auto != null &&
        report.error == null &&
        report.newProducts.isNotEmpty) {
      try {
        auto = await _auto.run(report.catalog);
      } catch (e) {
        auto = AutoAddReport(
          entries: [
            AutoAddEntry(
              bayanNum: '',
              name: '—',
              at: DateTime.now(),
              error: '$e',
            ),
          ],
        );
      }
      if (isClosed) return;
    }
    final addedIds = {for (final e in auto.added) e.bayanNum};

    emit(
      state.copyWith(
        running: false,
        lastRun: DateTime.now(),
        // Only a run that could read Al-Bayan has a real picture of new items.
        newProducts: report.error == null
            ? [
                for (final p in report.newProducts)
                  if (!addedIds.contains('${p.id}')) p,
              ]
            : null,
        catalog: report.error == null ? report.catalog : null,
        log: [
          ...report.changes.reversed,
          ...state.log,
        ].take(_logLimit).toList(),
        lastSent: report.sent,
        lastFailed: report.failed,
        autoLog: [
          ...auto.entries.reversed,
          ...state.autoLog,
        ].take(_logLimit).toList(),
        lastAdded: auto.added.length,
        autoNote: auto.platformsUnreachable
            ? 'A platform could not be reached, so nothing was added this time.'
            : null,
        clearAutoNote: !auto.platformsUnreachable,
        error: report.error,
        clearError: report.error == null,
      ),
    );
  }
}
