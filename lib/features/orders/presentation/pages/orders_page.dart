import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/app_error.dart';
import '../../../../core/localization/locale_context.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/error_banner.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../data/models/order_model.dart';
import '../bloc/orders_bloc.dart';
import '../bloc/orders_event.dart';
import '../bloc/orders_state.dart';
import '../config/platform_board_config.dart';
import '../l10n/orders_strings.dart';
import '../widgets/board_header.dart';
import '../widgets/kanban_column.dart';
import '../widgets/order_card.dart';

class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _MainContent();
  }
}

// ── Main content (right of sidebar) ───────────────────────────────────────────

class _MainContent extends StatelessWidget {
  const _MainContent();

  @override
  Widget build(BuildContext context) {
    return BlocListener<OrdersBloc, OrdersState>(
      listenWhen: (p, c) => c.actionError != null && p.actionError != c.actionError,
      listener: (context, state) {
        AppSnackBar.fromError(
          context,
          state.actionError!,
          title: context.ordersStrings.actionFailed,
        );
        context.read<OrdersBloc>().add(const OrderActionErrorCleared());
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BoardHeader(),
          const _StaleBannerSlot(),
          const Expanded(child: _BoardBody()),
        ],
      ),
    );
  }
}

// ── Stale data banner ──────────────────────────────────────────────────────────

class _StaleBannerSlot extends StatelessWidget {
  const _StaleBannerSlot();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OrdersBloc, OrdersState>(
      buildWhen: (p, c) => p.error != c.error || p.status != c.status,
      builder: (context, state) {
        final error = state.error;
        final show = error != null && state.status != OrdersStatus.failure;
        return AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: show
              ? ErrorBanner(
                  error: error,
                  title: context.commonStrings.showingCachedData,
                  onRetry: () =>
                      context.read<OrdersBloc>().add(const OrdersRequested()),
                )
              : const SizedBox(width: double.infinity),
        );
      },
    );
  }
}

// ── Body (board / history / loading / error) ───────────────────────────────────

class _BoardBody extends StatelessWidget {
  const _BoardBody();

  @override
  Widget build(BuildContext context) {
    final s = context.ordersStrings;
    return BlocBuilder<OrdersBloc, OrdersState>(
      buildWhen: (p, c) =>
          p.status != c.status ||
          p.showHistory != c.showHistory ||
          p.orders != c.orders,
      builder: (context, state) {
        if (state.status == OrdersStatus.initial ||
            state.status == OrdersStatus.loading) {
          return LoadingView(message: s.loadingOrders);
        }

        if (state.status == OrdersStatus.failure && state.orders.isEmpty) {
          return ErrorView(
            error: state.error ?? const AppError(AppErrorKind.unknown),
            onRetry: () => context.read<OrdersBloc>().add(const OrdersRequested()),
          );
        }

        return state.showHistory
            ? _HistoryGrid(orders: state.visibleOrders)
            : _ActiveBoard(
                board: state.board,
                orders: state.visibleOrders,
                isActionPending: state.isActionPending,
              );
      },
    );
  }
}

// ── Active kanban board ────────────────────────────────────────────────────────

class _ActiveBoard extends StatelessWidget {
  const _ActiveBoard({
    required this.board,
    required this.orders,
    required this.isActionPending,
  });

  final PlatformBoardConfig board;
  final List<OrderModel> orders;
  final bool Function(String platform, String platformOrderId) isActionPending;

  @override
  Widget build(BuildContext context) {
    final s = context.ordersStrings;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final column in board.activeColumns)
            KanbanColumn(
              title: s.statusLabel(column.status, platform: board.platformId),
              accentColor: column.color,
              orders: orders.where((o) => o.status == column.status).toList(),
              isActionPending: (order) =>
                  isActionPending(order.platform, order.platformOrderId),
              onAction: (order, action, {reason}) =>
                  context.read<OrdersBloc>().add(
                        OrderActionRequested(
                          platform: order.platform,
                          platformOrderId: order.platformOrderId,
                          action: action,
                          reason: reason,
                        ),
                      ),
            ),
        ],
      ),
    );
  }
}

// ── History grid ───────────────────────────────────────────────────────────────

class _HistoryGrid extends StatelessWidget {
  const _HistoryGrid({required this.orders});

  final List<OrderModel> orders;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
        child: Text(
          context.ordersStrings.noArchivedOrders,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 300,
        mainAxisExtent: 190,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return OrderCard(
          key: ValueKey('${order.platform}:${order.platformOrderId}'),
          order: order,
          isActionPending: false,
          onAction: (_, {reason}) {},
        );
      },
    );
  }
}
