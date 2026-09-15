import 'package:flutter/material.dart';

import '../../../../core/theme/platform_colors.dart';

class PlatformBadge extends StatelessWidget {
  const PlatformBadge({super.key, required this.platform});

  final String platform;

  @override
  Widget build(BuildContext context) {
    final color = PlatformColors.of(platform);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        PlatformColors.label(platform),
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}
