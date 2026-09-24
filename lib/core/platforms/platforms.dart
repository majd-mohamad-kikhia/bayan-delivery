/// Direct Keeta / HungerStation APIs, executed through the backend's
/// `executeApiAndSendWebhook` (route: `PLATFORM_EXECUTOR_PATH`).
///
/// Flutter builds the full request — URL, method, params, headers, Keeta
/// `sig`, bearer tokens — and the backend only performs the HTTP call.
library;

export 'auth/auth_token.dart';
export 'common/delivery_platform.dart';
export 'common/http_method.dart';
export 'common/platform_api_exception.dart';
export 'common/platform_endpoint.dart';
export 'config/platform_credentials.dart';
export 'config/platform_credentials_store.dart';
export 'hungerstation/hs_api.dart';
export 'hungerstation/hs_endpoints.dart';
export 'hungerstation/hs_types.dart';
export 'keeta/keeta_api.dart';
export 'keeta/keeta_endpoints.dart';
export 'keeta/keeta_menu_api.dart';
export 'keeta/keeta_orders_api.dart';
export 'keeta/keeta_response.dart';
export 'keeta/keeta_shop_api.dart';
export 'keeta/keeta_types.dart';
export 'keeta/keeta_webhook.dart';
export 'platform_apis.dart';
