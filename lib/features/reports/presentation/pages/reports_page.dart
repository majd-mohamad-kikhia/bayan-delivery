import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/locale_context.dart';
import '../../../../core/storage/app_preferences.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../orders/presentation/widgets/orders_date_filter_dialog.dart';
import '../../data/report_export.dart';
import '../../data/report_models.dart';
import '../../data/reports_repository.dart';
import '../cubit/reports_cubit.dart';
import '../widgets/report_charts.dart';

/// Sales, orders and kitchen numbers for the chosen days, from one backend call.
class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ReportsCubit(
        context.read<ReportsRepository>(),
        context.read<AppPreferences>().dongleNumber,
        context.read<AppPreferences>(),
      )..load(),
      child: const _ReportsView(),
    );
  }
}

class _ReportsView extends StatelessWidget {
  const _ReportsView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReportsCubit, ReportsState>(
      builder: (context, state) {
        return ColoredBox(
          color: AppTheme.background,
          child: Column(
            children: [
              _Header(state: state),
              SizedBox(
                height: 2,
                child: state.refreshing
                    ? const LinearProgressIndicator(minHeight: 2)
                    : null,
              ),
              Expanded(
                child: switch (state.status) {
                  ReportsStatus.loading => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  ReportsStatus.failure => _Failure(error: state.error ?? ''),
                  ReportsStatus.ready => Column(
                    children: [
                      if (state.error != null)
                        _StaleBanner(error: state.error!),
                      Expanded(
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: state.refreshing ? 0.75 : 1,
                          child: _Body(
                            overview: state.overview!,
                            platform: state.platform,
                          ),
                        ),
                      ),
                    ],
                  ),
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Header ──────────────────────────────────────────────────────────────────

String _platformLabel(BuildContext context, String platform) =>
    platform == 'all'
    ? t(context, 'All platforms', 'كل المنصات')
    : platformName(platform);

class _Header extends StatelessWidget {
  const _Header({required this.state});

  final ReportsState state;

  Future<void> _export(BuildContext context) async {
    final overview = state.overview;
    if (overview == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final saved = t(context, 'Saved to Downloads', 'تم الحفظ في التنزيلات');
    final reveal = t(context, 'Show', 'إظهار');
    try {
      final path = await saveReportCsv(overview, platformLabel: state.platform);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '$saved · ${path.split(Platform.pathSeparator).last}',
            ),
            action: SnackBarAction(
              label: reveal,
              onPressed: () {
                if (Platform.isMacOS) {
                  Process.run('open', ['-R', path]);
                } else if (Platform.isWindows) {
                  Process.run('explorer', ['/select,', path]);
                }
              },
            ),
          ),
        );
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppTheme.coral),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ReportsCubit>();
    final overview = state.overview;
    final range = ReportsCubit.rangeOf(state.filter, DateTime.now());
    final updated = overview?.generatedAt;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 1280;
          final title = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  size: 22,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t(context, 'Reports', 'التقارير'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${rangeLabel(context, range.from, range.to)}  ·  ${_platformLabel(context, state.platform)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),
            ],
          );
          final controls = Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showOrdersDateFilterDialog(
                    context,
                    current: state.filter,
                  );
                  if (picked != null) cubit.setFilter(picked);
                },
                icon: const Icon(Icons.calendar_month_rounded, size: 18),
                label: Text(dateFilterLabel(context, state.filter)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              _PlatformSwitch(
                selected: state.platform,
                onChanged: cubit.setPlatform,
              ),
              OutlinedButton.icon(
                onPressed: overview == null ? null : () => _export(context),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: Text(t(context, 'Export CSV', 'تصدير CSV')),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              Tooltip(
                message: updated == null
                    ? t(context, 'Refresh', 'تحديث')
                    : '${t(context, 'Updated', 'آخر تحديث')} ${updated.hour.toString().padLeft(2, '0')}:${updated.minute.toString().padLeft(2, '0')}:${updated.second.toString().padLeft(2, '0')}',
                child: IconButton.filledTonal(
                  onPressed: state.refreshing
                      ? null
                      : () => cubit.load(silent: true),
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ),
            ],
          );
          return stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [title, const SizedBox(height: 12), controls],
                )
              : Row(
                  children: [
                    title,
                    const SizedBox(width: 20),
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: controls,
                      ),
                    ),
                  ],
                );
        },
      ),
    );
  }
}

