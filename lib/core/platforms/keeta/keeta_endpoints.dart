import '../common/delivery_platform.dart';
import '../common/http_method.dart';
import '../common/platform_endpoint.dart';

/// Every Keeta Open API operation — https://api-docs.mykeeta.com/apis/standard
///
/// All Keeta calls are `POST` with a JSON body carrying `appId`,
/// `accessToken`, `timestamp` and `sig` (added by `KeetaSigner`).
abstract final class KeetaEndpoints {
  static const String baseUrl = 'https://open.mykeeta.com/api/open';

  // ── Basic ─────────────────────────────────────────────────────────────────

  /// `grantType` = `authorization_code` (+ `code`) or `refresh_token`
  /// (+ `refreshToken`). Answers flat, without the `{code, data}` envelope.
  static const oauthToken = _Keeta(
    'base.oauthToken',
    '/base/oauth/token',
    requiresAuth: false,
  );

  /// Paginated; `pageSize` max 200.
  static const authorizedResources = _Keeta(
    'base.authorizedResources',
    '/base/authorized/resource/get',
    isRead: true,
  );
  static const batchDecrypt = _Keeta(
    'base.batchDecrypt',
    '/base/batchDecrypt',
    isRead: true,
    maxBatchSize: 50,
  );
  static const setWebhookUrl = _Keeta(
    'base.setWebhookUrl',
    '/base/callback/url/set',
  );

  // ── Order ─────────────────────────────────────────────────────────────────

  static const orderDetails = _Keeta(
    'order.details',
    '/order/get',
    isRead: true,
  );

  /// Must be called within 5 minutes of webhook 1001 or Keeta auto-cancels.
  static const confirmOrder = _Keeta('order.confirm', '/order/confirm');
  static const cancelOrder = _Keeta('order.cancel', '/order/cancel');
  static const orderReady = _Keeta('order.ready', '/order/prepare');
  static const confirmPickup = _Keeta('order.confirmPickup', '/order/collect');
  static const agreeRefund = _Keeta('order.agreeRefund', '/order/agree');
  static const rejectRefund = _Keeta('order.rejectRefund', '/order/reject');
  static const previewPartialRefund = _Keeta(
    'order.previewPartialRefund',
    '/order/refund/part/products/preview',
    isRead: true,
  );
  static const applyPartialRefund = _Keeta(
    'order.applyPartialRefund',
    '/order/refund/part/apply',
  );

  // ── Store ─────────────────────────────────────────────────────────────────

  static const shopDetails = _Keeta(
    'shop.details',
    '/scm/shop/base/get',
    isRead: true,
  );
  static const updateShopPicture = _Keeta(
    'shop.updatePicture',
    '/scm/shop/picture/main/update',
  );
  static const updateShopContact = _Keeta(
    'shop.updateContact',
    '/scm/shop/contact/update',
  );
  static const businessHours = _Keeta(
    'shop.businessHours',
    '/scm/shop/business/hour/effective/get',
    isRead: true,
  );
  static const updateBusinessHours = _Keeta(
    'shop.updateBusinessHours',
    '/scm/shop/business/hour/effective/update',
  );
  static const specialBusinessHours = _Keeta(
    'shop.specialBusinessHours',
    '/scm/shop/special/business/hour/effective/get',
    isRead: true,
  );
  static const updateSpecialBusinessHours = _Keeta(
    'shop.updateSpecialBusinessHours',
    '/scm/shop/special/business/hour/effective/update',
  );

  /// Status 3 → 4: hidden and blocked until reactivated.
  static const suspendShop = _Keeta('shop.suspend', '/scm/shop/status/rest');

  /// Status 4 → 3.
  static const reactivateShop = _Keeta(
    'shop.reactivate',
    '/scm/shop/status/open',
  );

  // ── Menu · Keeta-ID based ─────────────────────────────────────────────────

  static const productList = _Keeta(
    'menu.productList',
    '/product/spu/list',
    isRead: true,
  );
  static const productDetail = _Keeta(
    'menu.productDetail',
    '/product/spu/detail',
    isRead: true,
  );
  static const checkProductsConflict = _Keeta(
    'menu.checkProductsConflict',
    '/product/spu/batchcheck',
    isRead: true,
  );
  static const createProducts = _Keeta(
    'menu.createProducts',
    '/product/spu/batchcreate',
  );
  static const updateProducts = _Keeta(
    'menu.updateProducts',
    '/product/spu/batchupdate',
  );
  static const deleteProducts = _Keeta(
    'menu.deleteProducts',
    '/product/spu/batchdel',
    maxBatchSize: 200,
  );
  static const updateProductsStatus = _Keeta(
    'menu.updateProductsStatus',
    '/product/spustatus/batchupdate',
    maxBatchSize: 200,
  );
  static const bindProductPictures = _Keeta(
    'menu.bindProductPictures',
    '/product/spupicture/batchbind',
  );
  static const updateProductSequence = _Keeta(
    'menu.updateProductSequence',
    '/product/spu/updatesequence',
  );
  static const batchUpdateProductSequence = _Keeta(
    'menu.batchUpdateProductSequence',
    '/product/spu/batchupdatesequence',
  );
  static const batchUpdateAllProductSequence = _Keeta(
    'menu.batchUpdateAllProductSequence',
    '/product/spu/batchupdateallsequence',
  );

