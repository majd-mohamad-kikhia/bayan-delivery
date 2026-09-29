import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/bayan_erp_repository.dart';
import 'bayan_erp_event.dart';
import 'bayan_erp_state.dart';

/// Manages all Bayan ERP data across five tab sections.
///
/// Design principles:
/// - **Lazy loading**: data is fetched only when its tab is first visited.
/// - **Independent lifecycles**: each tab has its own status/error; a failure
///   on Products does not affect Customers.
/// - **Guard against concurrent fetches**: a tab that is already loading will
///   not trigger a second request.
class BayanErpBloc extends Bloc<BayanErpEvent, BayanErpState> {
  BayanErpBloc({required BayanErpRepository repository})
      : _repo = repository,
        super(const BayanErpState()) {
    on<BayanErpTabSelected>(_onTabSelected);
    on<BayanErpRefreshRequested>(_onRefreshRequested);
    on<BayanErpDateChanged>(_onDateChanged);
    on<BayanErpNextPageRequested>(_onNextPage);
    on<BayanErpPrevPageRequested>(_onPrevPage);
    on<BayanErpPageSelected>(_onPageSelected);
    on<BayanErpProductsPageSizeChanged>(_onProductsPageSizeChanged);
    on<BayanErpProductsSearchChanged>(_onProductsSearchChanged);
    on<BayanErpProductsStockFilterChanged>(_onProductsStockFilterChanged);
  }

  final BayanErpRepository _repo;

  // ─── Event handlers ───────────────────────────────────────────────────────

  Future<void> _onTabSelected(
    BayanErpTabSelected event,
    Emitter<BayanErpState> emit,
  ) async {
    if (event.tab == state.activeTab) return;
    emit(state.copyWith(activeTab: event.tab));
    // Lazy load: fetch only if this tab has never been loaded.
    if (state.activeStatus == BayanErpStatus.initial) {
      await _fetchActive(emit);
    }
  }

  Future<void> _onRefreshRequested(
    BayanErpRefreshRequested event,
    Emitter<BayanErpState> emit,
  ) =>
      _fetchActive(emit, force: true);

  Future<void> _onDateChanged(
    BayanErpDateChanged event,
    Emitter<BayanErpState> emit,
  ) async {
    // Reset every tab back to initial so all re-fetch with the new filter.
    emit(BayanErpState(
      activeTab: state.activeTab,
      sinceDate: event.date,
      productsPageSize: state.productsPageSize,
    ));
    await _fetchActive(emit);
  }

  Future<void> _onNextPage(
    BayanErpNextPageRequested event,
    Emitter<BayanErpState> emit,
  ) async {
    if (!state.canGoNext) return;
    emit(_withPage(state, state.activePage + 1));
    await _fetchActive(emit, force: true);
  }

  Future<void> _onPrevPage(
    BayanErpPrevPageRequested event,
    Emitter<BayanErpState> emit,
  ) async {
    if (!state.canGoPrev) return;
    emit(_withPage(state, state.activePage - 1));
    await _fetchActive(emit, force: true);
  }

  Future<void> _onPageSelected(
    BayanErpPageSelected event,
    Emitter<BayanErpState> emit,
  ) async {
    if (!state.hasPagination || event.page < 0 || event.page == state.activePage) return;
    emit(_withPage(state, event.page));
    await _fetchActive(emit, force: true);
  }

  Future<void> _onProductsPageSizeChanged(
    BayanErpProductsPageSizeChanged event,
    Emitter<BayanErpState> emit,
  ) async {
    if (event.pageSize <= 0 || event.pageSize == state.productsPageSize) return;
    emit(state.copyWith(productsPageSize: event.pageSize, productsPage: 0));
    await _fetchProducts(emit, force: true);
  }

  void _onProductsSearchChanged(
    BayanErpProductsSearchChanged event,
    Emitter<BayanErpState> emit,
  ) {
    if (event.query == state.productsQuery) return;
    emit(state.copyWith(productsQuery: event.query));
  }

  void _onProductsStockFilterChanged(
    BayanErpProductsStockFilterChanged event,
    Emitter<BayanErpState> emit,
  ) {
    if (event.level == state.productsStockFilter) return;
    emit(event.level == null
        ? state.copyWith(clearProductsStockFilter: true)
        : state.copyWith(productsStockFilter: event.level));
  }

  // ─── Routing ──────────────────────────────────────────────────────────────

