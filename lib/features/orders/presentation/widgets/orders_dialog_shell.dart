import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

const _gradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF3D5AFE), Color(0xFF7C4DFF)],
);

final dialogButtonStyle = FilledButton.styleFrom(
  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
);

/// The shared animated entrance (scale + slide + fade) of the order dialogs.
Future<T?> showOrdersDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'orders-dialog',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 340),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
      );
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.05),
            end: Offset.zero,
          ).animate(curved),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
            child: child,
          ),
        ),
      );
    },
    pageBuilder: (context, _, _) => builder(context),
  );
}

/// Rounded dialog with a gradient header (icon, title, subtitle), a scrolling
/// body and a row of actions.
class OrdersDialogShell extends StatelessWidget {
  const OrdersDialogShell({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    required this.actions,
    this.maxWidth = 560,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;
  final List<Widget> actions;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: Material(
          color: AppTheme.surface,
          elevation: 24,
          shadowColor: const Color(0x663D5AFE),
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
                decoration: const BoxDecoration(gradient: _gradient),
                child: Row(
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 650),
                      curve: Curves.elasticOut,
                      builder: (_, t, child) =>
                          Transform.scale(scale: t, child: child),
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(icon, color: Colors.white, size: 26),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                  child: child,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actions,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
