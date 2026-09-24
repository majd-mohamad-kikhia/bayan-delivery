import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app_shell.dart';
import 'core/constants/app_constants.dart';
import 'core/database/app_database.dart';
import 'core/network/api_client.dart';
import 'core/platforms/platform_apis.dart';
import 'core/realtime/device_poller.dart';
import 'core/storage/app_preferences.dart';
import 'core/theme/app_theme.dart';
import 'features/merchants/data/repositories/merchants_repository.dart';
import 'features/merchants/presentation/cubit/hs_outlet_cubit.dart';
import 'features/merchants/presentation/cubit/keeta_shop_cubit.dart';
import 'features/products/data/repositories/product_publish_repository.dart';
import 'features/products/data/repositories/product_records_repository.dart';
import 'features/orders/data/repositories/orders_repository.dart';
import 'features/orders/presentation/bloc/orders_bloc.dart';
import 'features/orders/presentation/bloc/orders_event.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final apiClient = ApiClient();
  final ordersRepository = OrdersRepository(apiClient);
  final merchantsRepository = MerchantsRepository(apiClient);
  // Independent startup work runs together, not one after another.
  final (preferences, platformApis, database) = await (
    AppPreferences.create(),
    PlatformApis.create(apiClient: apiClient),
    AppDatabase.open(),
  ).wait;
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
      merchantsRepository: merchantsRepository,
      platformApis: platformApis,
      devicePoller: devicePoller,
      productRecords: ProductRecordsRepository(database.db),
    ),
  );
}

class BayanDesktopApp extends StatelessWidget {
  const BayanDesktopApp({
    super.key,
    required this.preferences,
    required this.ordersRepository,
    required this.merchantsRepository,
    required this.platformApis,
    required this.devicePoller,
    required this.productRecords,
  });

  final AppPreferences preferences;
  final OrdersRepository ordersRepository;
  final MerchantsRepository merchantsRepository;
  final PlatformApis platformApis;
  final DevicePoller devicePoller;
  final ProductRecordsRepository productRecords;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
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
          BlocProvider(
            create: (_) => OrdersBloc(
              repository: ordersRepository,
              preferences: preferences,
              devicePoller: devicePoller,
            )..add(const OrdersRequested()),
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
        child: MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: const AppShell(),
        ),
      ),
    );
  }
}
