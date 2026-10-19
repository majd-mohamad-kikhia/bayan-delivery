import 'package:flutter_test/flutter_test.dart';
import 'package:bayan_desktop/features/bayan_erp/data/models/erp_product_model.dart';
import 'package:bayan_desktop/features/products/data/erp_product_adapter.dart';
import 'package:bayan_desktop/features/products/data/models/listing_models.dart';
import 'package:bayan_desktop/features/products/data/models/product_model.dart';
import 'package:bayan_desktop/features/products/data/repositories/product_publish_repository.dart';

ErpProductModel _p(int id, String name, int parent, [double price = 0]) => ErpProductModel(
      id: id,
      name: name,
      shortName: '',
      quantity: 5,
      price1: price,
      price2: 0,
      price3: 0,
      price4: 0,
      price5: 0,
      currency: 0,
      parentId: parent,
    );

void main() {
  test('items under an "إضافات" group become one add-on group and are not products', () {
    final result = addOnsOf([
      _p(1, 'برغر', 0, 25),
      _p(10, 'إضافات', 0),
      _p(11, 'بطاطا زيادة', 10, 3),
      _p(12, 'جبنة زيادة', 10, 4),
    ]);
    expect(result.groups, hasLength(1));
    expect(result.groups.single.name, 'إضافات');
    expect([for (final o in result.groups.single.options) o.name], ['بطاطا زيادة', 'جبنة زيادة']);
    expect(result.excluded, {10, 11, 12});
  });

  test('a group without items is ignored; English names match too', () {
    expect(addOnsOf([_p(10, 'Add-ons', 0)]).groups, isEmpty);
    expect(isAddOnGroupName('Extras'), isTrue);
    expect(isAddOnGroupName('Drinks'), isFalse);
  });

  test('add-ons reach the Keeta listing and the SPU links the choice group', () {
    const group = AddOnGroup(
      name: 'Extras',
      options: [AddOnOption(sku: '11', name: 'Extra Potato', price: 3)],
    );
    final product = publishableFromErp(_p(1, 'Burger', 0, 25), addOnGroups: const [group]);
    final listing = PlatformListing.initialFor('keeta', product) as KeetaListing;
    expect(listing.addOnGroups, [group]);

    final body = ProductPublishRepository.keetaChoiceGroup(group);
    final skus = body['choiceGroupSkuList']! as List;
    expect((skus.single as Map)['openItemCode'], '11');
    expect((skus.single as Map)['price'], '3.00');

    expect(body['minNumber'], 0);
    expect(body['maxNumber'], 1);

    final spu = ProductPublishRepository.keetaSpu(
      ListingContent.fromProduct(product),
      listing,
      9001,
      [
        {...body, 'id': 9100},
      ],
    );
    // Add-ons hang off the SKU, not the SPU.
    expect(spu.containsKey('choiceGroupList'), isFalse);
    final sku = (spu['skuList']! as List).single as Map;
    expect((sku['choiceGroupList'] as List).single['id'], 9100);
  });
}
