import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../errors/app_error.dart';
import '../localization/locale_context.dart';
import '../theme/app_theme.dart';
import 'app_snack_bar.dart';
import 'error_style.dart';

/// Full-area error state: illustrated icon, friendly title and advice, a
/// retry button, and the technical detail behind an expandable section.
///
/// Use [compact] inside panels and table areas.
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.error,
    this.onRetry,
    this.title,
    this.compact = false,
  });

  final AppError error;
  final VoidCallback? onRetry;

  /// Overrides the kind's default title (e.g. "Couldn't load orders").
  final String? title;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final strings = context.commonStrings;
    final kind = error.kind;
    final detail = error.detail;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(compact ? 20 : 32),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: compact ? 380 : 460),
          child: _Entrance(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _IconBadge(icon: kind.icon, color: kind.color, size: compact ? 60 : 84),
                SizedBox(height: compact ? 16 : 22),
                Text(
                  title ?? strings.errorTitle(kind),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: compact ? 15.5 : 19,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  errorMessageOf(error, strings),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: compact ? 12.5 : 13.5,
                    height: 1.55,
                    color: AppTheme.textSecondary,
                  ),
                ),
                if (onRetry != null) ...[
                  SizedBox(height: compact ? 16 : 22),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(strings.retry),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
                if (detail != null) ...[
                  const SizedBox(height: 10),
                  _ErrorDetails(detail: detail),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.color, required this.size});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        shape: BoxShape.circle,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: size * 0.38, color: color),
      ),
    );
  }
}

/// "Show details" toggle revealing the raw error text, selectable and
/// copyable for support.
class _ErrorDetails extends StatefulWidget {
  const _ErrorDetails({required this.detail});

  final String detail;

  @override
  State<_ErrorDetails> createState() => _ErrorDetailsState();
}

class _ErrorDetailsState extends State<_ErrorDetails> {
  bool _expanded = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.detail));
    if (!mounted) return;
    AppSnackBar.success(context, context.commonStrings.detailsCopied);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.commonStrings;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton.icon(
          onPressed: () => setState(() => _expanded = !_expanded),
          style: TextButton.styleFrom(foregroundColor: AppTheme.textMuted),
          icon: AnimatedRotation(
            turns: _expanded ? 0.5 : 0,
            duration: const Duration(milliseconds: 180),
            child: const Icon(Icons.expand_more_rounded, size: 18),
          ),
          label: Text(
            _expanded ? strings.hideDetails : strings.showDetails,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _expanded
              ? Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 4, 10),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SelectableText(
                          widget.detail,
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11.5,
                            height: 1.5,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _copy,
                        tooltip: strings.copyDetails,
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        color: AppTheme.textMuted,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// One-shot fade + rise when the error first appears.
class _Entrance extends StatelessWidget {
  const _Entrance({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 12), child: child),
      ),
    );
  }
}
