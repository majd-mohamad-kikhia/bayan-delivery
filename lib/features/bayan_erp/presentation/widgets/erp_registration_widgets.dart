import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/locale_context.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/platform_colors.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../products/data/erp_product_adapter.dart';
import '../../../products/data/models/product_record.dart';
import '../../../products/data/platform_reconcile.dart';
import '../../../products/data/repositories/product_publish_repository.dart';
import '../../../products/presentation/cubit/product_registry_cubit.dart';
import '../../../products/presentation/widgets/bulk_publish_dialog.dart';
import '../../data/models/erp_product_model.dart';
import '../utils/erp_formatters.dart';
import '../../../products/data/models/product_model.dart';

/// Which products the list shows, by where they are registered.
enum ErpRegistrationFilter {
  all,

  /// Missing from at least one platform.
  needsAdding,

  /// On every platform.
  registered;

  bool matches(ProductRegistryState registry, ErpProductModel product) =>
      switch (this) {
        all => true,
        needsAdding => !_onAll(registry, product),
        registered => _onAll(registry, product),
      };

  static bool _onAll(ProductRegistryState registry, ErpProductModel product) =>
      registry.isOnAll(
        '${product.id}',
        ProductPublishRepository.supportedPlatforms,
      );
}

/// One small pill per platform: filled when the product is there, a dashed
/// grey outline when it is not. Rebuilds only when this product's record
/// changes.
class ErpRegistrationBadges extends StatelessWidget {
  const ErpRegistrationBadges({super.key, required this.productId});

  final int productId;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      ProductRegistryCubit,
      ProductRegistryState,
      ProductRecord?
    >(
      selector: (state) => state.recordOf('$productId'),
      builder: (context, record) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final platform in ProductPublishRepository.supportedPlatforms)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 6),
              child: _PlatformPill(
                platform: platform,
                registered: record?.numFor(platform) != null,
              ),
            ),
        ],
      ),
    );
  }
}

class _PlatformPill extends StatelessWidget {
  const _PlatformPill({required this.platform, required this.registered});

  final String platform;
  final bool registered;

