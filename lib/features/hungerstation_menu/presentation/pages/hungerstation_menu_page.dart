import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/locale_context.dart';
import '../../../../core/platforms/platforms.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/platform_colors.dart';
import '../../../orders/presentation/widgets/orders_dialog_shell.dart';
import '../../../products/presentation/cubit/platform_sync_cubit.dart';
import '../../data/hs_menu_repository.dart';
import '../cubit/hs_menu_cubit.dart';

/// The HungerStation menu: what it lists, by category. Products get here from
/// the Al-Bayan sync (new ones are added, price changes are sent); this page
/// shows them and lets you change a price, hide a product, .
class HungerStationMenuPage extends StatelessWidget {
  const HungerStationMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          HsMenuCubit(HsMenuRepository(context.read<PlatformApis>()))..load(),
      child: const _MenuView(),
    );
  }
}

String _t(BuildContext context, String en, String ar) =>
    context.isArabic ? ar : en;

final _brand = PlatformColors.of('hungerstation');

class _MenuView extends StatelessWidget {
  const _MenuView();

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<HsMenuCubit, HsMenuState>(
          listenWhen: (p, c) => c.message != null && p.message != c.message,
          listener: (context, state) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(state.message!),
                  backgroundColor: AppTheme.coral,
                ),
              );
            context.read<HsMenuCubit>().messageShown();
          },
        ),
        // A sync run may have added or repriced products: show them.
        BlocListener<PlatformSyncCubit, PlatformSyncState>(
          listenWhen: (p, c) => p.lastRun != c.lastRun,
          listener: (context, _) =>
              context.read<HsMenuCubit>().load(silent: true),
        ),
      ],
      child: BlocBuilder<HsMenuCubit, HsMenuState>(
        builder: (context, state) {
          return Column(
            children: [
              _Header(loading: state.status == HsMenuStatus.loading),
              Expanded(
                child: switch (state.status) {
                  HsMenuStatus.initial || HsMenuStatus.loading => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  HsMenuStatus.failure => _Failure(error: state.error ?? ''),
                  HsMenuStatus.ready when state.menu.products.isEmpty => Center(
                    child: Text(
                      _t(
                        context,
                        'Nothing on HungerStation yet',
                        'لا يوجد شيء على هنقرستيشن بعد',
                      ),
                      style: const TextStyle(color: AppTheme.textMuted),
                    ),
                  ),
                  HsMenuStatus.ready => Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 300,
                        child: _CategoriesPanel(state: state),
                      ),
                      const VerticalDivider(width: 1, color: AppTheme.border),
                      Expanded(child: _ProductsPanel(state: state)),
                    ],
                  ),
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          Icon(Icons.restaurant_menu_rounded, size: 20, color: _brand),
          const SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t(context, 'HungerStation menu', 'قائمة هنقرستيشن'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                _t(
                  context,
                  'Filled from the Al-Bayan sync · price and availability',
                  'تُملأ من مزامنة بيان · السعر والإخفاء والعروض',
                ),
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            tooltip: _t(context, 'Refresh', 'تحديث'),
            onPressed: loading
                ? null
                : () => context.read<HsMenuCubit>().load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 40,
            color: AppTheme.textMuted,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 420,
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => context.read<HsMenuCubit>().load(),
            child: Text(_t(context, 'Try again', 'حاول مرة أخرى')),
          ),
        ],
      ),
    );
  }
}

// ── Categories ────────────────────────────────────────────────────────────────

class _CategoriesPanel extends StatelessWidget {
  const _CategoriesPanel({required this.state});

