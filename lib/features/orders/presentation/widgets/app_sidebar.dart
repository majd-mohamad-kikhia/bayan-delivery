import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../bloc/orders_bloc.dart';
import '../bloc/orders_event.dart';
import '../bloc/orders_state.dart';
import 'dongle_settings_dialog.dart';

class AppSidebar extends StatelessWidget {
  const AppSidebar({super.key, this.onMerchantsTap});

  final VoidCallback? onMerchantsTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: AppTheme.sidebarBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SidebarBrand(),
          const SizedBox(height: 8),
          const Divider(color: AppTheme.sidebarItem, height: 1),
          const SizedBox(height: 8),
          BlocBuilder<OrdersBloc, OrdersState>(
            buildWhen: (p, c) =>
                p.showHistory != c.showHistory || p.platformFilter != c.platformFilter,
            builder: (context, state) => Column(
              children: [
                _NavItem(
                  icon: Icons.dashboard_outlined,
                  label: 'Live Kanban',
                  isActive: !state.showHistory,
                  onTap: () {
                    if (state.showHistory) {
                      context.read<OrdersBloc>().add(const OrdersHistoryToggled());
                    }
                  },
                ),
                _NavItem(
                  icon: Icons.history_outlined,
                  label: 'Order Archive',
                  isActive: state.showHistory,
                  onTap: () {
                    if (!state.showHistory) {
                      context.read<OrdersBloc>().add(const OrdersHistoryToggled());
                    }
                  },
                ),
                if (onMerchantsTap != null &&
                    (state.platformFilter == 'keeta' ||
                        state.platformFilter == 'hungerstation'))
                  _NavItem(
                    icon: Icons.storefront_outlined,
                    label: state.platformFilter == 'hungerstation'
                        ? 'HS Outlet'
                        : 'Keeta Shops',
                    isActive: false,
                    onTap: onMerchantsTap!,
                  ),
              ],
            ),
          ),
          const Spacer(),
          const Divider(color: AppTheme.sidebarItem, height: 1),
          BlocBuilder<OrdersBloc, OrdersState>(
            buildWhen: (p, c) => p.dongleNumber != c.dongleNumber,
            builder: (context, state) => _DongleButton(dongleNumber: state.dongleNumber),
          ),
        ],
      ),
    );
  }
}

class _SidebarBrand extends StatelessWidget {
  const _SidebarBrand();

  @override
  Widget build(BuildContext context) {
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
            child: const Icon(Icons.local_shipping_outlined, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Al-Bayan',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                Text(
                  'Delivery Hub',
                  style: TextStyle(color: AppTheme.sidebarText, fontSize: 11),
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
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
              color: isActive ? AppTheme.sidebarTextActive : AppTheme.sidebarText,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isActive ? AppTheme.sidebarTextActive : AppTheme.sidebarText,
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
  const _DongleButton({required this.dongleNumber});

  final String dongleNumber;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final value = await showDongleSettingsDialog(context, current: dongleNumber);
        if (value != null && context.mounted) {
          context.read<OrdersBloc>().add(OrdersDongleChanged(value));
        }
      },
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
              const Icon(Icons.sim_card_outlined, size: 15, color: AppTheme.sidebarText),
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
              const Icon(Icons.edit_outlined, size: 12, color: Color(0xFF475569)),
            ],
          ),
        ),
      ),
    );
  }
}
