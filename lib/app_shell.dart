import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/navigation/app_section.dart';
import 'features/merchants/presentation/widgets/hs_outlet_panel.dart';
import 'features/merchants/presentation/widgets/keeta_shop_panel.dart';
import 'features/orders/presentation/bloc/orders_bloc.dart';
import 'features/orders/presentation/pages/orders_page.dart';
import 'features/orders/presentation/widgets/app_sidebar.dart';
import 'features/products/presentation/pages/products_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppSection _section = AppSection.orders;

  void _openMerchants() {
    final platform = context.read<OrdersBloc>().state.platformFilter;
    final dongle = context.read<OrdersBloc>().state.dongleNumber;

    if (platform == 'hungerstation') {
      showHsOutletPanel(context, dongleNumber: dongle);
    } else {
      showKeetaShopPanel(context, dongleNumber: dongle);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          AppSidebar(
            section: _section,
            onSectionChanged: (section) => setState(() => _section = section),
            onMerchantsTap: _openMerchants,
          ),
          Expanded(
            child: switch (_section) {
              AppSection.orders => const OrdersPage(),
              AppSection.products => const ProductsPage(),
            },
          ),
        ],
      ),
    );
  }
}
