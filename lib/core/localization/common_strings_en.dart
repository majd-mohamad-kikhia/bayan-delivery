import '../errors/app_error_kind.dart';
import 'common_strings.dart';

final class CommonStringsEn extends CommonStrings {
  const CommonStringsEn();

  @override
  String get appName => 'Al-Bayan Delivery Hub';
  @override
  String get brandName => 'Al-Bayan';
  @override
  String get brandTagline => 'Delivery Hub';

  @override
  String get retry => 'Retry';
  @override
  String get cancel => 'Cancel';
  @override
  String get close => 'Close';
  @override
  String get save => 'Save';
  @override
  String get confirm => 'Confirm';
  @override
  String get back => 'Back';
  @override
  String get edit => 'Edit';
  @override
  String get copy => 'Copy';
  @override
  String copied(String label) => '$label copied';

  @override
  String get loading => 'Loading…';
  @override
  String get somethingWentWrong => 'Something went wrong.';
  @override
  String get active => 'Active';
  @override
  String get inactive => 'Inactive';
  @override
  String get all => 'All';

  @override
  String errorTitle(AppErrorKind kind) => switch (kind) {
        AppErrorKind.offline => "Can't reach the server",
        AppErrorKind.timeout => 'The server is taking too long',
        AppErrorKind.unauthorized => 'Access denied',
        AppErrorKind.notConfigured => 'Setup required',
        AppErrorKind.rateLimited => 'Too many requests',
        AppErrorKind.server => 'Server error',
        AppErrorKind.rejected => 'Request was declined',
        AppErrorKind.unknown => 'Something went wrong',
      };
  @override
  String errorAdvice(AppErrorKind kind) => switch (kind) {
        AppErrorKind.offline =>
          'Check your internet connection and that the backend is running, then try again.',
        AppErrorKind.timeout =>
          'The connection is slow or the server is busy. Please try again in a moment.',
        AppErrorKind.unauthorized =>
          'The credentials were rejected. Check the account settings.',
        AppErrorKind.notConfigured =>
          'Some credentials or settings are missing for this service.',
        AppErrorKind.rateLimited =>
          'Please wait a few seconds before trying again.',
        AppErrorKind.server =>
          'The server ran into a problem. Please try again shortly.',
        AppErrorKind.rejected => "The server couldn't process this request.",
        AppErrorKind.unknown =>
          'An unexpected error occurred. Please try again.',
      };
  @override
  String get showDetails => 'Show details';
  @override
  String get hideDetails => 'Hide details';
  @override
  String get copyDetails => 'Copy details';
  @override
  String get detailsCopied => 'Details copied';
  @override
  String get dismiss => 'Dismiss';
  @override
  String get showingCachedData => 'Showing the last loaded data';

  @override
  String get language => 'Language';

  @override
  String get justNow => 'just now';
  @override
  String secondsAgo(int n) => '${n}s ago';
  @override
  String minutesAgo(int n) => '${n}m ago';
  @override
  String hoursAgo(int n) => '${n}h ago';
  @override
  String daysAgo(int n) => '${n}d ago';

  @override
  String money(double amount) => 'SAR ${amount.toStringAsFixed(2)}';

  @override
  String get keeta => 'Keeta';
  @override
  String get hungerStation => 'HungerStation';
  @override
  String get careem => 'Careem';
}
