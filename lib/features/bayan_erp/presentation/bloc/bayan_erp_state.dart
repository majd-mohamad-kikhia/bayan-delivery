import 'package:equatable/equatable.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_error.dart';
import '../../data/models/agent_model.dart';
import '../../data/models/customer_model.dart';
import '../../data/models/erp_product_model.dart';
import '../../data/models/salesman_model.dart';
import '../../data/models/store_model.dart';

// ─── Enums ────────────────────────────────────────────────────────────────────

enum BayanErpTab { products, customers, salesmen, agents, stores }

enum BayanErpStatus { initial, loading, success, failure }

// ─── State ────────────────────────────────────────────────────────────────────

/// Immutable state for [BayanErpBloc].
///
/// Each ERP entity type has its own status, data list, page index, and
/// optional error message — enabling independent loading lifecycles per tab.
final class BayanErpState extends Equatable {
  const BayanErpState({
    this.activeTab = BayanErpTab.products,
    this.sinceDate,
    // ── Customers
    this.customersStatus = BayanErpStatus.initial,
    this.customers = const [],
    this.customersPage = 0,
    this.customersError,
    // ── Products
    this.productsStatus = BayanErpStatus.initial,
    this.products = const [],
    this.productsPage = 0,
    this.productsError,
    this.productsPageSize = AppConstants.erpPageSize,
    this.productsQuery = '',
    this.productsStockFilter,
    // ── Salesmen
    this.salesmenStatus = BayanErpStatus.initial,
    this.salesmen = const [],
    this.salesmenError,
    // ── Agents
    this.agentsStatus = BayanErpStatus.initial,
    this.agents = const [],
    this.agentsPage = 0,
    this.agentsError,
    // ── Stores
    this.storesStatus = BayanErpStatus.initial,
    this.stores = const [],
    this.storesError,
  });

  final BayanErpTab activeTab;

  /// Optional date filter: fetch records modified/created on or after this date.
  final DateTime? sinceDate;

  // ── Customers ──────────────────────────────────────────────────────────────
  final BayanErpStatus customersStatus;
  final List<CustomerModel> customers;
  final int customersPage;
  final AppError? customersError;

  // ── Products ───────────────────────────────────────────────────────────────
  final BayanErpStatus productsStatus;
  final List<ErpProductModel> products;
  final int productsPage;
  final AppError? productsError;
  final int productsPageSize;

  /// Client-side filters applied to the currently loaded products page.
  final String productsQuery;
  final ErpStockLevel? productsStockFilter;

  // ── Salesmen ───────────────────────────────────────────────────────────────
  final BayanErpStatus salesmenStatus;
  final List<SalesmanModel> salesmen;
  final AppError? salesmenError;

  // ── Agents ─────────────────────────────────────────────────────────────────
  final BayanErpStatus agentsStatus;
  final List<AgentModel> agents;

  /// The `/getAgent` endpoint uses 1-based page numbers (`number` param).
  final int agentsPage;
  final AppError? agentsError;

  // ── Stores ─────────────────────────────────────────────────────────────────
  final BayanErpStatus storesStatus;
  final List<StoreModel> stores;
  final AppError? storesError;

  // ─── Computed helpers ─────────────────────────────────────────────────────

  int get pageSize => AppConstants.erpPageSize;

  BayanErpStatus get activeStatus => switch (activeTab) {
        BayanErpTab.customers => customersStatus,
        BayanErpTab.products => productsStatus,
        BayanErpTab.salesmen => salesmenStatus,
        BayanErpTab.agents => agentsStatus,
        BayanErpTab.stores => storesStatus,
      };

  /// Zero-based page index for the active tab (0 if tab has no pagination).
  int get activePage => switch (activeTab) {
        BayanErpTab.customers => customersPage,
        BayanErpTab.products => productsPage,
        BayanErpTab.agents => agentsPage,
        _ => 0,
      };

  /// True if there may be a next page (last fetch returned a full page).
  bool get canGoNext => switch (activeTab) {
        BayanErpTab.customers => customers.length >= pageSize,
        BayanErpTab.products => products.length >= productsPageSize,
        BayanErpTab.agents => agents.length >= pageSize,
        _ => false,
      };

