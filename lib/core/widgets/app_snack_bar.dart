import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../errors/app_error.dart';
import '../localization/locale_context.dart';
import '../theme/app_theme.dart';
import 'error_style.dart';

/// Floating toast-style snackbars with an icon, a title and an optional
/// second line. Use these instead of building `SnackBar`s by hand.
abstract final class AppSnackBar {
  static void fromError(BuildContext context, AppError error, {String? title}) {
    final strings = context.commonStrings;
    _show(
      context,
      icon: error.kind.icon,
      color: error.kind.color,
      title: title ?? strings.errorTitle(error.kind),
      message: errorMessageOf(error, strings),
      duration: const Duration(seconds: 6),
    );
  }

  static void error(BuildContext context, {required String title, String? message}) =>
      _show(
        context,
        icon: Icons.error_outline_rounded,
        color: AppTheme.coral,
        title: title,
        message: message,
        duration: const Duration(seconds: 6),
      );

  static void success(BuildContext context, String title, {String? message}) => _show(
        context,
        icon: Icons.check_circle_outline_rounded,
        color: AppTheme.success,
        title: title,
        message: message,
      );

  static void info(BuildContext context, String title, {String? message}) => _show(
        context,
        icon: Icons.info_outline_rounded,
        color: AppTheme.primary,
        title: title,
        message: message,
      );

  static void _show(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    String? message,
    Duration duration = const Duration(seconds: 4),
  }) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          width: math.min(460, screenWidth - 32),
          duration: duration,
          showCloseIcon: true,
          padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 6, 12),
          content: _SnackContent(icon: icon, color: color, title: title, message: message),
        ),
      );
  }
}

class _SnackContent extends StatelessWidget {
  const _SnackContent({
    required this.icon,
    required this.color,
    required this.title,
    this.message,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (message != null && message!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    message!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFCBD5E1),
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
