import '../../orders/data/models/order_model.dart';

/// An order turned into the body Bayan's `/addOrderInternal` takes (without
/// the `Hash`, which is stamped per request), or the reasons it cannot be.
final class BayanOrderDraft {
  const BayanOrderDraft._({
    this.order,
    this.total = 0,
    this.problems = const [],
  });

  const BayanOrderDraft.ok(Map<String, Object?> order, double total)
    : this._(order: order, total: total);

  const BayanOrderDraft.invalid(List<String> problems)
    : this._(problems: problems);

  /// `{headers: {...}, items: [...]}`, null when [problems] is not empty.
  final Map<String, Object?>? order;

  /// `TotalValue`: what the lines come to after their own discounts.
  final double total;

  /// Why the order cannot be booked (an item with no Bayan number, say).
  final List<String> problems;

  bool get ok => order != null;
}

/// Maps a platform order onto Bayan's invoice shape.
///
/// Bayan takes, per order, `headers {AccNum, TotalValue, Remark}` and `items
/// [{Item, MatNum, Quantity, Price, Value, DisItem, RemarkI}]`. What is not
/// stated anywhere, so decided here (change it in this one place):
///
/// * `MatNum` is the Al-Bayan product number: the code the product was added
///   to the platform under (Keeta `skuOpenItemCode`, HungerStation `sku`).
/// * `Price` is the normal unit price, `Value = Quantity × Price`, `DisItem`
///   what the customer saved on that line (a promotion), and `TotalValue` the sum
///   of `Value − DisItem`.
/// * Add-ons are products in Bayan too: each one is a line of its own.
/// * Order-level discounts and the delivery fee are not lines; the platform
///   and order number go in `Remark`.
/// * Amounts are in the unit of Bayan's own prices (the order's major unit).
///
/// An order with any line that has no usable number is refused whole: a
/// partial invoice would be worse than none.
abstract final class BayanOrderMapper {
  static BayanOrderDraft build(OrderModel order, {required int account}) {
    if (account <= 0) {
      return const BayanOrderDraft.invalid(['No Bayan account number is set']);
    }
    final lines = <_Line>[];
    final problems = <String>[];

    final raw = order.rawOrder;
    if (raw['products'] is List) {
      _keeta(raw['products'] as List, lines, problems);
    } else if (raw['items'] is List) {
      _hungerStation(raw['items'] as List, lines, problems);
    }
    if (lines.isEmpty && problems.isEmpty) {
      problems.add('The order has no items');
    }
    if (problems.isNotEmpty) return BayanOrderDraft.invalid(problems);

    var total = 0.0;
    final items = <Map<String, Object?>>[];
    for (var i = 0; i < lines.length; i++) {
      final l = lines[i];
      final value = _round(l.quantity * l.price);
      final discount = _round(l.discount);
      total += value - discount;
      items.add({
        'Item': i,
        'MatNum': l.matNum,
        'Quantity': _num(l.quantity),
        'Price': _num(l.price),
        'Value': _num(value),
        'DisItem': _num(discount),
        'RemarkI': '',
      });
    }
    total = _round(total);
    return BayanOrderDraft.ok({
      'headers': {
        'AccNum': account,
        'TotalValue': _num(total),
        'Remark':
            '${order.platform} #${order.orderCode ?? order.platformOrderId}',
      },
      'items': items,
    }, total);
  }

  // ── Keeta ──────────────────────────────────────────────────────────────────

