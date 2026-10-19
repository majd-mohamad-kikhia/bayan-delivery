import 'package:bayan_desktop/core/network/bayan_erp_client.dart';
import 'package:bayan_desktop/features/bayan_erp/data/datasources/bayan_erp_datasource.dart';
import 'package:bayan_desktop/features/bayan_erp/data/models/erp_product_model.dart';
import 'package:bayan_desktop/features/bayan_erp/data/repositories/bayan_erp_repository.dart';
import 'package:bayan_desktop/features/orders/data/debug/saved_menu.dart';
import 'package:bayan_desktop/features/products/data/models/product_record.dart';
import 'package:flutter_test/flutter_test.dart';

ErpProductModel _erp(
  int id,
  String name,
  int parent,
  double price1, {
  int kind = 0,
}) => ErpProductModel(
  id: id,
  name: name,
  shortName: '',
  quantity: 1,
  price1: price1,
  price2: 0,
  price3: 0,
  price4: 0,
  price5: 0,
  currency: 0,
  parentId: parent,
  kind: kind,
);

class _FakeErp extends BayanErpRepository {
  _FakeErp(this.products) : super(BayanErpDatasource(BayanErpClient()));

  final List<ErpProductModel> products;

  @override
  Future<List<ErpProductModel>> getProducts({
    DateTime? since,
    int offset = 0,
    int limit = 20,
  }) async => products.skip(offset).take(limit).toList();
}

void main() {
  final erp = _FakeErp([
    _erp(1, 'صنف 1', 0, 0, kind: 1),
    _erp(2, 'مادة 1', 1, 12.5),
    _erp(6, 'طابعة', 1, 45),
    _erp(9, 'غير محفوظ', 1, 30),
    _erp(10, 'إضافات', 0, 0, kind: 1),
    _erp(11, 'بطاطا زيادة', 10, 3),
  ]);

  test(
    'only saved products, priced from Al-Bayan, with the add-on options',
    () async {
      final menu = await savedMenuForMockOrders(
        saved: const [
          ProductRecord(bayanNum: '2', name: 'مادة 1', keetaNum: '9001'),
          ProductRecord(bayanNum: '6', name: 'طابعة', hungerNum: 'HS-6'),
          ProductRecord(
            bayanNum: '77',
            name: 'Saved but not in Bayan',
            keetaNum: '9003',
          ),
          ProductRecord(bayanNum: '9', name: 'Not on any platform'),
        ],
        erp: erp,
      );

      final products = menu['products']! as List;
      expect(
        [for (final p in products) (p as Map)['name']],
        ['مادة 1', 'طابعة'],
      );
      expect((products.first as Map)['price'], 1250, reason: 'minor units');
      expect(((menu['addOns']! as List).single as Map)['name'], 'بطاطا زيادة');
    },
  );

  test('says so, instead of inventing products, when nothing is saved', () {
    expect(
      savedMenuForMockOrders(
        saved: const [ProductRecord(bayanNum: '9', name: 'x')],
        erp: erp,
      ),
      throwsA(isA<StateError>()),
    );
  });
}
