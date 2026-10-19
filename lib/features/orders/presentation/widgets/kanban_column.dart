import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/locale_context.dart';
import '../../data/models/order_model.dart';
import '../bloc/orders_bloc.dart';
import '../bloc/orders_state.dart';
import '../l10n/orders_strings.dart';
import '../utils/order_status_style.dart';
import 'order_card.dart';

class KanbanColumn extends StatelessWidget {
  const KanbanColumn({
    super.key,
    required this.title,
    required this.status,
    required this.accentColor,
    required this.orders,
    required this.onAction,
    this.width = 300,
    this.neutralLabels = false,
    this.alerting = false,
    this.dragging,
    this.dropActionFor,
    this.onDrop,
  });

  final String title;

  /// Column's first status — picks the empty-state icon.
  final String status;
  final Color accentColor;
  final List<OrderModel> orders;
  final double width;
  final bool neutralLabels;

  /// Orders are waiting here: the column flashes until it is empty.
  final bool alerting;

  /// The card being dragged right now (null when none): every column reads it
  /// to show whether the card may be dropped here.
  final ValueNotifier<OrderModel?>? dragging;

  /// The action that would move [order] into this column, or null when it may
  /// not go here. Null function = this column takes no drops.
  final String? Function(OrderModel order)? dropActionFor;

  /// Called when a valid card is dropped here.
  final void Function(OrderModel order, String action)? onDrop;
  final void Function(
    OrderModel order,
    String action, {
    String? reason,
    Map<String, Object?>? payload,
  })
  onAction;

  @override
  Widget build(BuildContext context) {
    final notifier = dragging;
    final resolve = dropActionFor;
    final column = _buildColumn(context);
    if (notifier == null || resolve == null || onDrop == null) return column;

    return ValueListenableBuilder<OrderModel?>(
      valueListenable: notifier,
      builder: (context, dragged, _) {
        final action = dragged == null ? null : resolve(dragged);
        return DragTarget<OrderModel>(
          onWillAcceptWithDetails: (details) => resolve(details.data) != null,
          onAcceptWithDetails: (details) {
            final drop = resolve(details.data);
            if (drop != null) onDrop!(details.data, drop);
          },
          builder: (context, hovering, _) => _DropFeedback(
            // none: nothing is being dragged; valid / invalid for the dragged card.
            mode: dragged == null
                ? _DropMode.none
                : action == null
                ? _DropMode.refuse
                : hovering.isNotEmpty
                ? _DropMode.hover
                : _DropMode.allow,
            color: accentColor,
            width: width,
            label: action == null
                ? null
                : _dropLabel(
                    context,
                    context.ordersStrings.actionLabel(
                      action,
                      platform: neutralLabels ? 'all' : dragged!.platform,
                    ),
                  ),
            child: column,
          ),
        );
      },
    );
  }

  static String _dropLabel(BuildContext context, String action) =>
      context.isArabic ? 'أفلت هنا: $action' : 'Drop to: $action';

