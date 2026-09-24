import 'keeta_client.dart';
import 'keeta_endpoints.dart';
import 'keeta_response.dart';

/// Keeta Menu API — shop categories, products (SPU/SKU) and choice groups.
///
/// Product, category and choice-group bodies are passed as maps in Keeta's
/// schema (see the Menu API reference) so no field is lost in translation.
/// Batch writes come back as one [KeetaResponse]; check
/// [KeetaResponse.hasPartialFailure].
class KeetaMenuApi {
  const KeetaMenuApi(this._client);

  final KeetaClient _client;

  // ── Products ──────────────────────────────────────────────────────────────

  Future<Object?> products(int shopId) async => (await _client.send(
    KeetaEndpoints.productList,
    params: {'shopId': shopId},
  )).data;

  /// One product; cheaper than listing the whole menu.
  Future<Map<String, dynamic>> product({
    required int shopId,
    required int spuId,
  }) async => (await _client.send(
    KeetaEndpoints.productDetail,
    params: {'shopId': shopId, 'spuId': spuId},
  )).dataMap;

  Future<Object?> checkProductsConflict({
    required int shopId,
    required List<int> spuIds,
  }) async => (await _client.send(
    KeetaEndpoints.checkProductsConflict,
    params: {'shopId': shopId, 'spuIdList': spuIds},
  )).data;

  Future<KeetaResponse> createProducts({
    required int shopId,
    required List<Map<String, Object?>> spuList,
  }) => _client.send(
    KeetaEndpoints.createProducts,
    params: {'shopId': shopId, 'spuList': spuList},
  );

  /// Updates in place, keeping `Spu.id` / `Sku.id` (promotions depend on them).
  Future<KeetaResponse> updateProducts({
    required int shopId,
    required List<Map<String, Object?>> spuList,
  }) => _client.send(
    KeetaEndpoints.updateProducts,
    params: {'shopId': shopId, 'spuList': spuList},
  );

  /// Chunked by 200. [deleteLinkedChoiceSkus] also removes linked choice-group SKUs.
  Future<KeetaResponse> deleteProducts({
    required int shopId,
    required List<int> spuIds,
    bool deleteLinkedChoiceSkus = false,
  }) => _client.sendBatched(
    KeetaEndpoints.deleteProducts,
    spuIds,
    (chunk) => {
      'shopId': shopId,
      'spuIdList': chunk,
      'linkedDel': deleteLinkedChoiceSkus,
    },
  );

  /// Enables/disables products by Keeta SPU id, chunked by 200. A category
  /// with no available product disappears from the app.
  Future<KeetaResponse> setProductsAvailable({
    required int shopId,
    required List<int> spuIds,
    required bool available,
    bool updateLinkedChoiceSkus = false,
  }) => _client.sendBatched(
    KeetaEndpoints.updateProductsStatus,
    spuIds,
    (chunk) => {
      'shopId': shopId,
      'spuIdList': chunk,
      'status': available ? 1 : 0,
      'needLinkage': updateLinkedChoiceSkus ? 1 : 0,
    },
  );

  /// [urlsBySpuId]: product id → picture URLs. Result arrives by webhook 1201.
  Future<KeetaResponse> bindProductPictures({
    required int shopId,
    required Map<int, List<String>> urlsBySpuId,
  }) => _client.send(
    KeetaEndpoints.bindProductPictures,
    params: {
      'shopId': shopId,
      'spuPictureList': [
        for (final entry in urlsBySpuId.entries)
          {'spuId': entry.key, 'urlList': entry.value},
      ],
    },
  );

  Future<KeetaResponse> updateProductSequence({
    required int shopId,
    required int categoryId,
    required int spuId,
    required int sequence,
  }) => _client.send(
    KeetaEndpoints.updateProductSequence,
    params: {
      'shopId': shopId,
      'shopCategoryId': categoryId,
      'spuId': spuId,
      'sequence': sequence,
    },
  );

  /// [sequenceBySpuId]: product id → position inside [categoryId].
  Future<KeetaResponse> reorderProducts({
    required int shopId,
    required int categoryId,
    required Map<int, int> sequenceBySpuId,
  }) => _client.send(
    KeetaEndpoints.batchUpdateProductSequence,
    params: {
      'shopId': shopId,
      'shopCategoryId': categoryId,
      'spuSequenceDTOList': _sequences(sequenceBySpuId, 'spuId'),
    },
  );

  /// Reorders products across every category in one call.
  Future<KeetaResponse> reorderAllProducts({
    required int shopId,
    required Map<int, Map<int, int>> sequenceBySpuIdByCategory,
  }) => _client.send(
    KeetaEndpoints.batchUpdateAllProductSequence,
    params: {
      'shopId': shopId,
      'shopCategoryId2SpuSeqMap': {
        for (final entry in sequenceBySpuIdByCategory.entries)
          '${entry.key}': _sequences(entry.value, 'spuId'),
      },
    },
  );

  // ── Categories ────────────────────────────────────────────────────────────

  Future<Object?> categories(int shopId) async => (await _client.send(
    KeetaEndpoints.categoryList,
    params: {'shopId': shopId},
  )).data;

  /// Required attributes for products in a platform category; `-1` = all.
  Future<Object?> categoryProperties({
    required int shopId,
    int categoryId = -1,
  }) async => (await _client.send(
    KeetaEndpoints.categoryProperties,
    params: {'shopId': shopId, 'categoryId': categoryId},
  )).data;

  Future<KeetaResponse> createCategory({
    required int shopId,
    required Map<String, Object?> category,
  }) => _client.send(
    KeetaEndpoints.createCategory,
    params: {'shopId': shopId, 'shopCategory': category},
  );

