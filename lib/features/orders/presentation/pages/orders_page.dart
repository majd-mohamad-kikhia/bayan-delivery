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
import '../utils/order_drag_rules.dart';
import '../widgets/kanban_column.dart';
import '../widgets/order_action_runner.dart';
import '../widgets/new_order_dialog.dart';
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
      listenWhen: (p, c) =>
          c.newOrderAlerts.isNotEmpty &&
          p.newOrderAlerts.length != c.newOrderAlerts.length,
      listener: (context, state) => _showNewOrderDialog(context),
      child: const _ErrorListener(),
    );
  }
}

class _ErrorListener extends StatelessWidget {
  const _ErrorListener();

  @override
  Widget build(BuildContext context) {
    return BlocListener<OrdersBloc, OrdersState>(
      listenWhen: (p, c) =>
          c.actionError != null && p.actionError != c.actionError,
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
          p.dateFilter != c.dateFilter ||
          p.isDateLoading != c.isDateLoading ||
          p.orders != c.orders,
      builder: (context, state) {
        if (state.status == OrdersStatus.initial ||
            state.status == OrdersStatus.loading ||
            state.isDateLoading) {
          return LoadingView(message: s.loadingOrders);
        }

        if (state.status == OrdersStatus.failure && state.orders.isEmpty) {
          return ErrorView(
            error: state.error ?? const AppError(AppErrorKind.unknown),
            onRetry: () =>
                context.read<OrdersBloc>().add(const OrdersRequested()),
          );
        }

        return state.showHistory
            ? _HistoryGrid(orders: state.visibleOrders)
            : _ActiveBoard(board: state.board, orders: state.visibleOrders);
      },
    );
  }
}

// ── Active kanban board ────────────────────────────────────────────────────────

class _ActiveBoard extends StatefulWidget {
  const _ActiveBoard({required this.board, required this.orders});

  final PlatformBoardConfig board;
  final List<OrderModel> orders;

  @override
  State<_ActiveBoard> createState() => _ActiveBoardState();
}

class _ActiveBoardState extends State<_ActiveBoard> {
  static const double _minColumnWidth = 270;
  static const double _maxColumnWidth = 340;
  static const double _gutter = 12;
  static const double _padding = 16;

  /// The card being dragged; every column reads it to show if it takes the drop.
  final ValueNotifier<OrderModel?> _dragging = ValueNotifier(null);

  @override
  void dispose() {
    _dragging.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_ActiveBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A poll can move or remove the card being dragged; its Draggable is then
    // gone and never reports the end, which would leave every column lit.
    final dragged = _dragging.value;
    if (dragged != null &&
        !widget.orders.any(
          (o) =>
              o.platform == dragged.platform &&
              o.platformOrderId == dragged.platformOrderId &&
              o.status == dragged.status,
        )) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _dragging.value = null;
      });
    }
  }

  PlatformBoardConfig get board => widget.board;
  List<OrderModel> get orders => widget.orders;

  @override
  Widget build(BuildContext context) {
    final s = context.ordersStrings;
    final columns = board.activeColumns;

    // One pass over the orders instead of one filter per column.
    final buckets = List.generate(columns.length, (_) => <OrderModel>[]);
    for (final order in orders) {
      for (var i = 0; i < columns.length; i++) {
        if (columns[i].holds(order.status)) {
          buckets[i].add(order);
          break;
        }
      }
    }

    final bloc = context.read<OrdersBloc>();
    void onAction(
      OrderModel order,
      String action, {
      String? reason,
      Map<String, Object?>? payload,
    }) => bloc.add(
      OrderActionRequested(
        platform: order.platform,
        platformOrderId: order.platformOrderId,
        action: action,
        reason: reason,
        payload: payload,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Fill the screen when it's wide enough, scroll sideways when not.
        final fit =
            (constraints.maxWidth - _padding * 2) / columns.length - _gutter;
        final width = fit.clamp(_minColumnWidth, _maxColumnWidth);
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(_padding),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < columns.length; i++)
                KanbanColumn(
                  key: ValueKey(columns[i].status),
                  width: width,
                  title: columns[i].titleKey != null
                      ? s.columnTitle(columns[i].titleKey!)
                      : s.statusLabel(
                          columns[i].status,
                          platform: board.platformId,
                        ),
                  status: columns[i].status,
                  accentColor: columns[i].color,
                  orders: buckets[i],
                  neutralLabels: board.platformId == 'all',
                  // The first column of every board is the new, unaccepted orders.
                  alerting: i == 0 && buckets[0].isNotEmpty,
                  onAction: onAction,
                  dragging: _dragging,
                  dropActionFor: (order) =>
                      dragActionFor(order, columns[i], board),
                  // A dropped card does what its button would: ask for a reason
                  // when cancelling, then send the action.
                  onDrop: (order, action) {
                    _dragging.value = null;
                    runOrderAction(
                      context,
                      order: order,
                      action: action,
                      onAction: (a, {reason, payload}) =>
                          onAction(order, a, reason: reason, payload: payload),
                    );
                  },
                ),
            ],
          ),
        );
      },
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
          onAction: (_, {reason, payload}) {},
        );
      },
    );
  }
}

bool _newOrderDialogOpen = false;

Future<void> _showNewOrderDialog(BuildContext context) async {
  if (_newOrderDialogOpen) return; // open dialog re-renders from state
  _newOrderDialogOpen = true;
  final bloc = context.read<OrdersBloc>();
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'new-order',
    barrierColor: Colors.black87,
    transitionDuration: const Duration(milliseconds: 400),
    pageBuilder: (_, _, _) =>
        BlocProvider.value(value: bloc, child: const NewOrderDialog()),
    transitionBuilder: (_, anim, _, child) => ScaleTransition(
      scale: CurvedAnimation(parent: anim, curve: Curves.elasticOut),
      child: FadeTransition(opacity: anim, child: child),
    ),
  );
  _newOrderDialogOpen = false;
  bloc.add(const NewOrderAlertDismissed());
}