  static const categoryList = _Keeta(
    'menu.categoryList',
    '/product/shopcategory/list',
    isRead: true,
  );
  static const createCategory = _Keeta(
    'menu.createCategory',
    '/product/shopcategory/create',
  );
  static const updateCategory = _Keeta(
    'menu.updateCategory',
    '/product/shopcategory/update',
  );
  static const deleteCategories = _Keeta(
    'menu.deleteCategories',
    '/product/shopcategory/batchdel',
  );
  static const updateCategorySequence = _Keeta(
    'menu.updateCategorySequence',
    '/product/shopcategory/updatesequence',
  );

  /// Must include **every** category of the shop or Keeta rejects it.
  static const batchUpdateCategorySequence = _Keeta(
    'menu.batchUpdateCategorySequence',
    '/product/shopcategory/batchupdatesequence',
  );
  static const categoryProperties = _Keeta(
    'menu.categoryProperties',
    '/product/categoryproperty/list',
    isRead: true,
  );

  static const choiceGroupList = _Keeta(
    'menu.choiceGroupList',
    '/product/choicegroup/list',
    isRead: true,
  );
  static const choiceGroupAppliedProducts = _Keeta(
    'menu.choiceGroupAppliedProducts',
    '/product/choicegroup/listappliedspu',
    isRead: true,
  );
  static const createChoiceGroups = _Keeta(
    'menu.createChoiceGroups',
    '/product/choicegroup/batchcreate',
  );
  static const updateChoiceGroups = _Keeta(
    'menu.updateChoiceGroups',
    '/product/choicegroup/batchupdate',
  );
  static const deleteChoiceGroups = _Keeta(
    'menu.deleteChoiceGroups',
    '/product/choicegroup/batchdel',
  );
  static const updateChoiceGroupSkuStatus = _Keeta(
    'menu.updateChoiceGroupSkuStatus',
    '/product/choicegroupskustatus/batchupdate',
  );

  // ── Menu · OpenItemCode based (your own ids) ──────────────────────────────

  static const syncMenu = _Keeta('menu.sync', '/product/menu/sync');
  static const bindOpenItemCodes = _Keeta(
    'menu.bindOpenItemCodes',
    '/product/mapping/batchupdatebyname',
  );
  static const updateProductsStatusByCode = _Keeta(
    'menu.updateProductsStatusByCode',
    '/product/spustatus/batchupdatebycode',
    maxBatchSize: 200,
  );
  static const updateChoiceGroupSkuStatusByCode = _Keeta(
    'menu.updateChoiceGroupSkuStatusByCode',
    '/product/choicegroupskustatus/batchupdatebycode',
  );

  static const List<PlatformEndpoint> all = [
    oauthToken,
    authorizedResources,
    batchDecrypt,
    setWebhookUrl,
    orderDetails,
    confirmOrder,
    cancelOrder,
    orderReady,
    confirmPickup,
    agreeRefund,
    rejectRefund,
    previewPartialRefund,
    applyPartialRefund,
    shopDetails,
    updateShopPicture,
    updateShopContact,
    businessHours,
    updateBusinessHours,
    specialBusinessHours,
    updateSpecialBusinessHours,
    suspendShop,
    reactivateShop,
    productList,
    productDetail,
    checkProductsConflict,
    createProducts,
    updateProducts,
    deleteProducts,
    updateProductsStatus,
    bindProductPictures,
    updateProductSequence,
    batchUpdateProductSequence,
    batchUpdateAllProductSequence,
    categoryList,
    createCategory,
    updateCategory,
    deleteCategories,
    updateCategorySequence,
    batchUpdateCategorySequence,
    categoryProperties,
    choiceGroupList,
    choiceGroupAppliedProducts,
    createChoiceGroups,
    updateChoiceGroups,
    deleteChoiceGroups,
    updateChoiceGroupSkuStatus,
    syncMenu,
    bindOpenItemCodes,
    updateProductsStatusByCode,
    updateChoiceGroupSkuStatusByCode,
  ];
}

final class _Keeta extends PlatformEndpoint {
  const _Keeta(
    String id,
    String path, {
    super.isRead,
    super.requiresAuth,
    super.maxBatchSize,
  }) : super(
         'keeta.$id',
         platform: DeliveryPlatform.keeta,
         method: HttpMethod.post,
         path: path,
       );
}
