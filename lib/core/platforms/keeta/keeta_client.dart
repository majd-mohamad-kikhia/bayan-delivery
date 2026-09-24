import '../common/platform_client.dart';
import '../common/platform_endpoint.dart';
import '../common/platform_executor.dart';
import '../common/platform_request.dart';
import '../common/platform_utils.dart';
import '../config/platform_credentials_store.dart';
import 'keeta_auth.dart';
import 'keeta_response.dart';
import 'keeta_signer.dart';

/// Signed transport for Keeta: every call carries `appId`, `accessToken`,
/// `timestamp` and `sig`, and every non-zero `code` becomes a
/// `PlatformApiException`.
///
/// Use it directly for anything the typed APIs don't wrap:
/// `client.send(KeetaEndpoints.syncMenu, params: {...})`.
class KeetaClient extends PlatformClient<KeetaResponse> {
  KeetaClient({
    required PlatformExecutor executor,
    required this.auth,
    required PlatformCredentialsStore credentials,
    Clock? clock,
    this.batchConcurrency = 3,
  }) : _credentials = credentials,
       _clock = clock ?? DateTime.now,
       super(executor);

  final KeetaAuth auth;
  final PlatformCredentialsStore _credentials;
  final Clock _clock;

  /// Chunks of one batched call sent in parallel. Keeta limits each appId to
  /// 10–100 QPS per endpoint; 3 in flight stays under the lowest limit.
  final int batchConcurrency;

  /// Sends [items] in chunks of [PlatformEndpoint.maxBatchSize], merging the
  /// results. An empty list costs no request.
  Future<KeetaResponse> sendBatched<T>(
    PlatformEndpoint endpoint,
    List<T> items,
    Map<String, Object?> Function(List<T> chunk) paramsFor,
  ) async {
    if (items.isEmpty) return KeetaResponse.merge(const []);
    final chunks = chunked(items, endpoint.maxBatchSize ?? items.length);
    final parts = await mapConcurrent(
      chunks,
      batchConcurrency,
      (chunk) => send(endpoint, params: paramsFor(chunk)),
    );
    return KeetaResponse.merge(parts);
  }

  @override
  Future<PlatformRequest> buildRequest(
    PlatformEndpoint endpoint,
    Map<String, Object?> params,
    Map<String, String> pathParams,
    String? device,
  ) async {
    final credentials = _credentials.requireKeeta();
    return KeetaSigner.signedRequest(
      endpoint: endpoint,
      credentials: credentials,
      params: params,
      now: _clock(),
      accessToken: endpoint.requiresAuth ? await auth.accessToken() : null,
      device: device,
    );
  }

  @override
  KeetaResponse interpret(PlatformEndpoint endpoint, Object? raw) =>
      KeetaResponse.fromRaw(raw, endpoint);

  @override
  Future<bool> reauthenticate(PlatformRequest failed) =>
      auth.recover(failed.params['accessToken'] as String?);
}
