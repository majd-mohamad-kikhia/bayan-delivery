import 'package:flutter/material.dart';

import '../../../../core/localization/locale_context.dart';
import '../../../../core/theme/app_theme.dart';

const Color hsOrange = Color(0xFFEA580C);

/// Opens a centered HungerStation-styled dialog with a fade + scale entrance.
Future<T?> showHsDialog<T>(
  BuildContext context, {
  required String barrierLabel,
  required WidgetBuilder builder,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: barrierLabel,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 220),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.95, end: 1).animate(curved),
          child: child,
        ),
      );
    },
    pageBuilder: (context, _, _) => builder(context),
  );
}

/// Rounded card that caps the dialog to [maxWidth] and 90% of the screen height.
class HsDialogFrameWidget extends StatelessWidget {
  const HsDialogFrameWidget({super.key, required this.maxWidth, required this.child});

  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: height * 0.9),
          child: Material(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: child,
          ),
        ),
      ),
    );
  }
}

class HsDialogHeaderWidget extends StatelessWidget {
  const HsDialogHeaderWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  /// Optional pill shown next to the title (e.g. the chosen reason).
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 18, 10, 16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: hsOrange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: hsOrange, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (badge != null) _Badge(label: badge!),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: hsOrange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: hsOrange.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: hsOrange),
      ),
    );
  }
}

/// Cancel + primary action. The action is disabled while [onConfirm] is null.
class HsDialogFooterWidget extends StatelessWidget {
  const HsDialogFooterWidget({
    super.key,
    required this.confirmLabel,
    required this.onConfirm,
    this.confirmIcon = Icons.storefront_outlined,
  });

  final String confirmLabel;
  final VoidCallback? onConfirm;
  final IconData confirmIcon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      child: OverflowBar(
        alignment: MainAxisAlignment.end,
        overflowAlignment: OverflowBarAlignment.end,
        spacing: 8,
        overflowSpacing: 8,
        overflowDirection: VerticalDirection.up,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.textSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            ),
            child: Text(context.commonStrings.cancel),
          ),
          FilledButton.icon(
            onPressed: onConfirm,
            style: FilledButton.styleFrom(
              backgroundColor: hsOrange,
              disabledBackgroundColor: AppTheme.border,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: Icon(confirmIcon, size: 18),
            label: Text(confirmLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
