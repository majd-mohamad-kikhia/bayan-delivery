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
    defaultValue: 'http://10.100.116.218:3001',
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
}
