import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/navigation/app_section.dart';
import 'core/storage/app_preferences.dart';
import 'features/bayan_erp/data/models/erp_product_model.dart';
import 'features/bayan_erp/presentation/screens/bayan_erp_screen.dart';
import 'features/menus/presentation/pages/menus_page.dart';
import 'features/merchants/presentation/widgets/hs_outlet_panel.dart';
import 'features/reports/presentation/pages/reports_page.dart';
import 'features/merchants/presentation/widgets/keeta_shop_panel.dart';
import 'features/orders/presentation/bloc/orders_bloc.dart';
import 'features/orders/presentation/pages/orders_page.dart';
import 'features/orders/presentation/widgets/app_sidebar.dart';
import 'features/products/data/erp_product_adapter.dart';
import 'features/products/data/models/product_model.dart';
import 'features/products/presentation/pages/products_page.dart';
import 'features/products/presentation/pages/publish_product_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppSection _section = AppSection.orders;
  late bool _sidebarCollapsed;

  @override
  void initState() {
    super.initState();
    _sidebarCollapsed = context.read<AppPreferences>().sidebarCollapsed;
  }

  void _toggleSidebar() {
    setState(() => _sidebarCollapsed = !_sidebarCollapsed);
    context.read<AppPreferences>().setSidebarCollapsed(_sidebarCollapsed);
  }

  /// ERP product currently open in the publish-to-platforms page.
  ProductModel? _erpPublishing;

  void _openMerchants() {
    final platform = context.read<OrdersBloc>().state.platformFilter;
    final dongle = context.read<OrdersBloc>().state.dongleNumber;

    if (platform == 'hungerstation') {
      showHsOutletPanel(context, dongleNumber: dongle);
    } else {
      showKeetaShopPanel(context, dongleNumber: dongle);
    }
  }

  void _publishErpProduct(ErpProductModel product) =>
      setState(() => _erpPublishing = publishableFromErp(product));

  void _closeErpPublish() => setState(() => _erpPublishing = null);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          AppSidebar(
            section: _section,
            onSectionChanged: (section) => setState(() => _section = section),
            onMerchantsTap: _openMerchants,
            collapsed: _sidebarCollapsed,
            onToggleCollapsed: _toggleSidebar,
          ),
          Expanded(
            child: switch (_section) {
              AppSection.orders => const OrdersPage(),
              AppSection.products => const ProductsPage(),
              AppSection.inventory => _buildInventory(),
              AppSection.menus => const MenusPage(),
              AppSection.reports => const ReportsPage(),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInventory() {
    final publishing = _erpPublishing;
    return Stack(
      children: [
        // Kept mounted so the list's page, filters, and view mode survive.
        Offstage(
          offstage: publishing != null,
          child: BayanErpScreen(onAddToPlatforms: _publishErpProduct),
        ),
        if (publishing != null)
          PublishProductPage(
            key: ValueKey(publishing.id),
            product: publishing,
            onClose: _closeErpPublish,
          ),
      ],
    );
  }
}
