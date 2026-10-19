import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_shell.dart';
import 'core/constants/app_constants.dart';
import 'core/database/app_database.dart';
import 'core/localization/app_language.dart';
import 'core/localization/locale_context.dart';
import 'core/localization/locale_cubit.dart';
import 'core/network/api_client.dart';
import 'core/network/bayan_erp_client.dart';
import 'core/platforms/platform_apis.dart';
import 'core/realtime/device_poller.dart';
import 'core/storage/app_preferences.dart';
import 'core/theme/app_theme.dart';
import 'features/bayan_erp/data/datasources/bayan_erp_datasource.dart';
import 'features/bayan_erp/data/repositories/bayan_erp_repository.dart';
import 'features/reports/data/reports_repository.dart';
import 'features/bayan_erp/data/models/erp_product_model.dart';
import 'features/keeta_menu/data/keeta_menu_repository.dart';
import 'features/products/data/hungerstation_price_push.dart';
import 'features/bayan_orders/data/bayan_order_sender.dart';
import 'features/bayan_orders/data/bayan_orders_repository.dart';
import 'features/bayan_orders/presentation/bayan_orders_cubit.dart';
import 'features/products/data/platform_sync_service.dart';
import 'features/products/data/repositories/product_sync_repository.dart';
import 'features/products/data/repositories/product_publish_repository.dart';
import 'features/products/presentation/cubit/auto_publisher.dart';
import 'features/products/presentation/cubit/platform_sync_cubit.dart';

import 'features/bayan_erp/presentation/bloc/bayan_erp_bloc.dart';
import 'features/bayan_erp/presentation/bloc/bayan_erp_event.dart';
import 'features/merchants/data/repositories/merchants_repository.dart';
import 'features/merchants/presentation/cubit/hs_outlet_cubit.dart';
import 'features/merchants/presentation/cubit/keeta_shop_cubit.dart';
import 'features/products/presentation/cubit/product_registry_cubit.dart';
import 'features/products/data/repositories/product_records_repository.dart';
import 'features/orders/data/datasources/orders_local_datasource.dart';
import 'features/orders/data/repositories/orders_repository.dart';
import 'features/orders/presentation/bloc/orders_bloc.dart';
import 'features/orders/presentation/bloc/orders_event.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final apiClient = ApiClient();
  final merchantsRepository = MerchantsRepository(apiClient);
  final bayanErpClient = BayanErpClient();
  final bayanErpRepository = BayanErpRepository(
    BayanErpDatasource(bayanErpClient),
  );
  // Independent startup work runs together, not one after another.
  final (preferences, platformApis, database) = await (
    AppPreferences.create(),
    PlatformApis.create(apiClient: apiClient),
    AppDatabase.open(),
  ).wait;
  final ordersRepository = OrdersRepository(
    apiClient,
    OrdersLocalDatasource(database.db),
  );
  final productSync = ProductSyncRepository(database.db);
  final bayanOrderSender = BayanOrderSender(
    post: bayanErpClient.post,
    repository: BayanOrdersRepository(database.db),
    preferences: preferences,
  );
  // Long-polls the backend for this device's queue for the app's lifetime;
  // the dongle number is the device id.
  final devicePoller = DevicePoller(
    baseUrl: AppConstants.devicePollBaseUrl,
    deviceId: preferences.dongleNumber,
    pollTimeout: AppConstants.devicePollHold,
  )..start();

  runApp(
    BayanDesktopApp(
      preferences: preferences,
      ordersRepository: ordersRepository,
      reportsRepository: ReportsRepository(apiClient),
      merchantsRepository: merchantsRepository,
      bayanErpRepository: bayanErpRepository,
      platformApis: platformApis,
      devicePoller: devicePoller,
      productRecords: ProductRecordsRepository(database.db),
      productSync: productSync,
      bayanOrderSender: bayanOrderSender,
    ),
  );
}

