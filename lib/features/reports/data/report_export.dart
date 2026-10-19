import 'dart:convert';
import 'dart:io';

import 'report_models.dart';

String _day(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _money(int minor) => (minor / 100).toStringAsFixed(2);

/// One CSV cell: quoted when it holds a comma, quote or line break.
String _cell(Object? value) {
  final text = '$value';
  return text.contains(RegExp(r'[",\n\r]'))
      ? '"${text.replaceAll('"', '""')}"'
      : text;
}

String _row(List<Object?> cells) => cells.map(_cell).join(',');

/// The report as CSV, in sections that open as tables in Excel / Numbers:
/// summary, per day, per platform, best sellers, add-ons, cancellations.
/// Money is in riyals with two decimals; dates are `YYYY-MM-DD`.
String buildReportCsv(ReportOverview o, {required String platformLabel}) {
  final k = o.kpis;
  final lines = <String>[
    _row(['Report', '${_day(o.from)} to ${_day(o.to)}', platformLabel]),
    '',
    _row(['Summary']),
    _row(['Orders', k.orders]),
    _row(['Completed', k.completed]),
    _row(['Cancelled', k.cancelled]),
    _row(['Cancellation rate %', (k.cancelRate * 100).toStringAsFixed(1)]),
    _row(['Sales', _money(k.grossMinor)]),
    _row(['Discounts', _money(k.discountMinor)]),
    _row(['Average order', _money(k.avgOrderMinor)]),
    _row(['Items sold', k.itemsSold]),
    _row(['Average preparation (seconds)', k.avgPrepSeconds ?? '']),
    '',
    _row(['Per day']),
    _row([
      'Date',
      'Orders',
      'Keeta orders',
      'HungerStation orders',
      'Cancelled',
      'Sales',
    ]),
    for (final d in o.daily)
      _row([
        _day(d.date),
        d.orders,
        d.byPlatform['keeta'] ?? 0,
        d.byPlatform['hungerstation'] ?? 0,
        d.cancelled,
        _money(d.grossMinor),
      ]),
    '',
    _row(['Per platform']),
    _row(['Platform', 'Orders', 'Sales']),
    for (final p in o.platforms)
      _row([p.platform, p.orders, _money(p.grossMinor)]),
    '',
    _row(['Best sellers']),
    _row(['Item', 'Quantity', 'Revenue']),
    for (final p in o.topProducts)
      _row([p.name, p.qty, _money(p.revenueMinor)]),
    '',
    _row(['Add-ons']),
    _row(['Item', 'Quantity', 'Revenue']),
    for (final p in o.topAddOns) _row([p.name, p.qty, _money(p.revenueMinor)]),
    '',
    _row(['Cancellation reasons']),
    _row(['Reason', 'Orders']),
    for (final r in o.cancelReasons) _row([r.reason, r.orders]),
  ];
  return lines.join('\r\n');
}

/// Writes the CSV to the user's Downloads folder (UTF-8 with a BOM, so Excel
/// reads Arabic names correctly) and returns the file path.
Future<String> saveReportCsv(
  ReportOverview o, {
  required String platformLabel,
}) async {
  final home =
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
  if (home == null) throw StateError('Cannot find the Downloads folder');
  final dir = Directory('$home${Platform.pathSeparator}Downloads');
  if (!dir.existsSync()) dir.createSync(recursive: true);

  final name = 'report_${_day(o.from)}_${_day(o.to)}_$platformLabel.csv'
      .replaceAll(RegExp(r'[^\w.\-]'), '_');
  final file = File('${dir.path}${Platform.pathSeparator}$name');
  await file.writeAsBytes([
    0xEF,
    0xBB,
    0xBF,
    ...utf8.encode(buildReportCsv(o, platformLabel: platformLabel)),
  ]);
  return file.path;
}
