import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/app_language.dart';
import '../../../../core/localization/locale_context.dart';
import '../../../../core/localization/locale_cubit.dart';
import '../../../../core/navigation/app_section.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/language_switcher.dart';
import '../bloc/orders_bloc.dart';
import '../bloc/orders_event.dart';
import '../bloc/orders_state.dart';
import '../l10n/orders_strings.dart';
import 'dongle_settings_dialog.dart';

class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.section,
    required this.onSectionChanged,
    required this.collapsed,
    required this.onToggleCollapsed,
    this.onMerchantsTap,
  });

  final AppSection section;
  final ValueChanged<AppSection> onSectionChanged;
  final VoidCallback? onMerchantsTap;

  /// Icon-only rail instead of the full menu.
  final bool collapsed;
  final VoidCallback onToggleCollapsed;

  static const double _fullWidth = 220;
  static const double _railWidth = 68;

  @override
  Widget build(BuildContext context) {
    // Animates the width; the layout switches to the rail as soon as the
    // labels would no longer fit, so nothing overflows mid-animation.
    return TweenAnimationBuilder<double>(
      tween: Tween(end: collapsed ? _railWidth : _fullWidth),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      builder: (context, width, _) {
        final rail = width < 150;
        return Container(
          width: width,
          color: AppTheme.sidebarBg,
          child: ClipRect(child: _content(context, rail: rail)),
        );
      },
    );
  }

  Widget _content(BuildContext context, {required bool rail}) {
    final ordersActive = section == AppSection.orders;
    final s = context.ordersStrings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SidebarBrand(rail: rail),
        const SizedBox(height: 8),
        const Divider(color: AppTheme.sidebarItem, height: 1),
        const SizedBox(height: 8),
        BlocBuilder<OrdersBloc, OrdersState>(
          buildWhen: (p, c) =>
              p.showHistory != c.showHistory ||
              p.platformFilter != c.platformFilter,
          builder: (context, state) => Column(
            children: [
              _NavItem(
                rail: rail,
                icon: Icons.dashboard_outlined,
                label: s.liveKanban,
                isActive: ordersActive && !state.showHistory,
                onTap: () {
                  onSectionChanged(AppSection.orders);
                  if (state.showHistory) {
                    context.read<OrdersBloc>().add(
                      const OrdersHistoryToggled(),
                    );
                  }
                },
              ),
              _NavItem(
                rail: rail,
                icon: Icons.history_outlined,
                label: s.orderArchive,
                isActive: ordersActive && state.showHistory,
                onTap: () {
                  onSectionChanged(AppSection.orders);
                  if (!state.showHistory) {
                    context.read<OrdersBloc>().add(
                      const OrdersHistoryToggled(),
                    );
                  }
                },
              ),
              _NavItem(
                rail: rail,
                icon: Icons.inventory_2_outlined,
                label: s.products,
                isActive: section == AppSection.products,
                onTap: () => onSectionChanged(AppSection.products),
              ),
              _NavItem(
                rail: rail,
                icon: Icons.account_balance_outlined,
                label: s.bayanErp,
                isActive: section == AppSection.inventory,
                onTap: () => onSectionChanged(AppSection.inventory),
              ),
              _NavItem(
                rail: rail,
                icon: Icons.restaurant_menu_rounded,
                label: s.menus,
                isActive: section == AppSection.menus,
                onTap: () => onSectionChanged(AppSection.menus),
              ),
              _NavItem(
                rail: rail,
                icon: Icons.insights_rounded,
                label: s.reports,
                isActive: section == AppSection.reports,
                onTap: () => onSectionChanged(AppSection.reports),
              ),
              if (onMerchantsTap != null &&
                  ordersActive &&
                  (state.platformFilter == 'keeta' ||
                      state.platformFilter == 'hungerstation'))
                _NavItem(
                  rail: rail,
                  icon: Icons.storefront_outlined,
                  label: state.platformFilter == 'hungerstation'
                      ? s.hsOutlet
                      : s.keetaShops,
                  isActive: false,
                  onTap: onMerchantsTap!,
                ),
            ],
          ),
        ),
        const Spacer(),
        const Divider(color: AppTheme.sidebarItem, height: 1),
        const SizedBox(height: 12),
        if (rail) const _RailLanguageButton() else const LanguageSwitcher(),
        BlocBuilder<OrdersBloc, OrdersState>(
          buildWhen: (p, c) => p.dongleNumber != c.dongleNumber,
          builder: (context, state) =>
              _DongleButton(dongleNumber: state.dongleNumber, rail: rail),
        ),
        _CollapseToggle(
          rail: rail,
          label: collapsed ? s.sidebarExpand : s.sidebarCollapse,
          onTap: onToggleCollapsed,
        ),
      ],
    );
  }
}

