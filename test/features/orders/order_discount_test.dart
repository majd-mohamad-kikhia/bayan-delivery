import 'package:bayan_desktop/features/orders/data/models/order_model.dart';
import 'package:flutter_test/flutter_test.dart';

OrderModel order(String platform, Map<String, dynamic> raw) => OrderModel(
      platform: platform,
      platformOrderId: 'x',
      dongleNumber: 'D',
      status: 'NEW_ORDER',
      availableActions: const [],
      transportType: null,
      requiresUrgentAction: false,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      rawOrder: raw,
    );

void main() {
  test('Keeta: discount, payment and promotions come from feeDtl / orderPromotionDtlList', () {
    final o = order('keeta', {
      'feeDtl': {
        'customerFee': {
          'productPrice': 9000,
          'shippingFee': 1200,
          'platformFee': 0,
          'discounts': 2745,
          'payTotal': 7455,
        },
      },
      'orderPromotionDtlList': [
        {'typeName': 'Promo items', 'promotionRuleDesc': 'Burger 30% off', 'reduceFee': 1545},
        {'typeName': 'Delivery charge discount', 'reduceFee': 1200},
      ],
      'items': [
        {'name': 'A'},
        {'name': 'B'},
        {'name': 'C'},
      ],
    });

    expect(o.discountTotal, 27.45);
    expect(o.orderTotal, 74.55);
    expect(o.payment!['sub_total'], 90.0);
    expect(o.payment!['delivery_fee'], 12.0);
    expect(o.itemCount, 3);
    expect(o.promotions.map((p) => p.name), ['Burger 30% off', 'Delivery charge discount']);
    expect(o.promotions.fold<double>(0, (s, p) => s + p.amount), closeTo(27.45, 1e-9));
  });

  test('HungerStation: voucher plus item promotions, negative sign handled', () {
    final o = order('hungerstation', {
      'items': [
        {
          'name': 'Salad',
          'discount': 6.6,
          'promotion': [
            {'name': 'Weekend sale', 'type': 'STRIKETHROUGH', 'discount_amount': 6.6},
          ],
        },
        {'name': 'Pepsi', 'discount': 0},
      ],
      'payment': {'sub_total': 73.2, 'order_total': 73.88, 'discount': -7.32, 'delivery_fee': 8},
    });

    expect(o.discountTotal, closeTo(13.92, 1e-9)); // 7.32 voucher + 6.6 item promo
    expect(o.orderTotal, 73.88);
    expect(o.promotions.single.name, 'Weekend sale · Salad');
  });

  test('an order with no discount data reports none', () {
    final o = order('keeta', {'total': 33.0});
    expect(o.discountTotal, 0);
    expect(o.promotions, isEmpty);
    expect(o.orderTotal, 33.0);
  });
}