  Future<KeetaResponse> updateCategory({
    required int shopId,
    required Map<String, Object?> category,
  }) => _client.send(
    KeetaEndpoints.updateCategory,
    params: {'shopId': shopId, 'shopCategory': category},
  );

  Future<KeetaResponse> deleteCategories({
    required int shopId,
    required List<int> categoryIds,
  }) => _client.send(
    KeetaEndpoints.deleteCategories,
    params: {'shopId': shopId, 'shopCategoryIdList': categoryIds},
  );

  Future<KeetaResponse> updateCategorySequence({
    required int shopId,
    required int categoryId,
    required int sequence,
  }) => _client.send(
    KeetaEndpoints.updateCategorySequence,
    params: {'id': categoryId, 'shopId': shopId, 'sequence': sequence},
  );

  /// [sequenceByCategoryId] must contain **every** category of the shop,
  /// otherwise Keeta rejects the whole request.
  Future<KeetaResponse> reorderCategories({
    required int shopId,
    required Map<int, int> sequenceByCategoryId,
  }) => _client.send(
    KeetaEndpoints.batchUpdateCategorySequence,
    params: {
      'shopId': shopId,
      'openShopCategorySequenceDTOList': _sequences(
        sequenceByCategoryId,
        'shopCategoryId',
      ),
    },
  );

  // ── Choice groups (add-ons / modifiers) ───────────────────────────────────

  Future<Object?> choiceGroups(int shopId) async => (await _client.send(
    KeetaEndpoints.choiceGroupList,
    params: {'shopId': shopId},
  )).data;

  Future<Object?> choiceGroupAppliedProducts({
    required int shopId,
    required List<int> choiceGroupIds,
  }) async => (await _client.send(
    KeetaEndpoints.choiceGroupAppliedProducts,
    params: {'shopId': shopId, 'choiceGroupIdList': choiceGroupIds},
  )).data;

  Future<KeetaResponse> createChoiceGroups({
    required int shopId,
    required List<Map<String, Object?>> choiceGroups,
  }) => _client.send(
    KeetaEndpoints.createChoiceGroups,
    params: {'shopId': shopId, 'choiceGroupList': choiceGroups},
  );

  Future<KeetaResponse> updateChoiceGroups({
    required int shopId,
    required List<Map<String, Object?>> choiceGroups,
  }) => _client.send(
    KeetaEndpoints.updateChoiceGroups,
    params: {'shopId': shopId, 'choiceGroupList': choiceGroups},
  );

  Future<KeetaResponse> deleteChoiceGroups({
    required int shopId,
    required List<int> choiceGroupIds,
  }) => _client.send(
    KeetaEndpoints.deleteChoiceGroups,
    params: {'shopId': shopId, 'choiceGroupIdList': choiceGroupIds},
  );

  /// [skuIdsByChoiceGroupId]: choice group id → its SKU ids to toggle.
  Future<KeetaResponse> setChoiceGroupSkusAvailable({
    required int shopId,
    required Map<int, List<int>> skuIdsByChoiceGroupId,
    required bool available,
  }) => _client.send(
    KeetaEndpoints.updateChoiceGroupSkuStatus,
    params: {
      'shopId': shopId,
      'status': available ? 1 : 0,
      'choiceGroupSkuIdPackList': [
        for (final entry in skuIdsByChoiceGroupId.entries)
          {'choiceGroupId': entry.key, 'choiceGroupSkuIds': entry.value},
      ],
    },
  );

  // ── OpenItemCode based (your own ids) ─────────────────────────────────────

  /// Full menu push keyed by your codes: [menu] holds `shopCategoryList`,
  /// `spuList`, `spuSequenceCodeMap` and `choiceGroupList`.
  Future<KeetaResponse> syncMenu({
    required int shopId,
    required Map<String, Object?> menu,
  }) => _client.send(
    KeetaEndpoints.syncMenu,
    params: {...menu, 'shopId': shopId},
  );

  /// Maps existing Keeta products (matched by name) to your codes.
  Future<KeetaResponse> bindOpenItemCodes({
    required int shopId,
    required List<Map<String, Object?>> spuMappingList,
  }) => _client.send(
    KeetaEndpoints.bindOpenItemCodes,
    params: {'shopId': shopId, 'spuMappingList': spuMappingList},
  );

  /// Enables/disables products by your own codes, chunked by 200.
  Future<KeetaResponse> setProductsAvailableByCode({
    required int shopId,
    required List<String> openItemCodes,
    required bool available,
    bool updateLinkedChoiceSkus = false,
  }) => _client.sendBatched(
    KeetaEndpoints.updateProductsStatusByCode,
    openItemCodes,
    (chunk) => {
      'shopId': shopId,
      'spuOpenItemCodeList': chunk,
      'status': available ? 1 : 0,
      'needLinkage': updateLinkedChoiceSkus ? 1 : 0,
    },
  );

  /// [skuCodesByChoiceGroupCode]: choice group code → its SKU codes.
  Future<KeetaResponse> setChoiceGroupSkusAvailableByCode({
    required int shopId,
    required Map<String, List<String>> skuCodesByChoiceGroupCode,
    required bool available,
  }) => _client.send(
    KeetaEndpoints.updateChoiceGroupSkuStatusByCode,
    params: {
      'shopId': shopId,
      'choiceGroupSkuCodePackList': [
        for (final entry in skuCodesByChoiceGroupCode.entries)
          {'choiceGroupCode': entry.key, 'choiceGroupSkuCodes': entry.value},
      ],
      'status': available ? 1 : 0,
    },
  );

  static List<Map<String, int>> _sequences(
    Map<int, int> sequenceById,
    String idField,
  ) => [
    for (final entry in sequenceById.entries)
      {idField: entry.key, 'sequence': entry.value},
  ];
}
