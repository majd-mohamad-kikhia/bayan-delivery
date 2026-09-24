import '../auth/auth_token.dart';
import '../common/platform_utils.dart';
import 'keeta_auth.dart';
import 'keeta_client.dart';
import 'keeta_endpoints.dart';
import 'keeta_menu_api.dart';
import 'keeta_orders_api.dart';
import 'keeta_response.dart';
import 'keeta_shop_api.dart';

/// Typed access to every Keeta Open API operation.
///
/// ```dart
/// final keeta = context.read<PlatformApis>().keeta;
/// await keeta.orders.confirm(shopId: 466663, orderViewId: 756823555555859);
/// final shops = await keeta.account.authorizedShops();
/// ```
///
/// Anything not wrapped is still one line away through [client]:
/// `keeta.client.send(KeetaEndpoints.x, params: {...})`.
class KeetaApi {
  KeetaApi({required this.client})
    : auth = client.auth,
      account = KeetaAccountApi(client),
      orders = KeetaOrdersApi(client),
      shop = KeetaShopApi(client),
      menu = KeetaMenuApi(client);

  final KeetaClient client;
  final KeetaAuth auth;
  final KeetaAccountApi account;
  final KeetaOrdersApi orders;
  final KeetaShopApi shop;
  final KeetaMenuApi menu;
}

/// Keeta Basic API: authorization scope, decryption, webhook setup.
class KeetaAccountApi {
  const KeetaAccountApi(this._client);

  final KeetaClient _client;

  static const int maxPageSize = 200;

  /// Exchanges an OAuth authorization code and stores the token pair.
  Future<AuthToken> exchangeAuthorizationCode(String code) =>
      _client.auth.exchangeAuthorizationCode(code);

  /// One page: `userId`, `brandId`, `brandName`, `authorizedShops[]`, `page`.
  Future<Map<String, dynamic>> authorizedResources({
    int pageNum = 1,
    int pageSize = maxPageSize,
  }) async => (await _client.send(
    KeetaEndpoints.authorizedResources,
    params: {'pageNum': pageNum, 'pageSize': pageSize},
  )).dataMap;

  /// Every authorized shop across all pages (`id`, `name`, `address`,
  /// `longitude`, `latitude`). Page 1 reveals the page count; the remaining
  /// pages are fetched in parallel.
  Future<List<Map<String, dynamic>>> authorizedShops() async {
    final first = await authorizedResources();
    final totalPages =
        ((first['page'] as Map?)?['totalPage'] as num?)?.toInt() ?? 1;
    final pages = totalPages <= 1
        ? [first]
        : [
            first,
            ...await mapConcurrent(
              [for (var page = 2; page <= totalPages; page++) page],
              _client.batchConcurrency,
              (page) => authorizedResources(pageNum: page),
            ),
          ];
    return [
      for (final page in pages)
        ...(page['authorizedShops'] as List? ?? const [])
            .whereType<Map<String, dynamic>>(),
    ];
  }

  /// Decrypts customer fields (`ENC_…`), chunked by 50.
  Future<KeetaResponse> decrypt({
    required int shopId,
    required List<String> cipherTexts,
  }) => _client.sendBatched(
    KeetaEndpoints.batchDecrypt,
    cipherTexts,
    (chunk) => {
      'shopId': shopId,
      'cipherInfos': [
        for (final text in chunk) {'cipherText': text},
      ],
    },
  );

  /// Points webhook [eventId] at [url] (`isTest` targets the test setup).
  Future<KeetaResponse> setWebhookUrl({
    required int eventId,
    required String url,
    bool isTest = false,
  }) => _client.send(
    KeetaEndpoints.setWebhookUrl,
    params: {'eventId': eventId, 'url': url, 'isTest': isTest ? 1 : 0},
  );
}