  Future<void> _fetchActive(
    Emitter<BayanErpState> emit, {
    bool force = false,
  }) =>
      switch (state.activeTab) {
        BayanErpTab.customers => _fetchCustomers(emit, force: force),
        BayanErpTab.products => _fetchProducts(emit, force: force),
        BayanErpTab.salesmen => _fetchSalesmen(emit, force: force),
        BayanErpTab.agents => _fetchAgents(emit, force: force),
        BayanErpTab.stores => _fetchStores(emit, force: force),
      };

  // ─── Per-tab fetchers ─────────────────────────────────────────────────────

  Future<void> _fetchCustomers(
    Emitter<BayanErpState> emit, {
    bool force = false,
  }) async {
    if (!force && state.customersStatus == BayanErpStatus.loading) return;
    emit(state.copyWith(
      customersStatus: BayanErpStatus.loading,
      clearCustomersError: true,
    ));
    try {
      final data = await _repo.getCustomers(
        since: state.sinceDate,
        offset: state.customersPage * state.pageSize,
        limit: state.pageSize,
      );
      emit(state.copyWith(customersStatus: BayanErpStatus.success, customers: data));
    } catch (e) {
      emit(state.copyWith(
        customersStatus: BayanErpStatus.failure,
        customersError: e.toString(),
      ));
    }
  }

  Future<void> _fetchProducts(
    Emitter<BayanErpState> emit, {
    bool force = false,
  }) async {
    if (!force && state.productsStatus == BayanErpStatus.loading) return;
    emit(state.copyWith(
      productsStatus: BayanErpStatus.loading,
      clearProductsError: true,
    ));
    try {
      final data = await _repo.getProducts(
        since: state.sinceDate,
        offset: state.productsPage * state.productsPageSize,
        limit: state.productsPageSize,
      );
      emit(state.copyWith(productsStatus: BayanErpStatus.success, products: data));
    } catch (e) {
      emit(state.copyWith(
        productsStatus: BayanErpStatus.failure,
        productsError: e.toString(),
      ));
    }
  }

  Future<void> _fetchSalesmen(
    Emitter<BayanErpState> emit, {
    bool force = false,
  }) async {
    if (!force && state.salesmenStatus == BayanErpStatus.loading) return;
    emit(state.copyWith(
      salesmenStatus: BayanErpStatus.loading,
      clearSalesmenError: true,
    ));
    try {
      final data = await _repo.getSalesmen(since: state.sinceDate);
      emit(state.copyWith(salesmenStatus: BayanErpStatus.success, salesmen: data));
    } catch (e) {
      emit(state.copyWith(
        salesmenStatus: BayanErpStatus.failure,
        salesmenError: e.toString(),
      ));
    }
  }

  Future<void> _fetchAgents(
    Emitter<BayanErpState> emit, {
    bool force = false,
  }) async {
    if (!force && state.agentsStatus == BayanErpStatus.loading) return;
    emit(state.copyWith(
      agentsStatus: BayanErpStatus.loading,
      clearAgentsError: true,
    ));
    try {
      // getAgent uses 1-based page numbers.
      final data = await _repo.getAgents(
        since: state.sinceDate,
        number: state.agentsPage + 1,
        limit: state.pageSize,
      );
      emit(state.copyWith(agentsStatus: BayanErpStatus.success, agents: data));
    } catch (e) {
      emit(state.copyWith(
        agentsStatus: BayanErpStatus.failure,
        agentsError: e.toString(),
      ));
    }
  }

  Future<void> _fetchStores(
    Emitter<BayanErpState> emit, {
    bool force = false,
  }) async {
    if (!force && state.storesStatus == BayanErpStatus.loading) return;
    emit(state.copyWith(
      storesStatus: BayanErpStatus.loading,
      clearStoresError: true,
    ));
    try {
      final data = await _repo.getStores(since: state.sinceDate);
      emit(state.copyWith(storesStatus: BayanErpStatus.success, stores: data));
    } catch (e) {
      emit(state.copyWith(
        storesStatus: BayanErpStatus.failure,
        storesError: e.toString(),
      ));
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  static BayanErpState _withPage(BayanErpState s, int page) {
    final safePage = page < 0 ? 0 : page;
    return switch (s.activeTab) {
      BayanErpTab.customers => s.copyWith(customersPage: safePage),
      BayanErpTab.products => s.copyWith(productsPage: safePage),
      BayanErpTab.agents => s.copyWith(agentsPage: safePage),
      _ => s,
    };
  }
}
