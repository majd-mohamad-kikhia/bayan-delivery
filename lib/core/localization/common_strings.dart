import '../errors/app_error_kind.dart';

/// Strings shared by every feature (actions, time, money, platform names).
///
/// Feature-specific text lives in each feature's `presentation/l10n/`.
abstract class CommonStrings {
  const CommonStrings();

  String get appName;
  String get brandName;
  String get brandTagline;

  // ── Actions ────────────────────────────────────────────────────────────
  String get retry;
  String get cancel;
  String get close;
  String get save;
  String get confirm;
  String get back;
  String get edit;
  String get copy;
  String copied(String label);

  // ── States ─────────────────────────────────────────────────────────────
  String get loading;
  String get somethingWentWrong;
  String get active;
  String get inactive;
  String get all;

  // ── Errors ─────────────────────────────────────────────────────────────
  String errorTitle(AppErrorKind kind);
  String errorAdvice(AppErrorKind kind);
  String get showDetails;
  String get hideDetails;
  String get copyDetails;
  String get detailsCopied;
  String get dismiss;
  String get showingCachedData;

  // ── Language ───────────────────────────────────────────────────────────
  String get language;

  // ── Time ───────────────────────────────────────────────────────────────
  String get justNow;
  String secondsAgo(int n);
  String minutesAgo(int n);
  String hoursAgo(int n);
  String daysAgo(int n);

  // ── Money ──────────────────────────────────────────────────────────────
  String money(double amount);

  // ── Platforms ──────────────────────────────────────────────────────────
  String get keeta;
  String get hungerStation;

  String platformName(String platformId) => switch (platformId) {
        'keeta' => keeta,
        'hungerstation' => hungerStation,
        _ => platformId,
      };
}
