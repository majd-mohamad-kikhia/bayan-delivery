import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/locale_context.dart';
import '../../../../core/platforms/platforms.dart';
import '../../../../core/storage/app_preferences.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../orders/presentation/widgets/orders_dialog_shell.dart';
import '../../../products/presentation/cubit/platform_sync_cubit.dart';
import '../../data/keeta_menu_repository.dart';
import '../cubit/keeta_menu_cubit.dart';

/// Edit the live Keeta menu: product name / price / availability / delete,
/// and the order of categories and products.
class KeetaMenuPage extends StatelessWidget {
  const KeetaMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => KeetaMenuCubit(
        KeetaMenuRepository(
          apis: context.read<PlatformApis>(),
          preferences: context.read<AppPreferences>(),
        ),
      )..load(),
      // A sync run may have added or repriced products: show them.
      child: BlocListener<PlatformSyncCubit, PlatformSyncState>(
        listenWhen: (p, c) => p.lastRun != c.lastRun,
        listener: (context, _) =>
            context.read<KeetaMenuCubit>().load(silent: true),
        child: const _MenuView(),
      ),
    );
  }
}

String _t(BuildContext context, String en, String ar) =>
    context.isArabic ? ar : en;

class _MenuView extends StatelessWidget {
  const _MenuView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<KeetaMenuCubit, KeetaMenuState>(
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
        context.read<KeetaMenuCubit>().messageShown();
      },
      builder: (context, state) {
        return Column(
          children: [
            _Header(loading: state.status == KeetaMenuStatus.loading),
            Expanded(
              child: switch (state.status) {
                KeetaMenuStatus.initial || KeetaMenuStatus.loading =>
                  const Center(child: CircularProgressIndicator()),
                KeetaMenuStatus.failure => _Failure(error: state.error ?? ''),
                KeetaMenuStatus.ready when state.menu.categories.isEmpty =>
                  Center(
                    child: Text(
                      _t(
                        context,
                        'Nothing on Keeta yet',
                        'لا يوجد شيء على كيتا بعد',
                      ),
                      style: const TextStyle(color: AppTheme.textMuted),
                    ),
                  ),
                KeetaMenuStatus.ready => Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 300, child: _CategoriesPanel(state: state)),
                    const VerticalDivider(width: 1, color: AppTheme.border),
                    Expanded(child: _ProductsPanel(state: state)),
                  ],
                ),
              },
            ),
          ],
        );
      },
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
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.restaurant_menu_rounded,
            size: 20,
            color: AppTheme.primary,
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t(context, 'Keeta menu', 'قائمة كيتا'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                _t(
                  context,
                  'Edit, price, hide and reorder',
                  'تعديل وتسعير وإخفاء وترتيب',
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
                : () => context.read<KeetaMenuCubit>().load(),
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
            onPressed: () => context.read<KeetaMenuCubit>().load(),
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

  final KeetaMenuState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<KeetaMenuCubit>();
    final categories = state.menu.categories;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(
            _t(
              context,
              'CATEGORIES · drag to reorder',
              'التصنيفات · اسحب للترتيب',
            ),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.textMuted,
              letterSpacing: context.isArabic ? 0 : 0.5,
            ),
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            itemCount: categories.length,
            onReorder: cubit.moveCategory,
            itemBuilder: (context, i) {
              final category = categories[i];
              final selected = category.id == state.selectedCategoryId;
              return Padding(
                key: ValueKey(category.id),
                padding: const EdgeInsets.only(bottom: 6),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.primary.withValues(alpha: 0.1)
                        : AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? AppTheme.primary : AppTheme.border,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => cubit.selectCategory(category.id),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
                      child: Row(
                        children: [
                          ReorderableDragStartListener(
                            index: i,
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(
                                Icons.drag_indicator_rounded,
                                size: 20,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              category.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: selected
                                    ? AppTheme.primary
                                    : AppTheme.textPrimary,
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
                          PopupMenuButton<String>(
                            tooltip: '',
                            icon: const Icon(Icons.more_vert_rounded, size: 18),
                            onSelected: (value) async {
                              if (value == 'rename') {
                                final name = await _askName(
                                  context,
                                  category.name,
                                );
                                if (name != null) {
                                  await cubit.renameCategory(category, name);
                                }
                              } else {
                                final ok = await _confirm(
                                  context,
                                  title: _t(
                                    context,
                                    'Delete category?',
                                    'حذف التصنيف؟',
                                  ),
                                  body: _t(
                                    context,
                                    '"${category.name}" must be empty; Keeta refuses otherwise.',
                                    '"${category.name}" يجب أن يكون فارغاً، وإلا ترفض كيتا الحذف.',
                                  ),
                                  confirm: _t(context, 'Delete', 'حذف'),
                                );
                                if (ok) await cubit.deleteCategory(category);
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'rename',
                                child: Text(
                                  _t(context, 'Rename', 'إعادة تسمية'),
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(_t(context, 'Delete', 'حذف')),
                              ),
                            ],
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

  final KeetaMenuState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<KeetaMenuCubit>();
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
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.all(20),
      itemCount: products.length,
      onReorder: cubit.moveProduct,
      itemBuilder: (context, i) {
        final product = products[i];
        return _ProductRow(
          key: ValueKey(product.id),
          index: i,
          product: product,
          busy: state.busyIds.contains(product.id),
        );
      },
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    super.key,
    required this.index,
    required this.product,
    required this.busy,
  });

  final int index;
  final MenuProduct product;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<KeetaMenuCubit>();
    final common = context.commonStrings;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: product.available ? 1 : 0.55,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(
                  Icons.drag_indicator_rounded,
                  size: 20,
                  color: AppTheme.textMuted,
                ),
              ),
            ),
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
                  if (product.description.isNotEmpty)
                    Text(
                      product.description,
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
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      common.money(product.price),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.edit_rounded,
                      size: 14,
                      color: AppTheme.primary,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Tooltip(
              message: product.available
                  ? _t(
                      context,
                      'Available — tap to hide',
                      'متاح — اضغط للإخفاء',
                    )
                  : _t(context, 'Hidden — tap to show', 'مخفي — اضغط للإظهار'),
              child: Switch(
                value: product.available,
                onChanged: busy
                    ? null
                    : (value) => cubit.setAvailable(product, value),
              ),
            ),
            IconButton(
              tooltip: _t(context, 'Edit', 'تعديل'),
              onPressed: busy ? null : () => _editProduct(context, product),
              icon: const Icon(Icons.tune_rounded),
            ),
            IconButton(
              tooltip: _t(context, 'Delete', 'حذف'),
              onPressed: busy
                  ? null
                  : () async {
                      final ok = await _confirm(
                        context,
                        title: _t(context, 'Delete product?', 'حذف المنتج؟'),
                        body: _t(
                          context,
                          '"${product.name}" will be removed from Keeta.',
                          '"${product.name}" سيُحذف من كيتا.',
                        ),
                        confirm: _t(context, 'Delete', 'حذف'),
                      );
                      if (ok) await cubit.deleteProduct(product);
                    },
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: AppTheme.coral,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Dialogs ───────────────────────────────────────────────────────────────────

Future<void> _editPrice(BuildContext context, MenuProduct product) async {
  final cubit = context.read<KeetaMenuCubit>();
  final price = await showOrdersDialog<double>(
    context,
    builder: (_) => _PriceDialog(product: product),
  );
  if (price != null) await cubit.updateProduct(product, price: price);
}

class _PriceDialog extends StatefulWidget {
  const _PriceDialog({required this.product});

  final MenuProduct product;

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
      child: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textDirection: TextDirection.ltr,
        decoration: InputDecoration(
          labelText: _t(context, 'Delivery price', 'سعر التوصيل'),
          prefixIcon: const Icon(Icons.payments_outlined),
        ),
        onSubmitted: (_) {
          if (_value != null) Navigator.pop(context, _value);
        },
      ),
    );
  }
}

Future<void> _editProduct(BuildContext context, MenuProduct product) async {
  final cubit = context.read<KeetaMenuCubit>();
  final result =
      await showOrdersDialog<({String name, String description, double price})>(
        context,
        builder: (_) => _ProductDialog(product: product),
      );
  if (result != null) {
    await cubit.updateProduct(
      product,
      name: result.name == product.name ? null : result.name,
      description: result.description == product.description
          ? null
          : result.description,
      price: result.price == product.price ? null : result.price,
    );
  }
}

class _ProductDialog extends StatefulWidget {
  const _ProductDialog({required this.product});

  final MenuProduct product;

  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  late final _name = TextEditingController(text: widget.product.name);
  late final _description = TextEditingController(
    text: widget.product.description,
  );
  late final _price = TextEditingController(
    text: widget.product.price.toStringAsFixed(2),
  );

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    super.dispose();
  }

  double? get _priceValue {
    final v = double.tryParse(_price.text.trim().replaceAll(',', '.'));
    return v != null && v > 0 ? v : null;
  }

  bool get _valid => _name.text.trim().isNotEmpty && _priceValue != null;

  @override
  Widget build(BuildContext context) {
    return OrdersDialogShell(
      icon: Icons.tune_rounded,
      title: _t(context, 'Edit product', 'تعديل المنتج'),
      subtitle: widget.product.name,
      maxWidth: 520,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.commonStrings.cancel),
        ),
        const SizedBox(width: 8),
        ListenableBuilder(
          listenable: Listenable.merge([_name, _price]),
          builder: (_, _) => FilledButton(
            onPressed: _valid
                ? () => Navigator.pop(context, (
                    name: _name.text.trim(),
                    description: _description.text.trim(),
                    price: _priceValue!,
                  ))
                : null,
            style: dialogButtonStyle,
            child: Text(_t(context, 'Save', 'حفظ')),
          ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _name,
            decoration: InputDecoration(
              labelText: _t(context, 'Name', 'الاسم'),
              prefixIcon: const Icon(Icons.label_outline_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: _t(context, 'Description', 'الوصف'),
              prefixIcon: const Icon(Icons.notes_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: _t(context, 'Delivery price', 'سعر التوصيل'),
              prefixIcon: const Icon(Icons.payments_outlined),
            ),
          ),
        ],
      ),
    );
  }
}

Future<String?> _askName(BuildContext context, String current) {
  return showOrdersDialog<String>(
    context,
    builder: (_) => _NameDialog(current: current),
  );
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.current});

  final String current;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _controller = TextEditingController(text: widget.current);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OrdersDialogShell(
      icon: Icons.drive_file_rename_outline_rounded,
      title: _t(context, 'Rename category', 'إعادة تسمية التصنيف'),
      subtitle: widget.current,
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
            onPressed: _controller.text.trim().isEmpty
                ? null
                : () => Navigator.pop(context, _controller.text.trim()),
            style: dialogButtonStyle,
            child: Text(_t(context, 'Save', 'حفظ')),
          ),
        ),
      ],
      child: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: _t(context, 'Name', 'الاسم'),
          prefixIcon: const Icon(Icons.label_outline_rounded),
        ),
      ),
    );
  }
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String body,
  required String confirm,
}) async {
  final ok = await showOrdersDialog<bool>(
    context,
    builder: (ctx) => OrdersDialogShell(
      icon: Icons.warning_amber_rounded,
      title: title,
      subtitle: '',
      maxWidth: 440,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(ctx.commonStrings.cancel),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: dialogButtonStyle.copyWith(
            backgroundColor: const WidgetStatePropertyAll(AppTheme.coral),
          ),
          child: Text(confirm),
        ),
      ],
      child: Text(body, style: const TextStyle(fontSize: 14, height: 1.5)),
    ),
  );
  return ok ?? false;
}
