import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/platform_colors.dart';

/// Pill-style platform selector — one chip per platform, no TabBar dependency.
class PlatformTabs extends StatelessWidget {
  const PlatformTabs({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final platform in PlatformColors.all)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _PlatformPill(
              platform: platform,
              isSelected: selected == platform,
              onTap: () => onChanged(platform),
            ),
          ),
      ],
    );
  }
}

class _PlatformPill extends StatelessWidget {
  const _PlatformPill({
    required this.platform,
    required this.isSelected,
    required this.onTap,
  });

  final String platform;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = PlatformColors.of(platform);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? color : AppTheme.border,
          ),
        ),
        child: Text(
          PlatformColors.label(platform),
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textSecondary,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
