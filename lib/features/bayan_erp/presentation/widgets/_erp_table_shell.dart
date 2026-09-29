import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../bloc/bayan_erp_state.dart';

/// Wraps a tab's content with uniform loading / error / empty-state handling.
///
/// When [status] is [BayanErpStatus.loading] a centred progress indicator is
/// shown.  On [BayanErpStatus.failure] an error card is rendered.  When the
/// data list is empty after a successful fetch, [emptyLabel] is shown.
/// Otherwise [child] is displayed.
class ErpTableShell extends StatelessWidget {
  const ErpTableShell({
    super.key,
    required this.status,
    required this.error,
    required this.isEmpty,
    required this.emptyLabel,
    required this.child,
  });

  final BayanErpStatus status;
  final String? error;
  final bool isEmpty;
  final String emptyLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      BayanErpStatus.initial => const SizedBox.shrink(),
      BayanErpStatus.loading => const Center(
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      BayanErpStatus.failure => _ErrorView(message: error ?? 'Unknown error'),
      BayanErpStatus.success when isEmpty => _EmptyView(label: emptyLabel),
      _ => child,
    };
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: AppTheme.textMuted.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 14)),
          ],
        ),
      );
}

// ─── Error state ──────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.coral.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.coral.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: AppTheme.coral.withValues(alpha: 0.8), size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      color: AppTheme.coral.withValues(alpha: 0.9),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