class _PlatformSwitch extends StatelessWidget {
  const _PlatformSwitch({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = [
      (
        'all',
        t(context, 'All platforms', 'كل المنصات'),
        Icons.apps_rounded,
        AppTheme.primary,
      ),
      ('keeta', 'Keeta', Icons.delivery_dining_rounded, platformColor('keeta')),
      (
        'hungerstation',
        'HungerStation',
        Icons.two_wheeler_rounded,
        platformColor('hungerstation'),
      ),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (id, label, icon, color) in options)
            _PlatformPill(
              label: label,
              icon: icon,
              color: color,
              selected: id == selected,
              onTap: () => onChanged(id),
            ),
        ],
      ),
    );
  }
}

class _PlatformPill extends StatelessWidget {
  const _PlatformPill({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : const [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: selected ? 1.15 : 1,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutBack,
                child: Icon(
                  icon,
                  size: 18,
                  color: selected ? Colors.white : color,
                ),
              ),
              const SizedBox(width: 7),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 260),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? Colors.white : AppTheme.textSecondary,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 40,
            color: AppTheme.textMuted,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 420,
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => context.read<ReportsCubit>().load(),
            child: Text(t(context, 'Try again', 'حاول مرة أخرى')),
          ),
        ],
      ),
    );
  }
}

/// Shown when a new choice (days or platform) could not be loaded: the numbers
/// below are from the previous choice, not the one now selected.
class _StaleBanner extends StatelessWidget {
  const _StaleBanner({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      color: AppTheme.coral.withValues(alpha: 0.1),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: AppTheme.coral,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              t(
                context,
                'Could not load this selection, so the numbers below are from the previous one. $error',
                'تعذّر تحميل هذا الاختيار، فالأرقام أدناه من الاختيار السابق. $error',
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, color: AppTheme.coral),
            ),
          ),
          TextButton(
            onPressed: () => context.read<ReportsCubit>().load(),
            child: Text(t(context, 'Retry', 'إعادة المحاولة')),
          ),
        ],
      ),
    );
  }
}

// ── Body ────────────────────────────────────────────────────────────────────

class _Body extends StatelessWidget {
  const _Body({required this.overview, required this.platform});

  final ReportOverview overview;
  final String platform;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth > 1100;
        const gap = 16.0;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (overview.kpis.orders == 0) ...[
                    const _EmptyNotice(),
                    const SizedBox(height: gap),
                  ],
                  _KpiGrid(overview: overview, width: c.maxWidth - 48),
                  const SizedBox(height: gap),
                  _pair(
                    wide,
                    gap,
                    flexA: 5,
                    flexB: 2,
                    a: _TrendCard(overview: overview, platform: platform),
                    b: _PlatformCard(overview: overview),
                  ),
                  const SizedBox(height: gap),
                  _pair(
                    wide,
                    gap,
                    flexA: 3,
                    flexB: 2,
                    a: _RankedCard(overview: overview, addOns: false),
                    b: Column(
                      children: [
                        _RankedCard(overview: overview, addOns: true),
                        const SizedBox(height: gap),
                        _CancellationsCard(overview: overview),
                      ],
                    ),
                  ),
                  if (overview.daily.length > 1) ...[
                    const SizedBox(height: gap),
                    _HoursCard(overview: overview),
                  ],
                  const SizedBox(height: gap),
                  _DailyTable(overview: overview),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _pair(
    bool wide,
    double gap, {
    required int flexA,
    required int flexB,
    required Widget a,
    required Widget b,
  }) => wide
      ? Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: flexA, child: a),
            SizedBox(width: gap),
            Expanded(flex: flexB, child: b),
          ],
        )
      : Column(
          children: [
            a,
            SizedBox(height: gap),
            b,
          ],
        );
}

