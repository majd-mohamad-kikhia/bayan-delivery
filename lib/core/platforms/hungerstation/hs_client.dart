import '../common/delivery_platform.dart';
import '../common/platform_api_exception.dart';
import '../common/platform_client.dart';
import '../common/platform_endpoint.dart';
import '../common/platform_executor.dart';
import '../common/platform_request.dart';
import '../config/platform_credentials_store.dart';
import 'hs_auth.dart';

/// Bearer-token transport for HungerStation. Fills `{chain_id}` (and the
/// default `{vendor_id}`) from the credentials, and on a 401 drops the
/// cached token and replays the call once.
///
/// Use it directly for anything the typed API doesn't wrap:
/// `client.send(HsEndpoints.x, pathParams: {...}, params: {...})`.
class HsClient extends PlatformClient<Object?> {
  HsClient({
    required PlatformExecutor executor,
    required this.auth,
    required PlatformCredentialsStore credentials,
  }) : _credentials = credentials,
       super(executor);

  final HsAuth auth;
  final PlatformCredentialsStore _credentials;

  @override
  Future<PlatformRequest> buildRequest(
    PlatformEndpoint endpoint,
    Map<String, Object?> params,
    Map<String, String> pathParams,
    String? device,
  ) async {
    final credentials = _credentials.requireHungerStation();
    final vendorId = pathParams['vendor_id'] ?? credentials.vendorId;
    if (vendorId.isEmpty && endpoint.path.contains('{vendor_id}')) {
      throw PlatformApiException(
        'No HungerStation vendor — pass vendorId or set HS_VENDOR_ID.',
        platform: DeliveryPlatform.hungerStation,
        kind: PlatformErrorKind.notConfigured,
        endpointId: endpoint.id,
      );
    }

    final path = endpoint.resolvePath({
      ...pathParams,
      'chain_id': credentials.chainId,
      'vendor_id': vendorId,
    });
    final token = await auth.accessToken();
    return PlatformRequest(
      endpoint: endpoint,
      url: '${credentials.environment.baseUrl}$path',
      params: endpoint.method.sendsParamsAsQuery ? _query(params) : params,
      headers: {'Authorization': 'Bearer $token'},
      device: device,
    );
  }

  @override
  Object? interpret(PlatformEndpoint endpoint, Object? raw) => raw;

  @override
  Future<bool> reauthenticate(PlatformRequest failed) async {
    final header = failed.headers['Authorization'];
    await auth.invalidate(
      header != null && header.startsWith('Bearer ')
          ? header.substring(7)
          : null,
    );
    return true;
  }

  /// Query values as the API expects them: lists comma-joined.
  static Map<String, Object?> _query(Map<String, Object?> params) => {
    for (final entry in params.entries)
      entry.key: switch (entry.value) {
        final Iterable<Object?> list => list.join(','),
        final value => '$value',
      },
  };
}
