/// Numbers for one period, as the backend reports them. Money is in minor
/// units (SAR 46.00 = 4600).
class ReportKpis {
  const ReportKpis({
    required this.orders,
    required this.completed,
    required this.cancelled,
    required this.grossMinor,
    required this.discountMinor,
    required this.itemsSold,
    required this.avgOrderMinor,
    required this.cancelRate,
    required this.avgPrepSeconds,
    required this.avgDeliverySeconds,
  });

  factory ReportKpis.fromJson(Map<String, dynamic> json) => ReportKpis(
    orders: (json['orders'] as num?)?.toInt() ?? 0,
    completed: (json['completed'] as num?)?.toInt() ?? 0,
    cancelled: (json['cancelled'] as num?)?.toInt() ?? 0,
    grossMinor: (json['grossMinor'] as num?)?.toInt() ?? 0,
    discountMinor: (json['discountMinor'] as num?)?.toInt() ?? 0,
    itemsSold: (json['itemsSold'] as num?)?.toInt() ?? 0,
    avgOrderMinor: (json['avgOrderMinor'] as num?)?.toInt() ?? 0,
    cancelRate: (json['cancelRate'] as num?)?.toDouble() ?? 0,
    avgPrepSeconds: (json['avgPrepSeconds'] as num?)?.toInt(),
    avgDeliverySeconds: (json['avgDeliverySeconds'] as num?)?.toInt(),
  );

  final int orders;
  final int completed;
  final int cancelled;
  final int grossMinor;
  final int discountMinor;
  final int itemsSold;
  final int avgOrderMinor;
  final double cancelRate;
  final int? avgPrepSeconds;
  final int? avgDeliverySeconds;
}

class ReportDay {
  const ReportDay({
    required this.date,
    required this.orders,
    required this.grossMinor,
    required this.cancelled,
    required this.byPlatform,
    this.salesByPlatform = const {},
  });

  factory ReportDay.fromJson(Map<String, dynamic> json) => ReportDay(
    date: DateTime.parse('${json['date']}T00:00:00Z'),
    orders: (json['orders'] as num?)?.toInt() ?? 0,
    grossMinor: (json['grossMinor'] as num?)?.toInt() ?? 0,
    cancelled: (json['cancelled'] as num?)?.toInt() ?? 0,
    byPlatform: {
      for (final e in ((json['byPlatform'] as Map?) ?? const {}).entries)
        '${e.key}': ((e.value as Map)['orders'] as num?)?.toInt() ?? 0,
    },
    salesByPlatform: {
      for (final e in ((json['byPlatform'] as Map?) ?? const {}).entries)
        '${e.key}': ((e.value as Map)['grossMinor'] as num?)?.toInt() ?? 0,
    },
  );

  final DateTime date;
  final int orders;
  final int grossMinor;
  final int cancelled;

  /// Orders per platform id.
  final Map<String, int> byPlatform;

  /// Sales (minor units) per platform id.
  final Map<String, int> salesByPlatform;
}

class ReportPlatform {
  const ReportPlatform({
    required this.platform,
    required this.orders,
    required this.grossMinor,
  });

  final String platform;
  final int orders;
  final int grossMinor;
}

class ReportHour {
  const ReportHour({
    required this.hour,
    required this.orders,
    required this.grossMinor,
  });

  final int hour;
  final int orders;
  final int grossMinor;
}

class ReportRanked {
  const ReportRanked({
    required this.name,
    required this.qty,
    required this.revenueMinor,
  });

  final String name;
  final int qty;
  final int revenueMinor;
}

class ReportReason {
  const ReportReason({required this.reason, required this.orders});

  final String reason;
  final int orders;
}

/// The whole Reports screen, from one backend response.
class ReportOverview {
  const ReportOverview({
    required this.from,
    required this.to,
    required this.kpis,
    required this.previous,
    required this.daily,
    required this.platforms,
    required this.hourly,
    required this.topProducts,
    required this.topAddOns,
    required this.cancelReasons,
    this.generatedAt,
  });

  factory ReportOverview.fromJson(Map<String, dynamic> json) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) build) => [
      for (final e in (json[key] as List? ?? const []).whereType<Map>())
        build(e.cast<String, dynamic>()),
    ];
    ReportRanked ranked(Map<String, dynamic> m) => ReportRanked(
      name: '${m['name']}',
      qty: (m['qty'] as num?)?.toInt() ?? 0,
      revenueMinor: (m['revenueMinor'] as num?)?.toInt() ?? 0,
    );
    final range = (json['range'] as Map?)?.cast<String, dynamic>() ?? const {};
    return ReportOverview(
      from: DateTime.parse('${range['from']}T00:00:00Z'),
      to: DateTime.parse('${range['to']}T00:00:00Z'),
      kpis: ReportKpis.fromJson(
        (json['kpis'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      previous: ReportKpis.fromJson(
        (json['previous'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      daily: list('daily', ReportDay.fromJson),
      platforms: list(
        'platforms',
        (m) => ReportPlatform(
          platform: '${m['platform']}',
          orders: (m['orders'] as num?)?.toInt() ?? 0,
          grossMinor: (m['grossMinor'] as num?)?.toInt() ?? 0,
        ),
      ),
      hourly: list(
        'hourly',
        (m) => ReportHour(
          hour: (m['hour'] as num?)?.toInt() ?? 0,
          orders: (m['orders'] as num?)?.toInt() ?? 0,
          grossMinor: (m['grossMinor'] as num?)?.toInt() ?? 0,
        ),
      ),
      topProducts: list('topProducts', ranked),
      topAddOns: list('topAddOns', ranked),
      cancelReasons: list(
        'cancelReasons',
        (m) => ReportReason(
          reason: '${m['reason']}',
          orders: (m['orders'] as num?)?.toInt() ?? 0,
        ),
      ),
      generatedAt: DateTime.tryParse('${json['generatedAt']}')?.toLocal(),
    );
  }

  final DateTime from;
  final DateTime to;
  final ReportKpis kpis;
  final ReportKpis previous;
  final List<ReportDay> daily;
  final List<ReportPlatform> platforms;
  final List<ReportHour> hourly;
  final List<ReportRanked> topProducts;
  final List<ReportRanked> topAddOns;
  final List<ReportReason> cancelReasons;

  /// When the backend built this answer.
  final DateTime? generatedAt;
}