class _EmptyNotice extends StatelessWidget {
  const _EmptyNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppTheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              t(
                context,
                'No orders in this period. Pick another date range, or switch platform.',
                'لا توجد طلبات في هذه الفترة. اختر فترة أخرى أو غيّر المنصة.',
              ),
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

// ── KPIs ────────────────────────────────────────────────────────────────────

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.overview, required this.width});

  final ReportOverview overview;
  final double width;

  @override
  Widget build(BuildContext context) {
    final k = overview.kpis;
    final p = overview.previous;
    final days = overview.daily;
    final multi = days.length > 1;

    final tiles = [
      KpiTile(
        icon: Icons.receipt_long_rounded,
        label: t(context, 'Orders', 'الطلبات'),
        value: k.orders.toDouble(),
        text: groupDigits(k.orders),
        previous: p.orders.toDouble(),
        trend: multi ? [for (final d in days) d.orders.toDouble()] : null,
      ),
      KpiTile(
        icon: Icons.payments_rounded,
        label: t(context, 'Sales', 'المبيعات'),
        value: major(k.grossMinor),
        text: moneyText(context, k.grossMinor),
        previous: major(p.grossMinor),
        color: const Color(0xFF16A34A),
        trend: multi ? [for (final d in days) d.grossMinor.toDouble()] : null,
      ),
      KpiTile(
        icon: Icons.shopping_basket_rounded,
        label: t(context, 'Average order', 'متوسط الطلب'),
        value: major(k.avgOrderMinor),
        text: moneyText(context, k.avgOrderMinor),
        previous: major(p.avgOrderMinor),
        color: const Color(0xFF7C4DFF),
      ),
      KpiTile(
        icon: Icons.cancel_rounded,
        label: t(context, 'Cancellation rate', 'نسبة الإلغاء'),
        value: k.cancelRate * 100,
        text: percent(k.cancelRate),
        previous: p.cancelRate * 100,
        lowerIsBetter: true,
        color: AppTheme.coral,
        trend: multi
            ? [
                for (final d in days)
                  d.orders == 0 ? 0 : d.cancelled / d.orders * 100,
              ]
            : null,
      ),
      KpiTile(
        icon: Icons.timer_rounded,
        label: t(context, 'Avg preparation', 'متوسط التحضير'),
        value: k.avgPrepSeconds?.toDouble(),
        text: duration(k.avgPrepSeconds),
        previous: p.avgPrepSeconds?.toDouble(),
        lowerIsBetter: true,
        color: const Color(0xFFFB8C00),
      ),
      KpiTile(
        icon: Icons.local_offer_rounded,
        label: t(context, 'Discounts given', 'الخصومات'),
        value: major(k.discountMinor),
        text: moneyText(context, k.discountMinor),
        previous: major(p.discountMinor),
        lowerIsBetter: true,
        color: const Color(0xFF0891B2),
      ),
    ];

    const gap = 14.0;
    final columns = width > 1400 ? 6 : (width > 800 ? 3 : 2);
    final tileWidth = (width - gap * (columns - 1)) / columns;
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: [
        for (final tile in tiles) SizedBox(width: tileWidth, child: tile),
      ],
    );
  }
}

// ── Trend (per day, or per hour for a single day) ───────────────────────────

class _TrendCard extends StatefulWidget {
  const _TrendCard({required this.overview, required this.platform});

  final ReportOverview overview;
  final String platform;

  @override
  State<_TrendCard> createState() => _TrendCardState();
}

class _TrendCardState extends State<_TrendCard> {
  bool _sales = false;

