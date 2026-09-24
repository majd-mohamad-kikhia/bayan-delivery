import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../data/models/order_model.dart';
import '../bloc/orders_bloc.dart';
import '../bloc/orders_event.dart';
import '../bloc/orders_state.dart';
import '../config/platform_board_config.dart';
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
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(state.actionError!),
              backgroundColor: AppTheme.coral,
            ),
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
      buildWhen: (p, c) => p.errorMessage != c.errorMessage || p.status != c.status,
      builder: (context, state) {
        if (state.errorMessage == null || state.status == OrdersStatus.failure) {
          return const SizedBox.shrink();
        }
        return _StaleBanner(message: state.errorMessage!);
      },
    );
  }
}

class _StaleBanner extends StatelessWidget {
  const _StaleBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFEF3C7),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, size: 13, color: Color(0xFF92400E)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Showing last known data — $message',
              style: const TextStyle(color: Color(0xFF92400E), fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Body (board / history / loading / error) ───────────────────────────────────

class _BoardBody extends StatelessWidget {
  const _BoardBody();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OrdersBloc, OrdersState>(
      buildWhen: (p, c) =>
          p.status != c.status ||
          p.showHistory != c.showHistory ||
          p.orders != c.orders,
      builder: (context, state) {
        if (state.status == OrdersStatus.initial ||
            state.status == OrdersStatus.loading) {
          return const LoadingView(message: 'Loading orders…');
        }

        if (state.status == OrdersStatus.failure && state.orders.isEmpty) {
          return ErrorView(
            message: state.errorMessage ?? 'Failed to load orders.',
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final column in board.activeColumns)
            KanbanColumn(
              title: column.title,
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
          'No archived orders yet',
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