class _SidebarBrand extends StatelessWidget {
  const _SidebarBrand({required this.rail});

  final bool rail;

  @override
  Widget build(BuildContext context) {
    final common = context.commonStrings;
    if (rail) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 20, 0, 16),
        child: Center(
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.local_shipping_outlined,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.local_shipping_outlined,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  common.brandName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                Text(
                  common.brandTagline,
                  style: const TextStyle(
                    color: AppTheme.sidebarText,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.rail,
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final bool rail;
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (rail) {
      return _RailButton(
        icon: icon,
        tooltip: label,
        isActive: isActive,
        onTap: onTap,
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.sidebarItem : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 17,
              color: isActive
                  ? AppTheme.sidebarTextActive
                  : AppTheme.sidebarText,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isActive
                      ? AppTheme.sidebarTextActive
                      : AppTheme.sidebarText,
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (isActive)
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DongleButton extends StatelessWidget {
  const _DongleButton({required this.dongleNumber, required this.rail});

  final String dongleNumber;
  final bool rail;

  Future<void> _edit(BuildContext context) async {
    final value = await showDongleSettingsDialog(
      context,
      current: dongleNumber,
    );
    if (value != null && context.mounted) {
      context.read<OrdersBloc>().add(OrdersDongleChanged(value));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (rail) {
      return _RailButton(
        icon: Icons.sim_card_outlined,
        tooltip: dongleNumber,
        isActive: false,
        onTap: () => _edit(context),
      );
    }
    return GestureDetector(
      onTap: () => _edit(context),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.sidebarItem,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.sim_card_outlined,
                size: 15,
                color: AppTheme.sidebarText,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  dongleNumber,
                  style: const TextStyle(
                    color: AppTheme.sidebarText,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(
                Icons.edit_outlined,
                size: 12,
                color: Color(0xFF475569),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Icon-only nav button for the collapsed rail; the label moves to a tooltip.
class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.icon,
    required this.tooltip,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 300),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 40,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            color: isActive ? AppTheme.sidebarItem : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 19,
            color: isActive ? AppTheme.sidebarTextActive : AppTheme.sidebarText,
          ),
        ),
      ),
    );
  }
}

/// Collapsed language switch: one button showing the language you'd switch to.
class _RailLanguageButton extends StatelessWidget {
  const _RailLanguageButton();

  @override
  Widget build(BuildContext context) {
    final current = context.watch<LocaleCubit>().state;
    final next = AppLanguage.values.firstWhere((l) => l != current);
    return Tooltip(
      message: next.nativeName,
      child: GestureDetector(
        onTap: () => context.read<LocaleCubit>().change(next),
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 34,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.sidebarItem,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            next.code.toUpperCase(),
            style: const TextStyle(
              color: AppTheme.sidebarText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom-of-sidebar button that collapses / expands the menu.
class _CollapseToggle extends StatelessWidget {
  const _CollapseToggle({
    required this.rail,
    required this.label,
    required this.onTap,
  });

  final bool rail;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Collapsing points at the sidebar's own edge, expanding points away from it.
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final towardsRight = rail != rtl; // expanding points away from the edge
    final icon = Icon(
      towardsRight
          ? Icons.keyboard_double_arrow_right
          : Icons.keyboard_double_arrow_left,
      size: 18,
      color: AppTheme.sidebarText,
    );
    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 40,
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.sidebarItem),
            borderRadius: BorderRadius.circular(8),
          ),
          child: rail
              ? Center(child: icon)
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    icon,
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: const TextStyle(
                        color: AppTheme.sidebarText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
