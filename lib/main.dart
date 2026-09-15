import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/constants/app_constants.dart';
import 'core/network/api_client.dart';
import 'core/storage/app_preferences.dart';
import 'core/theme/app_theme.dart';
import 'features/merchants/data/repositories/merchants_repository.dart';
import 'features/merchants/presentation/cubit/hs_outlet_cubit.dart';
import 'features/merchants/presentation/cubit/keeta_shop_cubit.dart';
import 'features/merchants/presentation/widgets/hs_outlet_panel.dart';
import 'features/merchants/presentation/widgets/keeta_shop_panel.dart';
import 'features/orders/data/repositories/orders_repository.dart';
import 'features/orders/presentation/bloc/orders_bloc.dart';
import 'features/orders/presentation/bloc/orders_event.dart';
import 'features/orders/presentation/pages/orders_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final preferences = await AppPreferences.create();
  final apiClient = ApiClient();
  final ordersRepository = OrdersRepository(apiClient);
  final merchantsRepository = MerchantsRepository(apiClient);

  runApp(
    BayanDesktopApp(
      preferences: preferences,
      ordersRepository: ordersRepository,
      merchantsRepository: merchantsRepository,
    ),
  );
}

class BayanDesktopApp extends StatelessWidget {
  const BayanDesktopApp({
    super.key,
    required this.preferences,
    required this.ordersRepository,
    required this.merchantsRepository,
  });

  final AppPreferences preferences;
  final OrdersRepository ordersRepository;
  final MerchantsRepository merchantsRepository;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => OrdersBloc(
            repository: ordersRepository,
            preferences: preferences,
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
        home: Builder(
          builder: (context) => OrdersPage(
            onMerchantsTap: () => _openMerchants(context),
          ),
        ),
      ),
    );
  }

  void _openMerchants(BuildContext context) {
    final platform = context.read<OrdersBloc>().state.platformFilter;
    final dongle = context.read<OrdersBloc>().state.dongleNumber;

    if (platform == 'hungerstation') {
      showHsOutletPanel(context, dongleNumber: dongle);
    } else {
      // keeta (and default)
      showKeetaShopPanel(context, dongleNumber: dongle);
    }
  }
}