  /// `products[]`: amounts are whole numbers in the smallest unit (÷100).
  /// Add-ons are `groups[].shopProductGroupSkuList[]` (nested groups too);
  /// the mock's `subProductList` is read as well.
  static void _keeta(List products, List<_Line> lines, List<String> problems) {
    for (final p in products.whereType<Map>()) {
      final name = '${p['name'] ?? '?'}';
      final qty = (p['count'] as num?)?.toDouble() ?? 1;
      final code = p['skuOpenItemCode'] ?? p['spuOpenItemCode'];
      final matNum = _matNum(code);
      if (matNum == null) {
        problems.add('$name: no Bayan number');
      } else {
        final amount = p['priceWithoutGroup'];
        double minor(String key, double fallback) =>
            amount is Map && amount[key] is num
            ? (amount[key] as num).toDouble()
            : fallback;
        final origin = minor(
          'originUnitPrice',
          ((p['originPrice'] as num?)?.toDouble() ?? 0) / qty,
        );
        final paid = minor(
          'unitPrice',
          ((p['price'] as num?)?.toDouble() ?? 0) / qty,
        );
        lines.add(
          _Line(matNum, qty, origin / 100, ((origin - paid) * qty) / 100),
        );
      }
      _keetaGroups(p['groups'], qty, lines, problems);
      for (final s
          in (p['subProductList'] as List? ?? const []).whereType<Map>()) {
        final addOn = _matNum(s['openItemCode']);
        final count = (s['count'] as num?)?.toDouble() ?? 1;
        if (addOn == null) {
          problems.add('${s['name'] ?? '?'}: no Bayan number');
          continue;
        }
        final total = (s['price'] as num?)?.toDouble() ?? 0;
        lines.add(_Line(addOn, count, count == 0 ? 0 : total / count / 100, 0));
      }
    }
  }

  static void _keetaGroups(
    Object? groups,
    double parentQty,
    List<_Line> lines,
    List<String> problems,
  ) {
    if (groups is! List) return;
    for (final g in groups.whereType<Map>()) {
      for (final o
          in (g['shopProductGroupSkuList'] as List? ?? const [])
              .whereType<Map>()) {
        final count =
            (o['groupSkuCount'] as num?)?.toDouble() ??
            ((o['count'] as num?)?.toDouble() ?? 1) * parentQty;
        final matNum = _matNum(o['groupSkuOpenItemCode']);
        if (matNum == null) {
          problems.add('${o['spuName'] ?? '?'}: no Bayan number');
        } else if (count > 0) {
          lines.add(
            _Line(
              matNum,
              count,
              ((o['price'] as num?)?.toDouble() ?? 0) / 100,
              0,
            ),
          );
        }
        _keetaGroups(o['groups'], count, lines, problems);
      }
    }
  }

  // ── HungerStation ──────────────────────────────────────────────────────────

  /// `items[]` in plain decimals; `options[]` are the add-ons.
  static void _hungerStation(
    List items,
    List<_Line> lines,
    List<String> problems,
  ) {
    for (final item in items.whereType<Map>()) {
      final name = '${item['name'] ?? '?'}';
      final pricing = item['pricing'];
      final matNum = _matNum(item['sku']);
      if (matNum == null) {
        problems.add('$name: no Bayan number');
      } else {
        final qty =
            (pricing is Map ? pricing['quantity'] as num? : null)?.toDouble() ??
            1;
        final unit =
            (pricing is Map ? pricing['unit_price'] as num? : null)
                ?.toDouble() ??
            0;
        lines.add(
          _Line(matNum, qty, unit, (item['discount'] as num?)?.toDouble() ?? 0),
        );
      }
      for (final o in (item['options'] as List? ?? const []).whereType<Map>()) {
        final addOn = _matNum(o['sku']);
        if (addOn == null) {
          problems.add('${o['name'] ?? '?'}: no Bayan number');
          continue;
        }
        lines.add(
          _Line(
            addOn,
            (o['quantity'] as num?)?.toDouble() ?? 1,
            (o['unit_price'] as num?)?.toDouble() ?? 0,
            0,
          ),
        );
      }
    }
  }

  // ── Numbers ────────────────────────────────────────────────────────────────

  static int? _matNum(Object? code) {
    final n = int.tryParse('${code ?? ''}'.trim());
    return n != null && n > 0 ? n : null;
  }

  static double _round(double v) => (v * 100).round() / 100;

  /// Whole numbers go out as integers (`50000`, not `50000.0`).
  static num _num(double v) => v == v.truncateToDouble() ? v.toInt() : v;
}

final class _Line {
  const _Line(this.matNum, this.quantity, this.price, this.discount);

  final int matNum;
  final double quantity;
  final double price;
  final double discount;
}
