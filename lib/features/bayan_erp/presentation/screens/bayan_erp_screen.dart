import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/erp_product_model.dart';
import '../bloc/bayan_erp_bloc.dart';
import '../bloc/bayan_erp_event.dart';
import '../bloc/bayan_erp_state.dart';
import '../widgets/agents_tab_widget.dart';
import '../widgets/customers_tab_widget.dart';
import '../widgets/erp_products_tab_widget.dart';
import '../widgets/salesman_tab_widget.dart';
import '../widgets/stores_tab_widget.dart';

/// Main screen for the Bayan Accounting & Warehouses integration.
///
/// Renders a five-tab layout (Customers, Products, Salesmen, Agents, Stores)
/// with a date-filter toolbar and per-tab pagination controls.
class BayanErpScreen extends StatelessWidget {
  const BayanErpScreen({super.key, this.onAddToPlatforms});

  /// Called when the user asks to publish an ERP product to delivery
  /// platforms. The action is hidden when null.
  final ValueChanged<ErpProductModel>? onAddToPlatforms;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _ErpHeader(),
        const _ErpTabBar(),
        Expanded(child: _ErpBody(onAddToPlatforms: onAddToPlatforms)),
        const _ErpPaginationBar(),
      ],
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _ErpHeader extends StatelessWidget {
  const _ErpHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          // ── Title
          const Icon(Icons.account_balance_outlined, size: 20, color: AppTheme.primary),
          const SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bayan ERP',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                'Accounting & Warehouses',
                style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
            ],
          ),
          const Spacer(),
          // ── Date filter
          const _DateFilterButton(),
          const SizedBox(width: 8),
          // ── Refresh
          const _RefreshButton(),
        ],
      ),
    );
  }
}

// ─── Date filter button ───────────────────────────────────────────────────────

class _DateFilterButton extends StatelessWidget {
  const _DateFilterButton();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BayanErpBloc, BayanErpState>(
      buildWhen: (p, c) => p.sinceDate != c.sinceDate,
      builder: (context, state) {
        final hasFilter = state.sinceDate != null;
        final label = hasFilter
            ? 'Since ${_fmtDate(state.sinceDate!)}'
            : 'All dates';

        return OutlinedButton.icon(
          onPressed: () => _pickDate(context, current: state.sinceDate),
          icon: Icon(
            hasFilter ? Icons.calendar_today : Icons.calendar_month_outlined,
            size: 14,
            color: hasFilter ? AppTheme.primary : AppTheme.textSecondary,
          ),
          label: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: hasFilter ? AppTheme.primary : AppTheme.textSecondary,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(
              color: hasFilter ? AppTheme.primary : AppTheme.border,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      },
    );
  }

  Future<void> _pickDate(BuildContext context, {DateTime? current}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(2010),
      lastDate: now,
      helpText: 'Filter records modified since',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (context.mounted) {
      if (picked != null) {
        context.read<BayanErpBloc>().add(BayanErpDateChanged(picked));
      }
    }
  }

  static String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

// ─── Refresh button ───────────────────────────────────────────────────────────

class _RefreshButton extends StatelessWidget {
  const _RefreshButton();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<BayanErpBloc, BayanErpState, BayanErpStatus>(
      selector: (s) => s.activeStatus,
      builder: (context, status) {
        final isLoading = status == BayanErpStatus.loading;
        return IconButton(
          tooltip: 'Refresh',
          onPressed: isLoading
              ? null
              : () => context.read<BayanErpBloc>().add(const BayanErpRefreshRequested()),
          icon: AnimatedRotation(
            turns: isLoading ? 1 : 0,
            duration: const Duration(milliseconds: 600),
            child: const Icon(Icons.refresh_outlined, size: 20),
          ),
          style: IconButton.styleFrom(
            foregroundColor: AppTheme.textSecondary,
            disabledForegroundColor: AppTheme.textMuted,
          ),
        );
      },
    );
  }
}

// ─── Tab bar ──────────────────────────────────────────────────────────────────

class _ErpTabBar extends StatelessWidget {
  const _ErpTabBar();

