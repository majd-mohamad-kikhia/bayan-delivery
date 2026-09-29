import '../../../../core/network/bayan_erp_client.dart';
import '../models/agent_model.dart';
import '../models/customer_model.dart';
import '../models/erp_product_model.dart';
import '../models/salesman_model.dart';
import '../models/store_model.dart';

/// Raw data access layer for every Bayan ERP endpoint.
///
/// All network I/O is delegated to [BayanErpClient]; this class is responsible
/// only for building query parameters and deserialising the responses.
///
/// **API note:** the server uses the (intentionally preserved) typo `limet`
/// instead of `limit` in query parameters, matching the official spec.
class BayanErpDatasource {
  const BayanErpDatasource(this._client);

  final BayanErpClient _client;

  // ── Customers ─────────────────────────────────────────────────────────────

  /// `GET /getCustomers`
  Future<List<CustomerModel>> fetchCustomers({
    DateTime? since,
    int offset = 0,
    int limit = 20,
  }) async {
    final raw = await _client.getList('/getCustomers', query: {
      if (since != null) 'date': _fmtDate(since),
      'offset': offset,
      'limet': limit,
    });
    return raw.map(CustomerModel.fromJson).toList(growable: false);
  }

  // ── Products ──────────────────────────────────────────────────────────────

  /// `GET /getProducts`
  Future<List<ErpProductModel>> fetchProducts({
    DateTime? since,
    int offset = 0,
    int limit = 20,
  }) async {
    final raw = await _client.getList('/getProducts', query: {
      if (since != null) 'date': _fmtDate(since),
      'offset': offset,
      'limet': limit,
    });
    return raw.map(ErpProductModel.fromJson).toList(growable: false);
  }

  // ── Salesmen ──────────────────────────────────────────────────────────────

  /// `GET /getSalesman`
  Future<List<SalesmanModel>> fetchSalesmen({DateTime? since}) async {
    final raw = await _client.getList('/getSalesman', query: {
      if (since != null) 'date': _fmtDate(since),
    });
    return raw.map(SalesmanModel.fromJson).toList(growable: false);
  }

  // ── Agents ────────────────────────────────────────────────────────────────

  /// `GET /getAgent`
  ///
  /// [number] is the page-number parameter this endpoint uses (not offset).
  Future<List<AgentModel>> fetchAgents({
    DateTime? since,
    int number = 1,
    int limit = 20,
  }) async {
    final raw = await _client.getList('/getAgent', query: {
      if (since != null) 'date': _fmtDate(since),
      'number': number,
      'limet': limit,
    });
    return raw.map(AgentModel.fromJson).toList(growable: false);
  }

  // ── Stores ────────────────────────────────────────────────────────────────

  /// `GET /getStores`
  Future<List<StoreModel>> fetchStores({DateTime? since}) async {
    final raw = await _client.getList('/getStores', query: {
      if (since != null) 'date': _fmtDate(since),
    });
    return raw.map(StoreModel.fromJson).toList(growable: false);
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  static String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