  final HsMenuState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<HsMenuCubit>();
    final categories = state.menu.categories;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(
            _t(context, 'CATEGORIES', 'التصنيفات'),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.textMuted,
              letterSpacing: context.isArabic ? 0 : 0.5,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            itemCount: categories.length,
            itemBuilder: (context, i) {
              final category = categories[i];
              final selected = category.id == state.selectedCategoryId;
              final name = category.id == HsMenuCategory.uncategorizedId
                  ? _t(context, 'Uncategorized', 'بلا تصنيف')
                  : category.name;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: selected
                        ? _brand.withValues(alpha: 0.1)
                        : AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? _brand : AppTheme.border,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => cubit.selectCategory(category.id),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: selected ? _brand : AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            '${state.menu.productsOf(category.id).length}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Products ──────────────────────────────────────────────────────────────────

class _ProductsPanel extends StatelessWidget {
  const _ProductsPanel({required this.state});

  final HsMenuState state;

  @override
  Widget build(BuildContext context) {
    final products = state.selectedProducts;
    if (products.isEmpty) {
      return Center(
        child: Text(
          _t(
            context,
            'No products in this category',
            'لا توجد منتجات بهذا التصنيف',
          ),
          style: const TextStyle(color: AppTheme.textMuted),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: products.length,
      itemBuilder: (context, i) {
        final product = products[i];
        return _ProductRow(
          product: product,
          busy: state.busySkus.contains(product.sku),
        );
      },
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.product, required this.busy});

  final HsMenuProduct product;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<HsMenuCubit>();
    final common = context.commonStrings;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: product.active ? 1 : 0.55,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                    ),
                  ),
                  Text(
                    [
                      '#${product.sku}',
                      if (product.altName.isNotEmpty) product.altName,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (busy)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            // Price: tap to change.
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: busy ? null : () => _editPrice(context, product),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _brand.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      common.money(product.price),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _brand,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.edit_rounded, size: 14, color: _brand),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Tooltip(
              message: product.active
                  ? _t(
                      context,
                      'Available — tap to hide',
                      'متاح — اضغط للإخفاء',
                    )
                  : _t(context, 'Hidden — tap to show', 'مخفي — اضغط للإظهار'),
              child: Switch(
                value: product.active,
                onChanged: busy
                    ? null
                    : (value) => cubit.setAvailable(product, value),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _editPrice(BuildContext context, HsMenuProduct product) async {
  final cubit = context.read<HsMenuCubit>();
  final price = await showOrdersDialog<double>(
    context,
    builder: (_) => _PriceDialog(product: product),
  );
  if (price != null) await cubit.setPrice(product, price);
}

class _PriceDialog extends StatefulWidget {
  const _PriceDialog({required this.product});

  final HsMenuProduct product;

  @override
  State<_PriceDialog> createState() => _PriceDialogState();
}

class _PriceDialogState extends State<_PriceDialog> {
  late final _controller = TextEditingController(
    text: widget.product.price.toStringAsFixed(2),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double? get _value {
    final v = double.tryParse(_controller.text.trim().replaceAll(',', '.'));
    return v != null && v > 0 ? v : null;
  }

  @override
  Widget build(BuildContext context) {
    return OrdersDialogShell(
      icon: Icons.sell_outlined,
      title: _t(context, 'Change price', 'تغيير السعر'),
      subtitle: widget.product.name,
      maxWidth: 440,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.commonStrings.cancel),
        ),
        const SizedBox(width: 8),
        ListenableBuilder(
          listenable: _controller,
          builder: (_, _) => FilledButton(
            onPressed: _value == null
                ? null
                : () => Navigator.pop(context, _value),
            style: dialogButtonStyle,
            child: Text(_t(context, 'Save price', 'حفظ السعر')),
          ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: _t(context, 'Price', 'السعر'),
              prefixIcon: const Icon(Icons.payments_outlined),
            ),
            onSubmitted: (_) {
              if (_value != null) Navigator.pop(context, _value);
            },
          ),
          const SizedBox(height: 10),
          Text(
            _t(
              context,
              'The next Al-Bayan price change will replace this price.',
              'أي تغيير لاحق لسعر بيان سيحلّ محل هذا السعر.',
            ),
            style: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}
