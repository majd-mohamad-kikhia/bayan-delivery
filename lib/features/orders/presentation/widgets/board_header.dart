import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/locale_context.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/time_ago.dart';
import '../../../bayan_erp/data/repositories/bayan_erp_repository.dart';
import '../../../bayan_orders/presentation/bayan_orders_cubit.dart';
import '../../../products/presentation/cubit/product_registry_cubit.dart';
import '../../../bayan_orders/data/bayan_orders_repository.dart';
import '../../data/debug/debug_order_seeder.dart';
import '../../data/models/order_model.dart';
import '../../data/debug/saved_menu.dart';
import '../bloc/orders_bloc.dart';
import '../bloc/orders_event.dart';
import '../bloc/orders_state.dart';
import '../l10n/orders_strings.dart';
import '../utils/orders_date_filter.dart';
import 'orders_date_filter_dialog.dart';
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
      padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 16, 0),
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
              onChanged: (p) => context.read<OrdersBloc>().add(
                OrdersPlatformFilterChanged(p),
              ),
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
    final s = context.ordersStrings;
    return BlocBuilder<OrdersBloc, OrdersState>(
      buildWhen: (p, c) => p.showHistory != c.showHistory,
      builder: (context, state) {
        return Text(
          state.showHistory ? s.orderArchive : s.liveKanban,
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
    final s = context.ordersStrings;
    final common = context.commonStrings;
    return BlocBuilder<OrdersBloc, OrdersState>(
      buildWhen: (p, c) =>
          p.lastSyncedAt != c.lastSyncedAt ||
          p.showHistory != c.showHistory ||
          p.alertMuted != c.alertMuted ||
          (p.pendingNewOrders > 0) != (c.pendingNewOrders > 0),
      builder: (context, state) {
        return Row(
          children: [
            if (state.lastSyncedAt != null) ...[
              const Icon(Icons.circle, size: 7, color: Color(0xFF22C55E)),
              const SizedBox(width: 5),
              Text(
                s.updatedAgo(timeAgo(state.lastSyncedAt!, common)),
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
              const SizedBox(width: 10),
            ],
            if (kDebugMode) ...[
              const _DebugAddOrderButton(),
              const SizedBox(width: 6),
            ],
            const _SendToBayanButton(),
            _AlertButton(
              muted: state.alertMuted,
              ringing: state.pendingNewOrders > 0,
            ),
            const SizedBox(width: 6),
            const _DateFilterButton(),
            const SizedBox(width: 6),
            _IconBtn(
              icon: Icons.refresh_rounded,
              tooltip: s.refresh,
              onTap: () =>
                  context.read<OrdersBloc>().add(const OrdersRequested()),
            ),
            const SizedBox(width: 6),
            _OutlineBtn(
              icon: state.showHistory
                  ? Icons.dashboard_outlined
                  : Icons.history_outlined,
              label: state.showHistory ? s.liveBoard : s.archive,
              onTap: () =>
                  context.read<OrdersBloc>().add(const OrdersHistoryToggled()),
            ),
          ],
        );
      },
    );
  }
}

/// "Bayan · 5": books every delivered order that Bayan does not have yet.
/// Hidden when there is nothing to send.
class _SendToBayanButton extends StatelessWidget {
  const _SendToBayanButton();

  @override
  Widget build(BuildContext context) {
    final orders = context.select<OrdersBloc, List<OrderModel>>(
      (b) => b.state.orders,
    );
    final records = context.select<BayanOrdersCubit, Map<String, BayanOrderRecord>>(
      (c) => c.state.records,
    );
    final busy = context.select<BayanOrdersCubit, bool>(
      (c) => c.state.busy.isNotEmpty,
    );
    var pending = 0;
    for (final o in orders) {
      if (BayanOrdersCubit.isSendable(o) &&
          !(records[BayanOrderRecord.keyOf(o.platform, o.platformOrderId)]
                  ?.sent ??
              false)) {
        pending++;
      }
    }
    if (pending == 0 && !busy) return const SizedBox.shrink();
    final ar = context.isArabic;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 6),
      child: Opacity(
        opacity: busy ? 0.6 : 1,
        child: _OutlineBtn(
          icon: busy ? Icons.sync_rounded : Icons.upload_rounded,
          label: busy
              ? (ar ? 'جارٍ الإرسال…' : 'Sending…')
              : (ar ? 'بيان · $pending' : 'Bayan · $pending'),
          onTap: () async {
            if (busy) return;
            final messenger = ScaffoldMessenger.maybeOf(context);
            final result = await context.read<BayanOrdersCubit>().sendAll(orders);
            messenger?.showSnackBar(
              SnackBar(
                content: Text(
                  result.failed == 0
                      ? (ar
                            ? 'سُجّل ${result.sent} طلب في بيان'
                            : '${result.sent} order(s) booked in Bayan')
                      : (ar
                            ? 'سُجّل ${result.sent}، وفشل ${result.failed} (افتح الطلب للسبب)'
                            : '${result.sent} booked, ${result.failed} failed (open the order for the reason)'),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Shows the day range on the board ("Today" by default); opens the picker.
class _DateFilterButton extends StatelessWidget {
  const _DateFilterButton();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<OrdersBloc, OrdersState, OrdersDateFilter>(
      selector: (s) => s.dateFilter,
      builder: (context, filter) {
        final custom = filter != OrdersDateFilter.today;
        return GestureDetector(
          onTap: () async {
            final bloc = context.read<OrdersBloc>();
            final picked = await showOrdersDateFilterDialog(
              context,
              current: filter,
            );
            if (picked != null) bloc.add(OrdersDateFilterChanged(picked));
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: custom ? AppTheme.primary.withValues(alpha: 0.08) : null,
              border: Border.all(
                color: custom ? AppTheme.primary : AppTheme.border,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  size: 14,
                  color: custom ? AppTheme.primary : AppTheme.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  dateFilterLabel(context, filter),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: custom ? AppTheme.primary : AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.arrow_drop_down_rounded,
                  size: 18,
                  color: custom ? AppTheme.primary : AppTheme.textSecondary,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Bell for the repeating new-order sound: red while orders are waiting and
/// the sound is on, grey with a slash when silenced. The flashing column
/// stays either way.
class _AlertButton extends StatelessWidget {
  const _AlertButton({required this.muted, required this.ringing});

  final bool muted;
  final bool ringing;

  @override
  Widget build(BuildContext context) {
    final active = ringing && !muted;
    final color = muted
        ? AppTheme.textMuted
        : (active ? const Color(0xFFFF3B3B) : AppTheme.textSecondary);
    return Tooltip(
      message: muted
          ? (context.isArabic
                ? 'تشغيل صوت الطلبات الجديدة'
                : 'Turn the new-order sound on')
          : (context.isArabic
                ? 'إيقاف صوت الطلبات الجديدة'
                : 'Silence the new-order sound'),
      child: GestureDetector(
        onTap: () =>
            context.read<OrdersBloc>().add(const OrdersAlertMuteToggled()),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: active ? color.withValues(alpha: 0.1) : null,
            border: Border.all(color: active ? color : AppTheme.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            muted
                ? Icons.notifications_off_rounded
                : Icons.notifications_active_rounded,
            size: 17,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

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
          child: const Icon(
            Icons.refresh_rounded,
            size: 16,
            color: AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _OutlineBtn extends StatelessWidget {
  const _OutlineBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

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

/// Debug builds only: adds a test order via the Keeta / HungerStation mocks.
class _DebugAddOrderButton extends StatefulWidget {
  const _DebugAddOrderButton();

  @override
  State<_DebugAddOrderButton> createState() => _DebugAddOrderButtonState();
}

class _DebugAddOrderButtonState extends State<_DebugAddOrderButton> {
  final _seeder = DebugOrderSeeder();
  bool _busy = false;

  Future<void> _add(
    Future<String> Function(Map<String, Object?> menu) seed,
    String label,
  ) async {
    final bloc = context.read<OrdersBloc>();
    final registry = context.read<ProductRegistryCubit>().state.records.values;
    final erp = context.read<BayanErpRepository>();
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() => _busy = true);
    try {
      // Orders hold the products you saved, not made-up ones.
      final menu = await savedMenuForMockOrders(
        saved: registry,
        erp: erp,
      );
      final id = await seed(menu);
      bloc.add(const OrdersPollTicked());
      messenger?.showSnackBar(
        SnackBar(content: Text('Added $label order $id')),
      );
    } catch (e) {
      messenger?.showSnackBar(
        SnackBar(content: Text('Could not add $label order: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<VoidCallback>(
      enabled: !_busy,
      tooltip: 'Add test order (debug)',
      onSelected: (run) => run(),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: () =>
              _add((menu) => _seeder.addKeetaOrder(menu: menu), 'Keeta'),
          child: const Text('Add Keeta order'),
        ),
        PopupMenuItem(
          value: () => _add(
            (menu) => _seeder.addHungerStationOrder(menu: menu),
            'HungerStation',
          ),
          child: const Text('Add HungerStation order'),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFF59E0B)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _busy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(
                    Icons.bug_report_outlined,
                    size: 16,
                    color: Color(0xFFF59E0B),
                  ),
            const SizedBox(width: 6),
            const Text(
              'Add order',
              style: TextStyle(
                color: Color(0xFFF59E0B),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
