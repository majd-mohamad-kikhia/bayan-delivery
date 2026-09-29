import 'dart:async';
import 'dart:io';

import 'package:equatable/equatable.dart';

import '../network/api_exception.dart';
import '../platforms/common/platform_api_exception.dart';
import 'app_error_kind.dart';

export 'app_error_kind.dart';

/// A failure ready for display: [kind] picks the friendly localized text,
/// [detail] keeps the technical specifics for the "Details" section.
///
/// Blocs store this instead of `e.toString()` so the UI never shows raw
/// exception text as the headline.
final class AppError extends Equatable {
  const AppError(this.kind, {this.detail});

  factory AppError.from(Object error) => switch (error) {
        AppError() => error,
        PlatformApiException() => AppError(
            _platformKind(error.kind),
            detail: _join([
              error.message,
              error.platform.label,
              if (error.statusCode != null) 'HTTP ${error.statusCode}',
              if (error.code != null) 'code ${error.code}',
              error.endpointId,
            ]),
          ),
        ApiException() => AppError(
            error.errorKind,
            detail: _join([
              error.message,
              if (error.statusCode != null) 'HTTP ${error.statusCode}',
              error.endpoint,
            ]),
          ),
        TimeoutException() => AppError(AppErrorKind.timeout, detail: '$error'),
        SocketException() => AppError(AppErrorKind.offline, detail: '$error'),
        _ => AppError(AppErrorKind.unknown, detail: '$error'),
      };

  final AppErrorKind kind;
  final String? detail;

  static AppErrorKind _platformKind(PlatformErrorKind kind) => switch (kind) {
        PlatformErrorKind.notConfigured => AppErrorKind.notConfigured,
        PlatformErrorKind.transport => AppErrorKind.offline,
        PlatformErrorKind.executor => AppErrorKind.server,
        PlatformErrorKind.unauthorized => AppErrorKind.unauthorized,
        PlatformErrorKind.rateLimited => AppErrorKind.rateLimited,
        PlatformErrorKind.serverError => AppErrorKind.server,
        PlatformErrorKind.rejected => AppErrorKind.rejected,
      };

  static String? _join(List<String?> parts) {
    final text = parts.whereType<String>().where((p) => p.isNotEmpty).join('\n');
    return text.isEmpty ? null : text;
  }

  @override
  List<Object?> get props => [kind, detail];
}
