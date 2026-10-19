import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/orders_bloc.dart';
import '../bloc/orders_state.dart';
import '../l10n/orders_strings.dart';

/// Full-attention, pulsing alert shown until the worker acknowledges it.
class NewOrderDialog extends StatefulWidget {
  const NewOrderDialog({super.key});

  @override
  State<NewOrderDialog> createState() => _NewOrderDialogState();
}

class _NewOrderDialogState extends State<NewOrderDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.ordersStrings;
    return Center(
      child: Material(
        color: Colors.transparent,
        child: BlocBuilder<OrdersBloc, OrdersState>(
          buildWhen: (p, c) => c.newOrderAlerts.isNotEmpty,
          builder: (context, state) {
            final alerts = state.newOrderAlerts;
            final count = alerts.length;
            return AnimatedBuilder(
              animation: _pulse,
              builder: (context, child) {
                final t = Curves.easeInOut.transform(_pulse.value);
                return Container(
                  width: 560,
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: Color.lerp(
                      const Color(0xFFE65100),
                      const Color(0xFFFF6D00),
                      t,
                    ),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orangeAccent.withValues(
                          alpha: 0.4 + 0.4 * t,
                        ),
                        blurRadius: 40 + 60 * t,
                        spreadRadius: 4 + 20 * t,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Transform.scale(
                        scale: 1 + 0.25 * t,
                        child: Transform.rotate(
                          angle: (t - 0.5) * 0.3,
                          child: const Icon(
                            Icons.notifications_active,
                            size: 110,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        count > 1
                            ? strings.newOrdersCount(count)
                            : strings.newOrderTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      for (final o in alerts.take(4))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            [
                              '#${o.orderCode}',
                              if (o.customerName != null) o.customerName!,
                              if (o.orderTotal != null)
                                o.orderTotal!.toStringAsFixed(2),
                            ].join('  ·  '),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      const SizedBox(height: 28),
                      FilledButton(
                        autofocus: true,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFFE65100),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 56,
                            vertical: 22,
                          ),
                          textStyle: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(strings.newOrderDismiss),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