class BayanDesktopApp extends StatelessWidget {
  const BayanDesktopApp({
    super.key,
    required this.preferences,
    required this.ordersRepository,
    required this.reportsRepository,
    required this.merchantsRepository,
    required this.bayanErpRepository,
    required this.platformApis,
    required this.devicePoller,
    required this.productRecords,
    required this.productSync,
    required this.bayanOrderSender,
  });

  final AppPreferences preferences;
  final OrdersRepository ordersRepository;
  final ReportsRepository reportsRepository;
  final MerchantsRepository merchantsRepository;
  final BayanErpRepository bayanErpRepository;
  final PlatformApis platformApis;
  final DevicePoller devicePoller;
  final ProductRecordsRepository productRecords;
  final ProductSyncRepository productSync;
  final BayanOrderSender bayanOrderSender;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: preferences),
        RepositoryProvider.value(value: ordersRepository),
        RepositoryProvider.value(value: reportsRepository),
        RepositoryProvider.value(value: bayanErpRepository),
        RepositoryProvider.value(value: platformApis),
        RepositoryProvider.value(value: devicePoller),
        RepositoryProvider.value(value: productRecords),
        RepositoryProvider(
          create: (_) => ProductPublishRepository(
            apis: platformApis,
            preferences: preferences,
          ),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => LocaleCubit(preferences)),
          BlocProvider(
            create: (_) =>
                ProductRegistryCubit(productRecords, productSync)..load(),
          ),
          // Keeps Keeta and HungerStation in step with Al-Bayan: prices (and
          // names, on Keeta) changed there are pushed to the platforms.
          BlocProvider(
            lazy: false,
            create: (context) {
              final keetaMenu = KeetaMenuRepository(
                apis: platformApis,
                preferences: preferences,
              );
              return PlatformSyncCubit(
                autoPublisher: AutoPublisher(
                  repository: context.read<ProductPublishRepository>(),
                  registry: context.read<ProductRegistryCubit>(),
                  preferences: preferences,
                ),
                autoAdd: preferences.autoAddNewProducts,
                onAutoAddChanged: preferences.setAutoAddNewProducts,
                PlatformSyncService(
                  loadCatalog: () async {
                    const page = 500;
                    final all = <ErpProductModel>[];
                    for (var offset = 0; ; offset += page) {
                      final chunk = await bayanErpRepository.getProducts(
                        offset: offset,
                        limit: page,
                      );
                      all.addAll(chunk);
                      if (chunk.length < page) return all;
                    }
                  },
                  records: productRecords,
                  state: productSync,
                  pushKeeta: keetaMenu.updateMany,
                  pushHungerStation: (updates) =>
                      pushHungerStationPrices(platformApis, updates),
                ),
              )..start();
            },
          ),
          BlocProvider(
            create: (_) => BayanOrdersCubit(bayanOrderSender)..load(),
          ),
          BlocProvider(
            create: (_) => OrdersBloc(
              repository: ordersRepository,
              preferences: preferences,
              devicePoller: devicePoller,
            )..add(const OrdersRequested()),
          ),
          BlocProvider(
            create: (_) => BayanErpBloc(
              repository: bayanErpRepository,
              preferences: preferences,
            )..add(const BayanErpRefreshRequested()),
          ),
          BlocProvider(
            create: (_) => KeetaShopCubit(
              repository: merchantsRepository,
              preferences: preferences,
            ),
          ),
          BlocProvider(
            create: (_) => HsOutletCubit(
              repository: merchantsRepository,
              preferences: preferences,
            ),
          ),
        ],
        child: const _LocalizedApp(),
      ),
    );
  }
}

/// Only this subtree rebuilds when the language changes; blocs and
/// repositories above it are untouched.
class _LocalizedApp extends StatelessWidget {
  const _LocalizedApp();

  static const _delegates = <LocalizationsDelegate<dynamic>>[
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LocaleCubit>().state;
    return MaterialApp(
      onGenerateTitle: (context) => context.commonStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: language.locale,
      supportedLocales: AppLanguage.supportedLocales,
      localizationsDelegates: _delegates,
      home: const AppShell(),
    );
  }
}
