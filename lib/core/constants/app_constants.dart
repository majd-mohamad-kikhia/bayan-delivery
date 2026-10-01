/// App-wide constants. Override at build/run time with --dart-define.
///
/// ```bash
/// flutter run -d macos --dart-define=API_BASE_URL=http://10.100.116.218:3001
/// ```
class AppConstants {
  const AppConstants._();

  static const String appName = 'Al-Bayan Delivery Hub';

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3001',
  );

  /// Backend route that runs `executeApiAndSendWebhook` for direct platform
  /// calls (see `lib/core/platforms`).
  static const String platformExecutorPath = String.fromEnvironment(
    'PLATFORM_EXECUTOR_PATH',
    defaultValue: '/api/execute',
  );

  /// Optional webhook URL / device id the executor forwards every platform
  /// result to. Empty = no forwarding (fastest: the executor waits for the
  /// forward, with retries, before it answers).
  static const String platformWebhookDevice = String.fromEnvironment('PLATFORM_WEBHOOK_DEVICE');

  /// Host serving `GET /poll/{deviceId}` (long-polling). Defaults to the API host.
  static const String devicePollBaseUrl = String.fromEnvironment(
    'POLL_BASE_URL',
    defaultValue: apiBaseUrl,
  );

  /// How long the server holds each poll open (it caps this at 60s).
  static const Duration devicePollHold = Duration(seconds: 25);

  static const Duration pollInterval = Duration(seconds: 4);
  static const Duration requestTimeout = Duration(seconds: 8);

  static const String defaultDongleNumber = 'DEV-DONGLE-001';

  // ── Bayan ERP (Accounting & Warehouses) ────────────────────────────────
  /// Local ERP server base URL.  Override at build/run time with --dart-define.
  /// ```bash
  /// flutter run -d windows --dart-define=BAYAN_ERP_BASE_URL=http://192.168.1.5:3003
  /// ```
  ///
  /// The default is `127.0.0.1`, not `localhost`: the Bayan API listens on IPv4
  /// only, and on Windows `localhost` tries IPv6 (`::1`) first, which costs
  /// ~2 s per new connection before falling back.
  static const String bayanErpBaseUrl = String.fromEnvironment(
    'BAYAN_ERP_BASE_URL',
    defaultValue: 'http://127.0.0.1:3003',
  );

  /// A reachable local server connects in milliseconds, so fail fast here.
  static const Duration erpConnectTimeout = Duration(seconds: 5);

  /// The server's first query after starting (or after idling) can be slow
  /// while it opens the accounting database.
  static const Duration erpReceiveTimeout = Duration(seconds: 30);
  static const int erpPageSize = 20;
}
