import 'package:bayan_desktop/core/network/api_client.dart';
import 'package:bayan_desktop/core/platforms/auth/auth_token.dart';
import 'package:bayan_desktop/core/platforms/common/platform_executor.dart';
import 'package:bayan_desktop/core/platforms/common/platform_request.dart';
import 'package:bayan_desktop/core/platforms/config/platform_credentials_store.dart';
import 'package:bayan_desktop/core/platforms/platform_apis.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records every request and answers through [handler].
class FakeExecutor implements PlatformExecutor {
  FakeExecutor(this.handler);

  Object? Function(PlatformRequest request) handler;
  final List<PlatformRequest> requests = [];

  @override
  Future<Object?> execute(PlatformRequest request) async {
    requests.add(request);
    await Future<void>.delayed(Duration.zero);
    return handler(request);
  }

  List<PlatformRequest> requestsTo(String endpointId) =>
      requests.where((r) => r.endpoint.id == endpointId).toList();
}

/// [ApiClient] whose executor route answers with a canned envelope.
class FakeApiClient extends ApiClient {
  FakeApiClient(this.envelope);

  Map<String, dynamic> Function(Object? payload) envelope;
  Object? lastPayload;
  Duration? lastTimeout;

  @override
  Future<Map<String, dynamic>> postEnvelope(
    String path, {
    Object? data,
    Duration? timeout,
  }) async {
    lastPayload = data;
    lastTimeout = timeout;
    return envelope(data);
  }
}

const keetaPrefs = {
  'platform.keeta.app_id': 123,
  'platform.keeta.app_secret': 'secret',
};

const hsPrefs = {
  'platform.hs.client_id': 'client',
  'platform.hs.client_secret': 'client-secret',
  'platform.hs.chain_id': 'chain-1',
  'platform.hs.vendor_id': 'vendor-1',
  'platform.hs.environment': 'sandbox',
};

Future<PlatformApis> buildApis(
  FakeExecutor executor, {
  Map<String, Object> prefs = const {...keetaPrefs, ...hsPrefs},
  AuthToken? keetaSeed,
  DateTime Function()? clock,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final preferences = await SharedPreferences.getInstance();
  return PlatformApis(
    apiClient: FakeApiClient((_) => const {}),
    preferences: preferences,
    executor: executor,
    credentials: PlatformCredentialsStore(
      preferences,
      keetaSeedToken: keetaSeed,
    ),
    clock: clock,
  );
}

Map<String, Object?> keetaOk([Object? data]) => {
  'code': 0,
  'message': 'Success',
  'data': data,
};
