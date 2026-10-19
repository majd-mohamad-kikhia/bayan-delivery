import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/localization/locale_context.dart';
import '../../../core/platforms/platforms.dart';
import '../../../core/storage/app_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../connections/data/platform_connections.dart';
import '../../connections/presentation/widgets/connections_dialog.dart';
import '../../orders/data/models/order_model.dart';
import 'bayan_orders_cubit.dart';

/// The strip at the bottom of an order: whether Bayan has it, and the button
/// that books it there. Rebuilds only for this order.
class BayanOrderBar extends StatelessWidget {
  const BayanOrderBar({super.key, required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final ar = context.isArabic;
    final cancelled = order.status == 'ORDER_CANCELLED';
    return BlocBuilder<BayanOrdersCubit, BayanOrdersState>(
      buildWhen: (p, c) =>
          p.recordOf(order) != c.recordOf(order) ||
          p.isBusy(order) != c.isBusy(order),
      builder: (context, state) {
        final record = state.recordOf(order);
        final busy = state.isBusy(order);
        final sent = record?.sent ?? false;
        final (IconData icon, Color color, String text) = switch ((
          sent,
          record,
        )) {
          (true, final r?) => (
            Icons.check_circle_rounded,
            const Color(0xFF16A34A),
            ar
                ? 'سُجّل في بيان · ${_time(r.attemptedAt)}'
                : 'Booked in Bayan · ${_time(r.attemptedAt)}',
          ),
          (false, final r?) => (
            Icons.error_outline_rounded,
            AppTheme.coral,
            r.error ?? (ar ? 'فشل الإرسال' : 'Sending failed'),
          ),
          _ => (
            Icons.account_balance_outlined,
            AppTheme.textMuted,
            cancelled
                ? (ar ? 'الطلب ملغى' : 'Cancelled order')
                : (ar ? 'غير مُرسل إلى بيان' : 'Not sent to Bayan'),
          ),
        };
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: const BoxDecoration(
            color: AppTheme.surfaceAlt,
            border: Border(top: BorderSide(color: AppTheme.border)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color == AppTheme.textMuted
                        ? AppTheme.textSecondary
                        : color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (!sent && (record?.error?.contains('not set') ?? false) ||
                  (record?.error?.contains('account number') ?? false)) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => showConnectionsDialog(
                    context,
                    connections: PlatformConnections(
                      context.read<PlatformApis>(),
                      context.read<AppPreferences>(),
                    ),
                    platform: 'bayan',
                  ),
                  child: Text(ar ? 'الإعدادات' : 'Settings'),
                ),
              ],
              const SizedBox(width: 12),
              if (!cancelled && !sent)
                FilledButton.icon(
                  onPressed: busy
                      ? null
                      : () => context.read<BayanOrdersCubit>().send(order),
                  icon: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.upload_rounded, size: 18),
                  label: Text(
                    record == null
                        ? (ar ? 'إرسال إلى بيان' : 'Send to Bayan')
                        : (ar ? 'إعادة المحاولة' : 'Retry'),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  static String _time(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