  bool get canGoPrev => activePage > 0;

  bool get hasPagination => switch (activeTab) {
        BayanErpTab.customers || BayanErpTab.products || BayanErpTab.agents => true,
        _ => false,
      };

  bool get hasProductFilters => productsQuery.isNotEmpty || productsStockFilter != null;

  List<ErpProductModel> get visibleProducts {
    if (!hasProductFilters) return products;
    final query = productsQuery.trim().toLowerCase();
    final level = productsStockFilter;
    return products
        .where((p) => (level == null || p.stockLevel == level) && p.matches(query))
        .toList(growable: false);
  }

  ({int available, int low, int out}) get productsStockSummary {
    var available = 0, low = 0, out = 0;
    for (final p in products) {
      switch (p.stockLevel) {
        case ErpStockLevel.available:
          available++;
        case ErpStockLevel.low:
          low++;
        case ErpStockLevel.out:
          out++;
      }
    }
    return (available: available, low: low, out: out);
  }

  // ─── copyWith ─────────────────────────────────────────────────────────────

  BayanErpState copyWith({
    BayanErpTab? activeTab,
    DateTime? sinceDate,
    bool clearSinceDate = false,
    // Customers
    BayanErpStatus? customersStatus,
    List<CustomerModel>? customers,
    int? customersPage,
    AppError? customersError,
    bool clearCustomersError = false,
    // Products
    BayanErpStatus? productsStatus,
    List<ErpProductModel>? products,
    int? productsPage,
    AppError? productsError,
    bool clearProductsError = false,
    int? productsPageSize,
    String? productsQuery,
    ErpStockLevel? productsStockFilter,
    bool clearProductsStockFilter = false,
    // Salesmen
    BayanErpStatus? salesmenStatus,
    List<SalesmanModel>? salesmen,
    AppError? salesmenError,
    bool clearSalesmenError = false,
    // Agents
    BayanErpStatus? agentsStatus,
    List<AgentModel>? agents,
    int? agentsPage,
    AppError? agentsError,
    bool clearAgentsError = false,
    // Stores
    BayanErpStatus? storesStatus,
    List<StoreModel>? stores,
    AppError? storesError,
    bool clearStoresError = false,
  }) =>
      BayanErpState(
        activeTab: activeTab ?? this.activeTab,
        sinceDate: clearSinceDate ? null : (sinceDate ?? this.sinceDate),
        customersStatus: customersStatus ?? this.customersStatus,
        customers: customers ?? this.customers,
        customersPage: customersPage ?? this.customersPage,
        customersError: clearCustomersError ? null : (customersError ?? this.customersError),
        productsStatus: productsStatus ?? this.productsStatus,
        products: products ?? this.products,
        productsPage: productsPage ?? this.productsPage,
        productsError: clearProductsError ? null : (productsError ?? this.productsError),
        productsPageSize: productsPageSize ?? this.productsPageSize,
        productsQuery: productsQuery ?? this.productsQuery,
        productsStockFilter: clearProductsStockFilter
            ? null
            : (productsStockFilter ?? this.productsStockFilter),
        salesmenStatus: salesmenStatus ?? this.salesmenStatus,
        salesmen: salesmen ?? this.salesmen,
        salesmenError: clearSalesmenError ? null : (salesmenError ?? this.salesmenError),
        agentsStatus: agentsStatus ?? this.agentsStatus,
        agents: agents ?? this.agents,
        agentsPage: agentsPage ?? this.agentsPage,
        agentsError: clearAgentsError ? null : (agentsError ?? this.agentsError),
        storesStatus: storesStatus ?? this.storesStatus,
        stores: stores ?? this.stores,
        storesError: clearStoresError ? null : (storesError ?? this.storesError),
      );

  @override
  List<Object?> get props => [
        activeTab,
        sinceDate,
        customersStatus, customers, customersPage, customersError,
        productsStatus, products, productsPage, productsError,
        productsPageSize, productsQuery, productsStockFilter,
        salesmenStatus, salesmen, salesmenError,
        agentsStatus, agents, agentsPage, agentsError,
        storesStatus, stores, storesError,
      ];
}
