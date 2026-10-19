import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/localization/locale_context.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/platform_colors.dart';
import 'report_format.dart';

export 'report_format.dart';

Color platformColor(String platform) => PlatformColors.of(platform);

String platformName(String platform) => switch (platform) {
  'keeta' => 'Keeta',
  'hungerstation' => 'HungerStation',
  _ => platform,
};

/// A white card with a title row, used by every block of the Reports screen.
class ReportCard extends StatelessWidget {
  const ReportCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.icon,
    this.padding = const EdgeInsets.all(20),
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  final IconData? icon;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(icon, size: 17, color: AppTheme.primary),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

/// One headline number with its change against the previous period and, for
/// ranges longer than a day, a small trend line.
class KpiTile extends StatelessWidget {
  const KpiTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.text,
    required this.previous,
    this.trend,
    this.lowerIsBetter = false,
    this.color = AppTheme.primary,
    this.hint,
  });

  final IconData icon;
  final String label;

  /// Raw value, for the change against [previous] (null = no data).
  final double? value;
  final String text;
  final double? previous;
  final List<double>? trend;
  final bool lowerIsBetter;
  final Color color;

  /// Shown instead of the change when there is none (e.g. "no earlier data").
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final cur = value;
    final delta = cur != null && previous != null && previous! > 0
        ? (cur - previous!) / previous!
        : null;
    final good = delta == null
        ? null
        : (lowerIsBetter ? delta <= 0 : delta >= 0);
    final tone = good == null
        ? AppTheme.textMuted
        : (good ? const Color(0xFF16A34A) : AppTheme.coral);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // One line always: a long number shrinks instead of wrapping.
          SizedBox(
            height: 36,
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: cur == null
                  ? const Text(
                      '—',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    )
                  : TweenAnimationBuilder<double>(
                      key: ValueKey(text),
                      tween: Tween(begin: 0.6, end: 1),
                      duration: const Duration(milliseconds: 420),
                      curve: Curves.easeOutCubic,
                      builder: (_, f, child) =>
                          Opacity(opacity: f.clamp(0.0, 1.0), child: child),
                      child: Text(
                        text,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 18,
            child: delta != null
                ? Row(
                    children: [
                      Icon(
                        delta >= 0
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 14,
                        color: tone,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${(delta.abs() * 100).toStringAsFixed(delta.abs() < 0.1 ? 1 : 0)}%',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                          color: tone,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          t(context, 'vs previous period', 'عن الفترة السابقة'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ),
                    ],
                  )
                : Text(
                    hint ?? '',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppTheme.textMuted,
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 30,
            child:
                trend != null && trend!.length > 1 && trend!.any((v) => v > 0)
                ? CustomPaint(
                    painter: _SparklinePainter(trend!, color),
                    size: Size.infinite,
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter(this.values, this.color);

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final peak = values.fold<double>(0, math.max);
    if (peak <= 0 || size.width <= 0) return;
    final dx = size.width / (values.length - 1);
    Offset point(int i) => Offset(
      i * dx,
      size.height - 2 - (values[i] / peak) * (size.height - 4),
    );

    final line = Path()..moveTo(point(0).dx, point(0).dy);
    for (var i = 1; i < values.length; i++) {
      final a = point(i - 1);
      final b = point(i);
      line.cubicTo(
        (a.dx + b.dx) / 2,
        a.dy,
        (a.dx + b.dx) / 2,
        b.dy,
        b.dx,
        b.dy,
      );
    }
    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.values != values || old.color != color;
}

class BarSegment {
  const BarSegment(this.value, this.color);
  final double value;
  final Color color;
}

class BarData {
  const BarData({required this.segments, required this.tooltip, this.label});

  final List<BarSegment> segments;
  final String tooltip;

  /// Under the bar; null = leave blank (labels are thinned out on dense charts).
  final String? label;

  double get total => segments.fold(0, (s, e) => s + e.value);
}

/// Bars with a value axis and light gridlines. Bars grow in when the data
/// changes, never get wider than [maxBarWidth] (one day is a bar, not a wall),
/// and show the exact numbers on hover.
class AxisBarChart extends StatelessWidget {
  const AxisBarChart({
    super.key,
    required this.bars,
    required this.axisLabel,
    this.height = 240,
    this.maxBarWidth = 56,
  });

  final List<BarData> bars;
  final String Function(double value) axisLabel;
  final double height;
  final double maxBarWidth;

  static const double _xLabelHeight = 22;
  static const double _axisWidth = 48;

  @override
  Widget build(BuildContext context) {
    final peak = bars.fold<double>(0, (m, b) => math.max(m, b.total));
    if (peak <= 0) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            t(context, 'No orders in this period', 'لا طلبات في هذه الفترة'),
            style: const TextStyle(color: AppTheme.textMuted),
          ),
        ),
      );
    }
    final top = niceCeil(peak);
    final plot = height - _xLabelHeight;

    return SizedBox(
      height: height,
      child: TweenAnimationBuilder<double>(
        key: ValueKey(Object.hashAll([for (final b in bars) b.total])),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeOutCubic,
        builder: (context, grow, _) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: _axisWidth,
              height: plot,
              child: Stack(
                children: [
                  for (final f in const [0.0, 0.5, 1.0])
                    Positioned(
                      left: 0,
                      right: 6,
                      bottom: f * plot - 7,
                      child: Text(
                        axisLabel(top * f),
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  // Gridlines at 0, 50% and 100% of the axis.
                  for (final f in const [0.0, 0.5, 1.0])
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: _xLabelHeight + f * plot,
                      child: Container(
                        height: 1,
                        color: f == 0
                            ? AppTheme.border
                            : AppTheme.border.withValues(alpha: 0.55),
                      ),
                    ),
                  Row(
                    children: [
                      for (final bar in bars)
                        Expanded(
                          child: Tooltip(
                            message: bar.tooltip,
                            child: Column(
                              children: [
                                SizedBox(
                                  height: plot,
                                  child: LayoutBuilder(
                                    builder: (context, c) {
                                      final w = math.min(
                                        c.maxWidth * 0.66,
                                        maxBarWidth,
                                      );
                                      final h = (bar.total / top * plot * grow)
                                          .clamp(0.0, plot);
                                      return Align(
                                        alignment: Alignment.bottomCenter,
                                        child: SizedBox(
                                          width: w,
                                          height: h,
                                          child: ClipRRect(
                                            borderRadius:
                                                const BorderRadius.vertical(
                                                  top: Radius.circular(5),
                                                ),
                                            child: Column(
                                              children: [
                                                for (final seg
                                                    in bar.segments.reversed)
                                                  if (seg.value > 0)
                                                    Expanded(
                                                      flex: math.max(
                                                        1,
                                                        (seg.value * 1000)
                                                            .round(),
                                                      ),
                                                      child: ColoredBox(
                                                        color: seg.color,
                                                        child:
                                                            const SizedBox.expand(),
                                                      ),
                                                    ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                SizedBox(
                                  height: _xLabelHeight,
                                  child: bar.label == null
                                      ? null
                                      : Center(
                                          child: FittedBox(
                                            child: Text(
                                              bar.label!,
                                              style: const TextStyle(
                                                fontSize: 10.5,
                                                color: AppTheme.textMuted,
                                              ),
                                            ),
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One platform: dot, name, orders, sales, its share of the total and a bar.
class PlatformShareRow extends StatelessWidget {
  const PlatformShareRow({
    super.key,
    required this.platform,
    required this.orders,
    required this.salesMinor,
    required this.share,
  });

  final String platform;
  final int orders;
  final int salesMinor;

  /// 0..1 of all sales in the range.
  final double share;

  @override
  Widget build(BuildContext context) {
    final color = platformColor(platform);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  platformName(platform),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
              ),
              Text(
                percent(share, digits: 0),
                style: TextStyle(fontWeight: FontWeight.w800, color: color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TweenAnimationBuilder<double>(
            key: ValueKey(share),
            tween: Tween(begin: 0, end: share.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 550),
            curve: Curves.easeOutCubic,
            builder: (_, f, _) => ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: f,
                minHeight: 9,
                color: color,
                backgroundColor: color.withValues(alpha: 0.12),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '$orders ${t(context, 'orders', 'طلب')}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                moneyText(context, salesMinor),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Ranked rows: position, name, quantity, revenue and a bar for the share.
class RankedTable extends StatelessWidget {
  const RankedTable({
    super.key,
    required this.rows,
    required this.color,
    required this.emptyLabel,
    required this.quantityLabel,
  });

  final List<({String name, int qty, int revenueMinor})> rows;
  final Color color;
  final String emptyLabel;
  final String quantityLabel;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 22),
        child: Center(
          child: Text(
            emptyLabel,
            style: const TextStyle(color: AppTheme.textMuted),
          ),
        ),
      );
    }
    final peak = rows.fold<int>(0, (m, r) => math.max(m, r.revenueMinor));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              const SizedBox(width: 32),
              Expanded(
                child: Text(t(context, 'ITEM', 'الصنف'), style: _head(context)),
              ),
              SizedBox(
                width: 64,
                child: Text(
                  quantityLabel,
                  textAlign: TextAlign.end,
                  style: _head(context),
                ),
              ),
              SizedBox(
                width: 120,
                child: Text(
                  t(context, 'REVENUE', 'الإيراد'),
                  textAlign: TextAlign.end,
                  style: _head(context),
                ),
              ),
            ],
          ),
        ),
        for (var i = 0; i < rows.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: AppTheme.border.withValues(alpha: i == 0 ? 1 : 0.6),
                ),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      margin: const EdgeInsetsDirectional.only(end: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: i < 3
                            ? color.withValues(alpha: 0.14)
                            : AppTheme.surfaceAlt,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: i < 3 ? color : AppTheme.textMuted,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        rows[i].name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 64,
                      child: Text(
                        groupDigits(rows[i].qty),
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 120,
                      child: Text(
                        amountText(rows[i].revenueMinor),
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 32),
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey('${rows[i].name}-${rows[i].revenueMinor}'),
                    tween: Tween(
                      begin: 0,
                      end: peak == 0 ? 0 : rows[i].revenueMinor / peak,
                    ),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    builder: (_, f, _) => ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: f,
                        minHeight: 5,
                        color: color,
                        backgroundColor: color.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  TextStyle _head(BuildContext context) => TextStyle(
    fontSize: 10.5,
    fontWeight: FontWeight.w700,
    color: AppTheme.textMuted,
    letterSpacing: context.isArabic ? 0 : 0.6,
  );
}
