import 'package:shared_preferences/shared_preferences.dart';

import '../network/api_client.dart';
import 'auth/token_store.dart';
import 'common/platform_executor.dart';
import 'common/platform_utils.dart';
import 'config/platform_credentials_store.dart';
import 'hungerstation/hs_api.dart';
import 'hungerstation/hs_auth.dart';
import 'hungerstation/hs_client.dart';
import 'keeta/keeta_api.dart';
import 'keeta/keeta_auth.dart';
import 'keeta/keeta_client.dart';

/// Entry point for direct platform calls, built once at startup and
/// provided through `RepositoryProvider`. Construction is cheap — nothing
/// touches the network until an API method is called.
///
/// ```dart
/// final apis = context.read<PlatformApis>();
/// await apis.keeta.orders.markReady(shopId: shopId, orderViewId: id);
/// await apis.hungerStation.outletStatus();
/// ```
class PlatformApis {
  PlatformApis._({
    required this.credentials,
    required this.keeta,
    required this.hungerStation,
  });

  factory PlatformApis({
    required ApiClient apiClient,
    required SharedPreferences preferences,
    PlatformExecutor? executor,
    PlatformCredentialsStore? credentials,
    Clock? clock,
  }) {
    final exec = executor ?? PlatformExecutor(apiClient);
    final store = credentials ?? PlatformCredentialsStore(preferences);
    final tokens = TokenStore(preferences);

    final keetaClient = KeetaClient(
      executor: exec,
      credentials: store,
      clock: clock,
      auth: KeetaAuth(
        executor: exec,
        credentials: store,
        tokens: tokens,
        clock: clock,
      ),
    );
    final hsClient = HsClient(
      executor: exec,
      credentials: store,
      auth: HsAuth(
        executor: exec,
        credentials: store,
        tokens: tokens,
        clock: clock,
      ),
    );

    return PlatformApis._(
      credentials: store,
      keeta: KeetaApi(client: keetaClient),
      hungerStation: HungerStationApi(client: hsClient),
    );
  }

  static Future<PlatformApis> create({required ApiClient apiClient}) async =>
      PlatformApis(
        apiClient: apiClient,
        preferences: await SharedPreferences.getInstance(),
      );

  final PlatformCredentialsStore credentials;
  final KeetaApi keeta;
  final HungerStationApi hungerStation;
}
