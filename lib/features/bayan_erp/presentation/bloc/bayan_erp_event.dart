import 'package:equatable/equatable.dart';

import '../../data/models/erp_product_model.dart';
import 'bayan_erp_state.dart';

sealed class BayanErpEvent extends Equatable {
  const BayanErpEvent();

  @override
  List<Object?> get props => [];
}

/// User switched to a different ERP tab.
/// The Bloc lazy-loads data for the new tab if not already fetched.
final class BayanErpTabSelected extends BayanErpEvent {
  const BayanErpTabSelected(this.tab);

  final BayanErpTab tab;

  @override
  List<Object?> get props => [tab];
}

/// Explicit refresh of the currently active tab.
final class BayanErpRefreshRequested extends BayanErpEvent {
  const BayanErpRefreshRequested();
}

/// User changed the "modified since" date filter.
/// Resets all cached data and reloads the active tab.
final class BayanErpDateChanged extends BayanErpEvent {
  const BayanErpDateChanged(this.date);

  /// Null clears the filter (fetch all records).
  final DateTime? date;

  @override
  List<Object?> get props => [date];
}

/// Advance to the next page of the active tab's data.
final class BayanErpNextPageRequested extends BayanErpEvent {
  const BayanErpNextPageRequested();
}

/// Go back to the previous page of the active tab's data.
final class BayanErpPrevPageRequested extends BayanErpEvent {
  const BayanErpPrevPageRequested();
}

/// Jump to a zero-based page of the active tab's data.
final class BayanErpPageSelected extends BayanErpEvent {
  const BayanErpPageSelected(this.page);

  final int page;

  @override
  List<Object?> get props => [page];
}

/// Changes how many products are requested per page and returns to page one.
final class BayanErpProductsPageSizeChanged extends BayanErpEvent {
  const BayanErpProductsPageSizeChanged(this.pageSize);

  final int pageSize;

  @override
  List<Object?> get props => [pageSize];
}

/// Filters the loaded products page by name, short name, or ID.
final class BayanErpProductsSearchChanged extends BayanErpEvent {
  const BayanErpProductsSearchChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

/// Filters the loaded products page by stock level. Null shows all.
final class BayanErpProductsStockFilterChanged extends BayanErpEvent {
  const BayanErpProductsStockFilterChanged(this.level);

  final ErpStockLevel? level;

  @override
  List<Object?> get props => [level];
}
