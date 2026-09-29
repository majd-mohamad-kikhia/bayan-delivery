import 'package:flutter/material.dart';

import '../errors/app_error.dart';
import '../localization/common_strings.dart';
import '../theme/app_theme.dart';

/// Icon + accent colour per error kind, shared by every error surface so the
/// same problem always looks the same.
extension AppErrorStyle on AppErrorKind {
  IconData get icon => switch (this) {
        AppErrorKind.offline => Icons.wifi_off_rounded,
        AppErrorKind.timeout => Icons.hourglass_top_rounded,
        AppErrorKind.unauthorized => Icons.lock_outline_rounded,
        AppErrorKind.notConfigured => Icons.settings_suggest_outlined,
        AppErrorKind.rateLimited => Icons.speed_rounded,
        AppErrorKind.server => Icons.dns_outlined,
        AppErrorKind.rejected => Icons.block_rounded,
        AppErrorKind.unknown => Icons.error_outline_rounded,
      };

  Color get color => switch (this) {
        AppErrorKind.offline ||
        AppErrorKind.timeout ||
        AppErrorKind.rateLimited =>
          AppTheme.warning,
        AppErrorKind.unauthorized ||
        AppErrorKind.notConfigured =>
          AppTheme.primary,
        AppErrorKind.server ||
        AppErrorKind.rejected ||
        AppErrorKind.unknown =>
          AppTheme.coral,
      };
}

/// The sentence shown under an error title. A rejection shows the server's
/// own reason (its first line); other kinds show localized advice.
String errorMessageOf(AppError error, CommonStrings strings) {
  final detail = error.detail;
  if (error.kind == AppErrorKind.rejected && detail != null) {
    return detail.split('\n').first;
  }
  return strings.errorAdvice(error.kind);
}
