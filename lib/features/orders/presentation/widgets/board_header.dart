import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/time_ago.dart';
import '../bloc/orders_bloc.dart';
import '../bloc/orders_event.dart';
import '../bloc/orders_state.dart';
import 'platform_tabs.dart';

class BoardHeader extends StatelessWidget {
  const BoardHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const _PageTitle(),
              const Spacer(),
              const _HeaderActions(),
            ],
          ),
          const SizedBox(height: 12),
          BlocBuilder<OrdersBloc, OrdersState>(
            buildWhen: (p, c) => p.platformFilter != c.platformFilter,
            builder: (context, state) => PlatformTabs(
              selected: state.platformFilter,
              onChanged: (p) =>
                  context.read<OrdersBloc>().add(OrdersPlatformFilterChanged(p)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageTitle extends StatelessWidget {
  const _PageTitle();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OrdersBloc, OrdersState>(
      buildWhen: (p, c) => p.showHistory != c.showHistory,
      builder: (context, state) {
        return Text(
          state.showHistory ? 'Order Archive' : 'Live Kanban',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        );
      },
    );
  }
}

class _HeaderActions extends StatelessWidget {
  const _HeaderActions();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OrdersBloc, OrdersState>(
      buildWhen: (p, c) =>
          p.lastSyncedAt != c.lastSyncedAt || p.showHistory != c.showHistory,
      builder: (context, state) {
        return Row(
          children: [
            if (state.lastSyncedAt != null) ...[
              const Icon(Icons.circle, size: 7, color: Color(0xFF22C55E)),
              const SizedBox(width: 5),
              Text(
                'Updated ${timeAgo(state.lastSyncedAt!)}',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
              const SizedBox(width: 10),
            ],
            _IconBtn(
              icon: Icons.refresh_rounded,
              tooltip: 'Refresh',
              onTap: () => context.read<OrdersBloc>().add(const OrdersRequested()),
            ),
            const SizedBox(width: 6),
            _OutlineBtn(
              icon: state.showHistory ? Icons.dashboard_outlined : Icons.history_outlined,
              label: state.showHistory ? 'Live Board' : 'Archive',
              onTap: () => context.read<OrdersBloc>().add(const OrdersHistoryToggled()),
            ),
          ],
        );
      },
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.refresh_rounded, size: 16, color: AppTheme.textSecondary),
        ),
      ),
    );
  }
}

class _OutlineBtn extends StatelessWidget {
  const _OutlineBtn({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppTheme.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
