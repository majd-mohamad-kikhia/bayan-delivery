import 'package:flutter/material.dart';

import '../errors/app_error.dart';
import '../localization/locale_context.dart';
import '../theme/app_theme.dart';
import 'error_style.dart';

/// Slim inline notice for a non-blocking error, e.g. a background refresh
/// failed while older data is still on screen.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({
    super.key,
    required this.error,
    this.title,
    this.onRetry,
  });

  final AppError error;
  final String? title;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final strings = context.commonStrings;
    final kind = error.kind;
    final color = kind.color;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsetsDirectional.fromSTEB(10, 8, 8, 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(kind.icon, size: 15, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Tooltip(
              message: error.detail ?? '',
              waitDuration: const Duration(milliseconds: 400),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: title ?? strings.errorTitle(kind),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    TextSpan(text: '  ·  ${errorMessageOf(error, strings)}'),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
              ),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(strings.retry),
              style: TextButton.styleFrom(
                foregroundColor: color,
                textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
