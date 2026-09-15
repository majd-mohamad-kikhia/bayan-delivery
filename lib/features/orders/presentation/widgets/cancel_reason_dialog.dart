import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Animated reason dialog for cancel / reject refund.
/// Returns the reason string, or null if dismissed.
Future<String?> showCancelReasonDialog(
  BuildContext context, {
  required String orderId,
  String title = 'Cancel Order?',
  String confirmLabel = 'Cancel Order',
}) {
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: title,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 300),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
    pageBuilder: (context, _, __) => _CancelDialog(
      orderId: orderId,
      title: title,
      confirmLabel: confirmLabel,
    ),
  );
}

class _CancelDialog extends StatefulWidget {
  const _CancelDialog({
    required this.orderId,
    required this.title,
    required this.confirmLabel,
  });

  final String orderId;
  final String title;
  final String confirmLabel;

  @override
  State<_CancelDialog> createState() => _CancelDialogState();
}

class _CancelDialogState extends State<_CancelDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _controller.text.trim();
    Navigator.of(context).pop(reason.isEmpty ? 'UNSPECIFIED' : reason);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Material(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Warning icon
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppTheme.coral.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.cancel_outlined, size: 32, color: AppTheme.coral),
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),

                // Subtitle
                Text(
                  'Order #${widget.orderId}',
                  style: const TextStyle(fontSize: 14, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Please provide a reason. This action cannot be undone.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 20),

                // Reason field
                TextField(
                  controller: _controller,
                  autofocus: true,
                  maxLines: 2,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: 'e.g. Out of stock, customer request…',
                    hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                    filled: true,
                    fillColor: AppTheme.surfaceAlt,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.coral, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: _DialogButton(
                        label: 'Keep Order',
                        onTap: () => Navigator.of(context).pop(),
                        filled: false,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DialogButton(
                        label: widget.confirmLabel,
                        onTap: _submit,
                        filled: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.label,
    required this.onTap,
    required this.filled,
  });

  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 44,
        decoration: BoxDecoration(
          color: filled ? AppTheme.coral : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: filled ? AppTheme.coral : AppTheme.border,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: filled ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