  static const _tabs = [
    (BayanErpTab.products, Icons.inventory_2_outlined, 'Products'),
    (BayanErpTab.customers, Icons.people_outline, 'Customers'),
    (BayanErpTab.salesmen, Icons.badge_outlined, 'Salesmen'),
    (BayanErpTab.agents, Icons.person_pin_outlined, 'Agents'),
    (BayanErpTab.stores, Icons.warehouse_outlined, 'Warehouses'),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocSelector<BayanErpBloc, BayanErpState, BayanErpTab>(
      selector: (s) => s.activeTab,
      builder: (context, activeTab) => Container(
        height: 48,
        color: AppTheme.surface,
        child: Row(
          children: [
            for (final (tab, icon, label) in _tabs)
              _TabItem(
                tab: tab,
                icon: icon,
                label: label,
                isActive: activeTab == tab,
                onTap: () => context.read<BayanErpBloc>().add(BayanErpTabSelected(tab)),
              ),
          ],
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.tab,
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final BayanErpTab tab;
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? AppTheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isActive ? AppTheme.primary : AppTheme.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? AppTheme.primary : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Body (tab content) ───────────────────────────────────────────────────────

class _ErpBody extends StatelessWidget {
  const _ErpBody({required this.onAddToPlatforms});

  final ValueChanged<ErpProductModel>? onAddToPlatforms;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<BayanErpBloc, BayanErpState, BayanErpTab>(
      selector: (s) => s.activeTab,
      builder: (context, activeTab) => switch (activeTab) {
        BayanErpTab.customers => const CustomersTabWidget(),
        BayanErpTab.products => ErpProductsTabWidget(onAddToPlatforms: onAddToPlatforms),
        BayanErpTab.salesmen => const SalesmanTabWidget(),
        BayanErpTab.agents => const AgentsTabWidget(),
        BayanErpTab.stores => const StoresTabWidget(),
      },
    );
  }
}

// ─── Pagination bar ───────────────────────────────────────────────────────────

class _ErpPaginationBar extends StatelessWidget {
  const _ErpPaginationBar();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BayanErpBloc, BayanErpState>(
      buildWhen: (p, c) =>
          p.activeTab != c.activeTab ||
          p.activePage != c.activePage ||
          p.canGoPrev != c.canGoPrev ||
          p.canGoNext != c.canGoNext ||
          p.activeStatus != c.activeStatus ||
          p.hasPagination != c.hasPagination,
      builder: (context, state) {
        // Products renders its own footer inside the list card.
        if (!state.hasPagination || state.activeTab == BayanErpTab.products) {
          return const SizedBox.shrink();
        }

        final isLoading = state.activeStatus == BayanErpStatus.loading;
        final page = state.activePage;

        return Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            border: Border(top: BorderSide(color: AppTheme.border)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Page ${page + 1}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 16),
              // Prev
              _PageButton(
                icon: Icons.chevron_left,
                tooltip: 'Previous page',
                onPressed: state.canGoPrev && !isLoading
                    ? () => context.read<BayanErpBloc>().add(const BayanErpPrevPageRequested())
                    : null,
              ),
              const SizedBox(width: 4),
              // Next
              _PageButton(
                icon: Icons.chevron_right,
                tooltip: 'Next page',
                onPressed: state.canGoNext && !isLoading
                    ? () => context.read<BayanErpBloc>().add(const BayanErpNextPageRequested())
                    : null,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PageButton extends StatelessWidget {
  const _PageButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      style: IconButton.styleFrom(
        foregroundColor: AppTheme.textSecondary,
        disabledForegroundColor: AppTheme.textMuted,
        backgroundColor: AppTheme.surfaceAlt,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }
}
