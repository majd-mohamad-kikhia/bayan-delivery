import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/app_error.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/error_view.dart';
import '../bloc/bayan_erp_bloc.dart';
import '../bloc/bayan_erp_event.dart';
import '../bloc/bayan_erp_state.dart';

/// Wraps a tab's content with uniform loading / error / empty-state handling.
///
/// When [status] is [BayanErpStatus.loading] a centred progress indicator is
/// shown.  On [BayanErpStatus.failure] an error view with a retry action is
/// rendered.  When the data list is empty after a successful fetch,
/// [emptyLabel] is shown.  Otherwise [child] is displayed.
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
  final AppError? error;
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
      BayanErpStatus.failure => ErrorView(
          error: error ?? const AppError(AppErrorKind.unknown),
          onRetry: () =>
              context.read<BayanErpBloc>().add(const BayanErpRefreshRequested()),
        ),
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
