import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../localization/app_language.dart';
import '../localization/locale_cubit.dart';
import '../theme/app_theme.dart';

/// Compact EN / العربية segmented toggle styled for the dark sidebar.
class LanguageSwitcher extends StatelessWidget {
  const LanguageSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final current = context.watch<LocaleCubit>().state;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppTheme.sidebarItem,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          for (final language in AppLanguage.values)
            Expanded(
              child: _Segment(
                language: language,
                selected: language == current,
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.language, required this.selected});

  final AppLanguage language;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: () => context.read<LocaleCubit>().change(language),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            language.nativeName,
            style: TextStyle(
              color: selected ? AppTheme.sidebarTextActive : AppTheme.sidebarText,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