  @override
  Widget build(BuildContext context) {
    final color = PlatformColors.of(platform);
    final name = context.commonStrings.platformName(platform);
    return Tooltip(
      message: registered ? '$name: registered' : '$name: not registered',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: registered ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: registered ? color : AppTheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              registered ? Icons.check_rounded : Icons.add_rounded,
              size: 12,
              color: registered ? Colors.white : AppTheme.textMuted,
            ),
            const SizedBox(width: 3),
            Text(
              platform == 'keeta' ? 'Keeta' : 'HS',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: registered ? Colors.white : AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Filter chips with counts, the bulk "add missing" action and the
/// "check platforms" sync.
class ErpRegistrationBar extends StatefulWidget {
  const ErpRegistrationBar({
    super.key,
    required this.filter,
    required this.onFilterChanged,
    required this.products,
  });

  final ErpRegistrationFilter filter;
  final ValueChanged<ErpRegistrationFilter> onFilterChanged;

  /// The products currently loaded (before the registration filter).
  final List<ErpProductModel> products;

  @override
  State<ErpRegistrationBar> createState() => _ErpRegistrationBarState();
}

class _ErpRegistrationBarState extends State<ErpRegistrationBar> {
  bool _syncing = false;

  Future<void> _sync() => _checkPlatforms();

  /// Asks every platform what it already lists and records it. Returns false
  /// when a platform could not be reached (its answer is then unknown).
  Future<bool> _checkPlatforms({bool quiet = false}) async {
    setState(() => _syncing = true);
    try {
      final result = await reconcilePlatforms(context);
      if (!mounted) return result.reachable;
      if (result.reachable) {
        if (!quiet) {
          AppSnackBar.success(
            context,
            'Platforms checked',
            message:
                '${result.matched} listings matched.'
                '${result.removed > 0 ? ' ${result.removed} no longer on a platform, marked as not added.' : ''}',
          );
        }
      } else {
        AppSnackBar.error(
          context,
          title: 'Could not check every platform',
          message:
              '${result.matched} matched. Failed: ${result.failed.join(', ')}',
        );
      }
      return result.reachable;
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  /// Checks the platforms first, so products someone already added there (or
  /// on another device) are listed and skipped instead of added twice.
  Future<void> _addMissing() => reviewAndAddToPlatforms(
    context,
    universe: widget.products,
    candidates: widget.products,
    onBusy: (busy) {
      if (mounted) setState(() => _syncing = busy);
    },
  );

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProductRegistryCubit, ProductRegistryState>(
      builder: (context, registry) {
        var needs = 0;
        for (final product in widget.products) {
          if (ErpRegistrationFilter.needsAdding.matches(registry, product)) {
            needs++;
          }
        }
        final all = widget.products.length;

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _FilterChip(
                label: 'All · $all',
                selected: widget.filter == ErpRegistrationFilter.all,
                onTap: () => widget.onFilterChanged(ErpRegistrationFilter.all),
              ),
              _FilterChip(
                label: 'Needs adding · $needs',
                selected: widget.filter == ErpRegistrationFilter.needsAdding,
                onTap: () =>
                    widget.onFilterChanged(ErpRegistrationFilter.needsAdding),
              ),
              _FilterChip(
                label: 'On all platforms · ${all - needs}',
                selected: widget.filter == ErpRegistrationFilter.registered,
                onTap: () =>
                    widget.onFilterChanged(ErpRegistrationFilter.registered),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _syncing ? null : _sync,
                icon: _syncing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_rounded, size: 16),
                label: const Text('Check platforms'),
              ),
              FilledButton.icon(
                onPressed: needs == 0 || _syncing ? null : _addMissing,
                icon: const Icon(Icons.add_business_outlined, size: 16),
                label: Text('Add $needs to all platforms'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      labelStyle: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: selected ? Colors.white : AppTheme.textSecondary,
      ),
      selectedColor: AppTheme.primary,
      backgroundColor: AppTheme.surface,
      showCheckmark: false,
      side: BorderSide(color: selected ? AppTheme.primary : AppTheme.border),
    );
  }
}

/// See [reconcilePlatformsWith]: the same, reading the repository and registry
/// from the widget tree.
Future<({bool reachable, int matched, int removed, List<String> failed})> reconcilePlatforms(
  BuildContext context,
) => reconcilePlatformsWith(context.read<ProductPublishRepository>(), context.read<ProductRegistryCubit>());

/// The "Add to all platforms" flow for [candidates]: check the platforms, show
/// what will be added (grouped by category, with the add-ons that go with
/// them), and on confirmation add them with the usual progress dialog.
///
/// [universe] is the whole catalog the candidates come from: it names their
/// groups (the Keeta category) and holds the add-on group.
Future<void> reviewAndAddToPlatforms(
  BuildContext context, {
  required List<ErpProductModel> universe,
  required List<ErpProductModel> candidates,
  void Function(bool busy)? onBusy,
}) async {
  final registryCubit = context.read<ProductRegistryCubit>();
  onBusy?.call(true);
  final bool reachable;
  try {
    reachable = (await reconcilePlatforms(context)).reachable;
  } finally {
    onBusy?.call(false);
  }
  if (!context.mounted) return;

  final registry = registryCubit.state;
  final missing = <ErpProductModel>[];
  // A product that other products sit under is a group (a Keeta category),
  // not something to sell.
  final groupIds = {for (final p in universe) p.parentId};
  // Add-on groups ("إضافات") and their items become Keeta choice groups
  // attached to every product, not products of their own.
  final addOns = addOnsOf(universe);
  for (final product in candidates) {
    if (groupIds.contains(product.id) || addOns.excluded.contains(product.id)) {
      continue;
    }
    if (ErpRegistrationFilter.needsAdding.matches(registry, product)) {
      missing.add(product);
    }
  }

  final names = {for (final p in universe) p.id: p.name};
  final proceed = await showAnimatedDialog<bool>(
    context,
    builder: (_) => _AddReviewDialog(
      missing: missing,
      categories: {for (final p in missing) p.id: names[p.parentId] ?? ''},
      addOnGroups: addOns.groups,
      complete: reachable,
    ),
  );
  if (proceed != true || !context.mounted) return;
  await showBulkPublishDialog(
    context,
    products: [
      for (final product in missing)
        publishableFromErp(
          product,
          category: names[product.parentId] ?? '',
          addOnGroups: addOns.groups,
        ),
    ],
  );
}

/// What a bulk add will do, before it starts: the products that will be added,
/// grouped by the category they will land in. Products already on the
/// platforms are left out silently.
class _AddReviewDialog extends StatefulWidget {
  const _AddReviewDialog({
    required this.missing,
    required this.categories,
    required this.addOnGroups,
    required this.complete,
  });

  final List<ErpProductModel> missing;

  /// Product id → ERP group name ('' when it has none on this page).
  final Map<int, String> categories;

  /// Extras that will be attached to every added product on Keeta.
  final List<AddOnGroup> addOnGroups;

  /// False when a platform could not be checked, so "missing" may include
  /// products that are really there.
  final bool complete;

  @override
  State<_AddReviewDialog> createState() => _AddReviewDialogState();
}

class _AddReviewDialogState extends State<_AddReviewDialog> {
  String _label(ErpProductModel p) =>
      '#${p.id} · ${p.name.isEmpty ? p.shortName : p.name}';

  @override
  Widget build(BuildContext context) {
    final missing = widget.missing;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 700),
        child: Material(
          color: AppTheme.surface,
          elevation: 24,
          shadowColor: const Color(0x663D5AFE),
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
                decoration: const BoxDecoration(gradient: bulkDialogGradient),
                child: Row(
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 650),
                      curve: Curves.elasticOut,
                      builder: (_, t, child) =>
                          Transform.scale(scale: t, child: child),
                      child: Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.fact_check_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Review before adding',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Checked against Keeta and HungerStation',
                            style: TextStyle(
                              color: Color(0xD9FFFFFF),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!widget.complete)
                        _Reveal(
                          index: 0,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.coral.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  size: 18,
                                  color: AppTheme.coral,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'A platform could not be checked, so some products below '
                                    'may already be there.',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: AppTheme.coral,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      _Reveal(
                        index: 1,
                        child: _StatTile(
                          value: missing.length,
                          label: 'Will be added',
                          color: AppTheme.primary,
                          icon: Icons.add_circle_rounded,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _Reveal(
                        index: 2,
                        child: missing.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  'Nothing new to add.',
                                  style: TextStyle(color: AppTheme.textMuted),
                                ),
                              )
                            : CategoryTree(
                                groups: groupByCategory([
                                  for (final p in missing)
                                    (widget.categories[p.id] ?? '', _label(p)),
                                ], fallback: ''),
                              ),
                      ),
                      if (widget.addOnGroups.isNotEmpty &&
                          missing.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _Reveal(
                          index: 3,
                          child: _AddOnsNote(
                            groups: widget.addOnGroups,
                            products: missing.length,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: missing.isEmpty
                          ? null
                          : () => Navigator.pop(context, true),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: Text('Continue with ${missing.length}'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Which add-on groups go with the products, and their options.
class _AddOnsNote extends StatelessWidget {
  const _AddOnsNote({required this.groups, required this.products});

  final List<AddOnGroup> groups;
  final int products;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF7C4DFF);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.add_circle_outline_rounded,
                size: 16,
                color: accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Add-ons on Keeta · offered with all $products products',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final group in groups) ...[
            Text(
              group.name,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final option in group.options)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: accent.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      option.price > 0
                          ? '${option.name} · ${ErpFormatters.amount(option.price)}'
                          : option.name,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

/// Fades and slides a block in, later blocks a little after earlier ones.
class _Reveal extends StatelessWidget {
  const _Reveal({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + index * 90),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 14),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// A big number that counts up, with a label.
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    required this.color,
    required this.icon,
  });

  final int value;
  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TweenAnimationBuilder<int>(
                  tween: IntTween(begin: 0, end: value),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, _) => Text(
                    '$v',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
