import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../l10n/orders_strings.dart';
import '../utils/orders_date_filter.dart';

const _gradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF3D5AFE), Color(0xFF7C4DFF)],
);

String _fmt(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// "10/10/2026" or "04/10/2026 – 10/10/2026".
String describeDateRange(OrdersDateFilter filter, DateTime now) {
  final range = filter.range(now);
  if (range == null) return '';
  return range.start == range.end
      ? _fmt(range.start)
      : '${_fmt(range.start)} – ${_fmt(range.end)}';
}

String dateFilterLabel(BuildContext context, OrdersDateFilter filter) {
  final s = context.ordersStrings;
  return switch (filter.preset) {
    OrdersDatePreset.today => s.dateToday,
    OrdersDatePreset.yesterday => s.dateYesterday,
    OrdersDatePreset.last7Days => s.dateLast7Days,
    OrdersDatePreset.thisMonth => s.dateThisMonth,
    OrdersDatePreset.all => s.dateAll,
    OrdersDatePreset.custom => describeDateRange(filter, DateTime.now()),
  };
}

/// Lets the worker choose which days of orders to show. Resolves to the new
/// filter, or null when dismissed.
Future<OrdersDateFilter?> showOrdersDateFilterDialog(
  BuildContext context, {
  required OrdersDateFilter current,
}) {
  return showGeneralDialog<OrdersDateFilter>(
    context: context,
    barrierDismissible: true,
    barrierLabel: context.ordersStrings.dateFilterTitle,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 340),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
      );
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.05),
            end: Offset.zero,
          ).animate(curved),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
            child: child,
          ),
        ),
      );
    },
    pageBuilder: (context, _, _) => _DateFilterDialog(current: current),
  );
}

class _DateFilterDialog extends StatelessWidget {
  const _DateFilterDialog({required this.current});

  final OrdersDateFilter current;

  static const _presets = [
    (OrdersDatePreset.today, Icons.today_rounded),
    (OrdersDatePreset.yesterday, Icons.history_rounded),
    (OrdersDatePreset.last7Days, Icons.date_range_rounded),
    (OrdersDatePreset.thisMonth, Icons.calendar_view_month_rounded),
    (OrdersDatePreset.all, Icons.all_inclusive_rounded),
  ];

  Future<void> _pickCustom(BuildContext context) async {
    final now = DateTime.now();
    final existing = current.preset == OrdersDatePreset.custom
        ? current.range(now)
        : current.range(now);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: existing == null
          ? null
          : DateTimeRange(start: existing.start, end: existing.end),
      helpText: context.ordersStrings.dateCustomHelp,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(
            ctx,
          ).colorScheme.copyWith(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null && context.mounted) {
      Navigator.of(
        context,
      ).pop(OrdersDateFilter.custom(picked.start, picked.end));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.ordersStrings;
    final now = DateTime.now();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Material(
          color: AppTheme.surface,
          elevation: 24,
          shadowColor: const Color(0x663D5AFE),
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(24, 22, 16, 20),
                decoration: const BoxDecoration(gradient: _gradient),
                child: Row(
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 650),
                      curve: Curves.elasticOut,
                      builder: (_, t, child) =>
                          Transform.scale(scale: t, child: child),
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(
                          Icons.calendar_month_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.dateFilterTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${dateFilterLabel(context, current)}'
                            '${current.preset == OrdersDatePreset.custom || current.preset == OrdersDatePreset.all ? '' : '  ·  ${describeDateRange(current, now)}'}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (var i = 0; i < _presets.length; i++)
                      _Reveal(
                        index: i,
                        child: _PresetTile(
                          icon: _presets[i].$2,
                          label: dateFilterLabel(
                            context,
                            OrdersDateFilter(_presets[i].$1),
                          ),
                          detail: describeDateRange(
                            OrdersDateFilter(_presets[i].$1),
                            now,
                          ),
                          selected: current.preset == _presets[i].$1,
                          onTap: () => Navigator.of(
                            context,
                          ).pop(OrdersDateFilter(_presets[i].$1)),
                        ),
                      ),
                    _Reveal(
                      index: _presets.length,
                      child: _PresetTile(
                        icon: Icons.edit_calendar_rounded,
                        label: s.dateCustom,
                        detail: current.preset == OrdersDatePreset.custom
                            ? describeDateRange(current, now)
                            : '',
                        selected: current.preset == OrdersDatePreset.custom,
                        onTap: () => _pickCustom(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({
    required this.icon,
    required this.label,
    required this.detail,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 216,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary.withValues(alpha: 0.08)
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(
                      alpha: selected ? 0.18 : 0.08,
                    ),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, size: 20, color: AppTheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      if (detail.isNotEmpty)
                        Text(
                          detail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppTheme.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
                AnimatedScale(
                  scale: selected ? 1 : 0,
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutBack,
                  child: const Icon(
                    Icons.check_circle_rounded,
                    size: 20,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Fades and slides a tile in, later tiles slightly after earlier ones.
class _Reveal extends StatelessWidget {
  const _Reveal({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + index * 70),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 14),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
