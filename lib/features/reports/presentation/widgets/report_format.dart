import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/localization/locale_context.dart';

/// Number, money and date wording for the Reports screen.

String t(BuildContext context, String en, String ar) =>
    context.isArabic ? ar : en;

double major(int minor) => minor / 100;

/// 1234567 → "1,234,567".
String groupDigits(int n) {
  final digits = n.abs().toString();
  final out = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}

/// Minor units → "43,563.16" (no currency).
String amountText(int minor) {
  final abs = minor.abs();
  final whole = groupDigits(abs ~/ 100);
  final cents = (abs % 100).toString().padLeft(2, '0');
  return '${minor < 0 ? '-' : ''}$whole.$cents';
}

/// "SAR 43,563.16" / "43,563.16 ر.س".
String moneyText(BuildContext context, int minor) =>
    context.isArabic ? '${amountText(minor)} ر.س' : 'SAR ${amountText(minor)}';

/// 43563 → "43.6K", 1200000 → "1.2M": for axis labels, where space is tight.
String compact(num v) {
  final a = v.abs();
  String trim(double x) =>
      x == x.roundToDouble() ? x.round().toString() : x.toStringAsFixed(1);
  if (a >= 1e6) return '${trim(v / 1e6)}M';
  if (a >= 1e3) return '${trim(v / 1e3)}K';
  return trim(v.toDouble());
}

String percent(double fraction, {int digits = 1}) =>
    '${(fraction * 100).toStringAsFixed(digits)}%';

String duration(int? seconds) {
  if (seconds == null) return '—';
  if (seconds < 60) return '${seconds}s';
  final m = seconds ~/ 60;
  return m < 60
      ? '${m}m ${(seconds % 60).toString().padLeft(2, '0')}s'
      : '${m ~/ 60}h ${m % 60}m';
}

const _monthsEn = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
const _monthsAr = [
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

String monthName(BuildContext context, int month) =>
    (context.isArabic ? _monthsAr : _monthsEn)[month - 1];

/// "18 Oct".
String shortDate(BuildContext context, DateTime d) =>
    '${d.day} ${monthName(context, d.month)}';

/// "18 Oct 2026" or "12 – 18 Oct 2026" or "28 Sep – 4 Oct 2026".
String rangeLabel(BuildContext context, DateTime from, DateTime to) {
  if (from == to) return '${shortDate(context, from)} ${from.year}';
  if (from.year == to.year && from.month == to.month) {
    return '${from.day} – ${to.day} ${monthName(context, to.month)} ${to.year}';
  }
  if (from.year == to.year) {
    return '${shortDate(context, from)} – ${shortDate(context, to)} ${to.year}';
  }
  return '${shortDate(context, from)} ${from.year} – ${shortDate(context, to)} ${to.year}';
}

/// The next "round" value at or above [value]: 43,563 → 50,000; 7 → 8... for chart axes.
double niceCeil(double value) {
  if (value <= 0) return 1;
  final exp = math.pow(10, (math.log(value) / math.ln10).floor()).toDouble();
  final n = value / exp;
  final nice = n <= 1
      ? 1
      : n <= 2
      ? 2
      : n <= 2.5
      ? 2.5
      : n <= 5
      ? 5
      : 10;
  return nice * exp;
}
