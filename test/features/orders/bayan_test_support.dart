import 'package:bayan_desktop/features/bayan_orders/data/bayan_order_sender.dart';
import 'package:bayan_desktop/features/bayan_orders/presentation/bayan_orders_cubit.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class _NeverSends implements BayanOrderSender {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName} is not used here');
}

/// The board shows a "send to Bayan" button, which reads this cubit.
/// [child] runs under one that never sends anything.
Widget withBayanOrders(Widget child) => BlocProvider(
  create: (_) => BayanOrdersCubit(_NeverSends()),
  child: child,
);