  @override
  Widget build(BuildContext context) {
    final o = widget.overview;
    final singleDay = o.daily.length == 1;
    final bars = singleDay
        ? _hourBars(context, o, _sales)
        : _dayBars(context, o, _sales);
    return ReportCard(
      icon: Icons.bar_chart_rounded,
      title: singleDay
          ? t(context, 'Today by hour', 'حسب الساعة')
          : t(
              context,
              'Sales and orders by day',
              'المبيعات والطلبات حسب اليوم',
            ),
      subtitle: widget.platform == 'all' && !singleDay
          ? t(context, 'Split by platform', 'موزّعة حسب المنصة')
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.platform == 'all' && !singleDay) ...[
            const _Legend(),
            const SizedBox(width: 14),
          ],
          SegmentedButton<bool>(
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
            segments: [
              ButtonSegment(
                value: false,
                label: Text(t(context, 'Orders', 'الطلبات')),
              ),
              ButtonSegment(
                value: true,
                label: Text(t(context, 'Sales', 'المبيعات')),
              ),
            ],
            selected: {_sales},
            onSelectionChanged: (s) => setState(() => _sales = s.first),
          ),
        ],
      ),
      child: AxisBarChart(
        bars: bars,
        axisLabel: (v) => _sales ? compact(v) : compact(v),
      ),
    );
  }

  /// One bar per day (per week once the range is long), stacked by platform.
  List<BarData> _dayBars(BuildContext context, ReportOverview o, bool sales) {
    final byWeek = o.daily.length > 45;
    final step = byWeek ? 7 : 1;
    final groups = [
      for (var i = 0; i < o.daily.length; i += step)
        o.daily.sublist(i, (i + step).clamp(0, o.daily.length)),
    ];
    final every = (groups.length / 10).ceil().clamp(1, 1000);
    return [
      for (var i = 0; i < groups.length; i++)
        () {
          final g = groups[i];
          double sum(int Function(ReportDay) f) =>
              g.fold<int>(0, (s, d) => s + f(d)).toDouble();
          final total = sales
              ? sum((d) => d.grossMinor) / 100
              : sum((d) => d.orders);
          final keeta = sales
              ? sum((d) => d.salesByPlatform['keeta'] ?? 0) / 100
              : sum((d) => d.byPlatform['keeta'] ?? 0);
          final hs = sales
              ? sum((d) => d.salesByPlatform['hungerstation'] ?? 0) / 100
              : sum((d) => d.byPlatform['hungerstation'] ?? 0);
          final other = (total - keeta - hs)
              .clamp(0, double.infinity)
              .toDouble();
          final label = g.first.date == g.last.date
              ? shortDate(context, g.first.date)
              : '${shortDate(context, g.first.date)} – ${shortDate(context, g.last.date)}';
          final orders = sum((d) => d.orders).round();
          final money = moneyText(
            context,
            g.fold(0, (s, d) => s + d.grossMinor),
          );
          return BarData(
            segments: [
              BarSegment(keeta, platformColor('keeta')),
              BarSegment(hs, platformColor('hungerstation')),
              if (other > 0) BarSegment(other, AppTheme.primary),
            ],
            tooltip: '$label\n$orders ${t(context, 'orders', 'طلب')} · $money',
            label: i % every == 0 ? shortDate(context, g.first.date) : null,
          );
        }(),
    ];
  }

  /// 24 bars for a single day.
  List<BarData> _hourBars(BuildContext context, ReportOverview o, bool sales) {
    final peak = o.hourly.fold<ReportHour?>(
      null,
      (m, h) => h.orders > 0 && (m == null || h.orders > m.orders) ? h : m,
    );
    return [
      for (final h in o.hourly)
        BarData(
          segments: [
            BarSegment(
              sales ? h.grossMinor / 100 : h.orders.toDouble(),
              h.hour == peak?.hour ? AppTheme.coral : AppTheme.primary,
            ),
          ],
          tooltip:
              '${h.hour.toString().padLeft(2, '0')}:00\n${h.orders} ${t(context, 'orders', 'طلب')} · ${moneyText(context, h.grossMinor)}',
          label: h.hour % 3 == 0 ? '${h.hour}:00' : null,
        ),
    ];
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget dot(String platform) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: platformColor(platform),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          platformName(platform),
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
      ],
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [dot('keeta'), const SizedBox(width: 12), dot('hungerstation')],
    );
  }
}

// ── Platforms, hours, rankings, cancellations ───────────────────────────────

class _PlatformCard extends StatelessWidget {
  const _PlatformCard({required this.overview});

  final ReportOverview overview;

  @override
  Widget build(BuildContext context) {
    final byId = {for (final p in overview.platforms) p.platform: p};
    final total = overview.platforms.fold<int>(0, (s, p) => s + p.grossMinor);
    return ReportCard(
      icon: Icons.donut_small_rounded,
      title: t(context, 'By platform', 'حسب المنصة'),
      subtitle: t(context, 'Share of sales', 'حصة المبيعات'),
      child: Column(
        children: [
          for (final id in const ['keeta', 'hungerstation'])
            PlatformShareRow(
              platform: id,
              orders: byId[id]?.orders ?? 0,
              salesMinor: byId[id]?.grossMinor ?? 0,
              share: total == 0 ? 0 : (byId[id]?.grossMinor ?? 0) / total,
            ),
        ],
      ),
    );
  }
}