  Widget _buildColumn(BuildContext context) {
    return _FlashingFrame(
      active: alerting,
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ColumnHeader(
            title: title,
            accentColor: accentColor,
            count: orders.length,
          ),
          Expanded(
            child: orders.isEmpty
                ? _EmptyColumn(
                    icon: OrderStatusStyle.columnIcon(status),
                    color: accentColor,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(10),
                    itemCount: orders.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      // Only this card rebuilds while its own action is in flight.
                      return BlocSelector<OrdersBloc, OrdersState, bool>(
                        key: ValueKey(
                          '${order.platform}:${order.platformOrderId}',
                        ),
                        selector: (state) => state.isActionPending(
                          order.platform,
                          order.platformOrderId,
                        ),
                        builder: (context, pending) {
                          final card = OrderCard(
                            order: order,
                            isActionPending: pending,
                            neutralLabels: neutralLabels,
                            onAction: (action, {reason, payload}) => onAction(
                              order,
                              action,
                              reason: reason,
                              payload: payload,
                            ),
                          );
                          // No drag where nothing can be dropped, or while an
                          // action on this very order is still running.
                          final notifier = dragging;
                          if (notifier == null ||
                              dropActionFor == null ||
                              pending) {
                            return card;
                          }
                          return Draggable<OrderModel>(
                            data: order,
                            onDragStarted: () => notifier.value = order,
                            onDragEnd: (_) => notifier.value = null,
                            childWhenDragging: Opacity(
                              opacity: 0.35,
                              child: card,
                            ),
                            feedback: Material(
                              color: Colors.transparent,
                              child: Transform.rotate(
                                angle: 0.035,
                                child: SizedBox(
                                  width: width - 20,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x40000000),
                                          blurRadius: 18,
                                          offset: Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: IgnorePointer(
                                      child: OrderCard(
                                        order: order,
                                        isActionPending: false,
                                        neutralLabels: neutralLabels,
                                        onAction: (_, {reason, payload}) {},
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            child: card,
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader({
    required this.title,
    required this.accentColor,
    required this.count,
  });

  final String title;
  final Color accentColor;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: accentColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyColumn extends StatelessWidget {
  const _EmptyColumn({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Soft halo in the column's own colour, so each empty column still
          // says what it is for.
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.06),
            ),
            alignment: Alignment.center,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.12),
              ),
              child: Icon(icon, size: 28, color: color.withValues(alpha: 0.75)),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            context.ordersStrings.noOrders,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// The column's frame. While [active] it pulses red, with a glow, so a waiting
/// order is seen from across the room; otherwise it is the plain frame.
class _FlashingFrame extends StatefulWidget {
  const _FlashingFrame({
    required this.active,
    required this.width,
    required this.child,
  });

  final bool active;
  final double width;
  final Widget child;

  @override
  State<_FlashingFrame> createState() => _FlashingFrameState();
}

class _FlashingFrameState extends State<_FlashingFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_FlashingFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  /// Runs only while there is something to flash for (no idle animation).
  void _sync() {
    if (widget.active) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      child: widget.child,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_pulse.value);
        return Container(
          width: widget.width,
          margin: const EdgeInsetsDirectional.only(end: 12),
          decoration: BoxDecoration(
            color: Color.lerp(
              const Color(0xFFF8FAFC),
              const Color(0xFFFFEBEB),
              t,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Color.lerp(
                const Color(0xFFE2E8F0),
                const Color(0xFFFF3B3B),
                widget.active ? 0.35 + 0.65 * t : 0,
              )!,
              width: widget.active ? 2.5 : 1,
            ),
            boxShadow: widget.active
                ? [
                    BoxShadow(
                      color: const Color(
                        0xFFFF3B3B,
                      ).withValues(alpha: 0.15 + 0.35 * t),
                      blurRadius: 10 + 18 * t,
                      spreadRadius: 1 + 3 * t,
                    ),
                  ]
                : const [],
          ),
          child: child,
        );
      },
    );
  }
}

enum _DropMode { none, allow, hover, refuse }

/// Tells, while a card is being dragged, whether this column takes it: a
/// coloured frame and a "Drop to: …" tag when it does (stronger under the
/// card), the column fades back when it does not.
class _DropFeedback extends StatelessWidget {
  const _DropFeedback({
    required this.mode,
    required this.color,
    required this.width,
    required this.label,
    required this.child,
  });

  final _DropMode mode;
  final Color color;
  final double width;
  final String? label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final taking = mode == _DropMode.allow || mode == _DropMode.hover;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: mode == _DropMode.refuse ? 0.4 : 1,
      child: Stack(
        children: [
          child,
          // The frame's own 12px side margin stays outside the highlight.
          PositionedDirectional(
            start: 0,
            end: 12,
            top: 0,
            bottom: 0,
            child: IgnorePointer(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: taking
                      ? color.withValues(
                          alpha: mode == _DropMode.hover ? 0.16 : 0.05,
                        )
                      : Colors.transparent,
                  border: Border.all(
                    color: taking ? color : Colors.transparent,
                    width: mode == _DropMode.hover ? 3 : 2,
                  ),
                ),
                alignment: Alignment.bottomCenter,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: taking && label != null ? 1 : 0,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.4),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Text(
                      label ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
