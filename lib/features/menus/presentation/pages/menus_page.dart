import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/locale_context.dart';
import '../../../../core/platforms/platforms.dart';
import '../../../../core/storage/app_preferences.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/platform_colors.dart';
import '../../../connections/data/platform_connections.dart';
import '../../../connections/presentation/widgets/connections_dialog.dart';
import '../../../hungerstation_menu/presentation/pages/hungerstation_menu_page.dart';
import '../../../keeta_menu/presentation/pages/keeta_menu_page.dart';
import '../../../products/presentation/cubit/platform_sync_cubit.dart';

/// Menus: pick a platform, then see (and edit) its menu. A platform's page is
/// built the first time it is picked and then kept, so switching back does not
/// reload it.
class MenusPage extends StatefulWidget {
  const MenusPage({super.key});

  @override
  State<MenusPage> createState() => _MenusPageState();
}

class _MenusPageState extends State<MenusPage> {
  static const _platforms = ['keeta', 'hungerstation'];

  /// Remembered while the app runs, so coming back to Menus shows the last one.
  static String _last = 'keeta';

  late String _selected = _last;
  late final Set<String> _opened = {_selected};

  void _select(String platform) {
    if (platform == _selected) return;
    setState(() {
      _selected = _last = platform;
      _opened.add(platform);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PlatformBar(
          platforms: _platforms,
          selected: _selected,
          onSelect: _select,
          onConnect: () async {
            await showConnectionsDialog(
              context,
              connections: PlatformConnections(
                context.read<PlatformApis>(),
                context.read<AppPreferences>(),
              ),
              platform: _selected,
            );
            // New credentials: re-read the platforms (the menus reload after).
            if (context.mounted) context.read<PlatformSyncCubit>().runNow();
          },
        ),
        Expanded(
          child: IndexedStack(
            index: _platforms.indexOf(_selected),
            children: [
              for (final p in _platforms)
                if (_opened.contains(p))
                  switch (p) {
                    'keeta' => const KeetaMenuPage(),
                    _ => const HungerStationMenuPage(),
                  }
                else
                  const SizedBox.shrink(),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlatformBar extends StatelessWidget {
  const _PlatformBar({
    required this.platforms,
    required this.selected,
    required this.onSelect,
    required this.onConnect,
  });

  final List<String> platforms;
  final String selected;
  final ValueChanged<String> onSelect;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceAlt,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          Text(
            context.isArabic ? 'القوائم' : 'Menus',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(width: 20),
          for (final p in platforms) ...[
            _PlatformPill(
              platform: p,
              selected: p == selected,
              onTap: () => onSelect(p),
            ),
            const SizedBox(width: 10),
          ],
          const Spacer(),
          OutlinedButton.icon(
            onPressed: onConnect,
            icon: const Icon(Icons.link_rounded, size: 18),
            label: Text(context.isArabic ? 'الربط' : 'Connection'),
          ),
        ],
      ),
    );
  }
}

class _PlatformPill extends StatelessWidget {
  const _PlatformPill({
    required this.platform,
    required this.selected,
    required this.onTap,
  });

  final String platform;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = PlatformColors.of(platform);
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? color : AppTheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? color : AppTheme.border),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: selected ? Colors.white : color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              PlatformColors.label(platform),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