class _HoursCard extends StatelessWidget {
  const _HoursCard({required this.overview});

  final ReportOverview overview;

  @override
  Widget build(BuildContext context) {
    final peak = overview.hourly.fold<ReportHour?>(
      null,
      (m, h) => h.orders > 0 && (m == null || h.orders > m.orders) ? h : m,
    );
    return ReportCard(
      icon: Icons.schedule_rounded,
      title: t(context, 'Busiest hours', 'أوقات الذروة'),
      subtitle: t(
        context,
        'Orders by hour of the day, all days in the range',
        'الطلبات حسب ساعة اليوم، لكل أيام الفترة',
      ),
      trailing: peak == null
          ? null
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.coral.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                t(
                  context,
                  'Peak ${peak.hour.toString().padLeft(2, '0')}:00 · ${peak.orders} orders',
                  'الذروة ${peak.hour.toString().padLeft(2, '0')}:00 · ${peak.orders} طلب',
                ),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.coral,
                ),
              ),
            ),
      child: AxisBarChart(
        height: 190,
        axisLabel: compact,
        bars: [
          for (final h in overview.hourly)
            BarData(
              segments: [
                BarSegment(
                  h.orders.toDouble(),
                  h.hour == peak?.hour
                      ? AppTheme.coral
                      : AppTheme.primary.withValues(alpha: 0.8),
                ),
              ],
              tooltip:
                  '${h.hour.toString().padLeft(2, '0')}:00 · ${h.orders} ${t(context, 'orders', 'طلب')}',
              label: h.hour % 2 == 0 ? '${h.hour}' : null,
            ),
        ],
      ),
    );
  }
}

class _RankedCard extends StatelessWidget {
  const _RankedCard({required this.overview, required this.addOns});

  final ReportOverview overview;
  final bool addOns;

  @override
  Widget build(BuildContext context) {
    final list = addOns ? overview.topAddOns : overview.topProducts;
    return ReportCard(
      icon: addOns
          ? Icons.add_circle_outline_rounded
          : Icons.emoji_events_rounded,
      title: addOns
          ? t(context, 'Top add-ons', 'أكثر الإضافات')
          : t(context, 'Best sellers', 'الأكثر مبيعاً'),
      subtitle: addOns ? null : t(context, 'By revenue', 'حسب الإيراد'),
      child: RankedTable(
        rows: [
          for (final r in list)
            (name: r.name, qty: r.qty, revenueMinor: r.revenueMinor),
        ],
        color: addOns ? const Color(0xFF7C4DFF) : const Color(0xFF16A34A),
        emptyLabel: addOns
            ? t(context, 'No add-ons sold', 'لم تُبع إضافات')
            : t(context, 'No item data yet', 'لا بيانات أصناف بعد'),
        quantityLabel: t(context, 'QTY', 'الكمية'),
      ),
    );
  }
}

class _CancellationsCard extends StatelessWidget {
  const _CancellationsCard({required this.overview});

  final ReportOverview overview;

