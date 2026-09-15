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

  static const Duration pollInterval = Duration(seconds: 4);
  static const Duration requestTimeout = Duration(seconds: 8);

  static const String defaultDongleNumber = 'DEV-DONGLE-001';
}
