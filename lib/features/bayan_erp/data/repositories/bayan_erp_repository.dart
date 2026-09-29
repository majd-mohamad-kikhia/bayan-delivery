import '../datasources/bayan_erp_datasource.dart';
import '../models/agent_model.dart';
import '../models/customer_model.dart';
import '../models/erp_product_model.dart';
import '../models/salesman_model.dart';
import '../models/store_model.dart';

/// Business-logic layer for Bayan ERP data.
///
/// Sits between the Bloc and the [BayanErpDatasource]; currently a thin
/// pass-through, but the right place to add caching, merging, or
/// transformation logic without touching either the Bloc or the network code.
class BayanErpRepository {
  const BayanErpRepository(this._datasource);

  final BayanErpDatasource _datasource;

  Future<List<CustomerModel>> getCustomers({
    DateTime? since,
    int offset = 0,
    int limit = 20,
  }) =>
      _datasource.fetchCustomers(since: since, offset: offset, limit: limit);

  Future<List<ErpProductModel>> getProducts({
    DateTime? since,
    int offset = 0,
    int limit = 20,
  }) =>
      _datasource.fetchProducts(since: since, offset: offset, limit: limit);

  Future<List<SalesmanModel>> getSalesmen({DateTime? since}) =>
      _datasource.fetchSalesmen(since: since);

  Future<List<AgentModel>> getAgents({
    DateTime? since,
    int number = 1,
    int limit = 20,
  }) =>
      _datasource.fetchAgents(since: since, number: number, limit: limit);

  Future<List<StoreModel>> getStores({DateTime? since}) =>
      _datasource.fetchStores(since: since);
}