  @override
  Widget build(BuildContext context) {
    final total = overview.cancelReasons.fold<int>(0, (s, r) => s + r.orders);
    return ReportCard(
      icon: Icons.report_gmailerrorred_rounded,
      title: t(context, 'Why orders were cancelled', 'أسباب الإلغاء'),
      subtitle: total == 0
          ? null
          : t(context, '$total cancelled', '$total ملغاة'),
      child: overview.cancelReasons.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF16A34A),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    t(context, 'No cancellations', 'لا إلغاءات'),
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                for (final r in overview.cancelReasons)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                r.reason == 'unspecified'
                                    ? t(context, 'No reason given', 'بدون سبب')
                                    : r.reason,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Text(
                              '${r.orders}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppTheme.coral,
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 44,
                              child: Text(
                                percent(r.orders / total, digits: 0),
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: r.orders / total,
                            minHeight: 5,
                            color: AppTheme.coral,
                            backgroundColor: AppTheme.coral.withValues(
                              alpha: 0.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

// ── Daily breakdown table ───────────────────────────────────────────────────

class _DailyTable extends StatelessWidget {
  const _DailyTable({required this.overview});

  final ReportOverview overview;

  @override
  Widget build(BuildContext context) {
    final rows = overview.daily.reversed.toList(); // newest first
    final k = overview.kpis;
    TextStyle head() => TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w700,
      color: AppTheme.textMuted,
      letterSpacing: context.isArabic ? 0 : 0.6,
    );

    Widget cell(
      String text, {
      int flex = 2,
      bool strong = false,
      Color? color,
      TextAlign align = TextAlign.end,
    }) => Expanded(
      flex: flex,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: align,
        style: TextStyle(
          fontSize: 13,
          fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
          color: color ?? AppTheme.textPrimary,
        ),
      ),
    );

    Widget line(List<Widget> cells, {Color? background, bool top = true}) =>
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: background,
            border: top
                ? const Border(top: BorderSide(color: AppTheme.border))
                : null,
          ),
          child: Row(children: cells),
        );

    return ReportCard(
      icon: Icons.table_rows_rounded,
      title: t(context, 'Day by day', 'يوماً بيوم'),
      subtitle: t(
        context,
        '${rows.length} days · newest first',
        '${rows.length} يوم · الأحدث أولاً',
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.border),
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            line(top: false, background: AppTheme.surfaceAlt, [
              Expanded(
                flex: 3,
                child: Text(t(context, 'DATE', 'التاريخ'), style: head()),
              ),
              for (final h in [
                t(context, 'ORDERS', 'الطلبات'),
                'KEETA',
                'HUNGERSTATION',
                t(context, 'CANCELLED', 'ملغاة'),
                t(context, 'SALES', 'المبيعات'),
                t(context, 'AVG ORDER', 'متوسط الطلب'),
              ])
                Expanded(
                  flex: 2,
                  child: Text(
                    h,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: head(),
                  ),
                ),
            ]),
            // Totals first, so the sum is visible without scrolling.
            line(background: AppTheme.primary.withValues(alpha: 0.05), [
              cell(
                t(context, 'Total', 'الإجمالي'),
                flex: 3,
                strong: true,
                align: TextAlign.start,
              ),
              cell(groupDigits(k.orders), strong: true),
              cell(
                groupDigits(
                  rows.fold(0, (s, d) => s + (d.byPlatform['keeta'] ?? 0)),
                ),
                strong: true,
              ),
              cell(
                groupDigits(
                  rows.fold(
                    0,
                    (s, d) => s + (d.byPlatform['hungerstation'] ?? 0),
                  ),
                ),
                strong: true,
              ),
              cell(
                groupDigits(k.cancelled),
                strong: true,
                color: k.cancelled > 0 ? AppTheme.coral : null,
              ),
              cell(amountText(k.grossMinor), strong: true),
              cell(amountText(k.avgOrderMinor), strong: true),
            ]),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 380),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: rows.length,
                itemBuilder: (context, i) {
                  final d = rows[i];
                  final billable = d.orders - d.cancelled;
                  final empty = d.orders == 0;
                  final muted = empty ? AppTheme.textMuted : null;
                  return line([
                    cell(
                      '${shortDate(context, d.date)} ${d.date.year}',
                      flex: 3,
                      align: TextAlign.start,
                      color: muted,
                    ),
                    cell(empty ? '—' : groupDigits(d.orders), color: muted),
                    cell(
                      empty ? '—' : groupDigits(d.byPlatform['keeta'] ?? 0),
                      color: muted,
                    ),
                    cell(
                      empty
                          ? '—'
                          : groupDigits(d.byPlatform['hungerstation'] ?? 0),
                      color: muted,
                    ),
                    cell(
                      empty ? '—' : groupDigits(d.cancelled),
                      color: d.cancelled > 0 ? AppTheme.coral : muted,
                    ),
                    cell(
                      empty ? '—' : amountText(d.grossMinor),
                      color: muted,
                      strong: !empty,
                    ),
                    cell(
                      billable > 0
                          ? amountText((d.grossMinor / billable).round())
                          : '—',
                      color: muted,
                    ),
                  ]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
