import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/locale_context.dart';
import '../../../../core/storage/app_preferences.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/platform_colors.dart';
import '../../data/models/product_model.dart';
import '../../data/repositories/product_publish_repository.dart';
import '../cubit/bulk_publish_cubit.dart';
import '../cubit/product_registry_cubit.dart';
import '../l10n/products_strings.dart';

const _gradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF3D5AFE), Color(0xFF7C4DFF)],
);

/// Gradient shared by the bulk-add dialogs.
const bulkDialogGradient = _gradient;

/// The scale + slide + fade entrance used by the bulk-add dialogs.
Future<T?> showAnimatedDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool barrierDismissible = false,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'animated-dialog',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 340),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
      );
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.05),
            end: Offset.zero,
          ).animate(curved),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
            child: child,
          ),
        ),
      );
    },
    pageBuilder: (context, _, _) => builder(context),
  );
}

/// Asks for the few values a quick add can't take from the ERP (categories,
/// barcode), then adds every product to the platforms it is still missing
/// from, with live, animated progress and a per-product failure list.
Future<void> showBulkPublishDialog(
  BuildContext context, {
  required List<ProductModel> products,
}) {
  final registry = context.read<ProductRegistryCubit>();
  final repository = context.read<ProductPublishRepository>();
  final preferences = context.read<AppPreferences>();
  return showAnimatedDialog<void>(
    context,
    builder: (_) => BlocProvider(
      create: (_) =>
          BulkPublishCubit(repository: repository, registry: registry),
      child: _BulkPublishDialog(products: products, preferences: preferences),
    ),
  );
}

class _BulkPublishDialog extends StatefulWidget {
  const _BulkPublishDialog({required this.products, required this.preferences});

  final List<ProductModel> products;
  final AppPreferences preferences;

  @override
  State<_BulkPublishDialog> createState() => _BulkPublishDialogState();
}

class _BulkPublishDialogState extends State<_BulkPublishDialog> {
  late final TextEditingController _keeta = TextEditingController(
    text: widget.preferences.bulkKeetaCategory,
  );
  late final TextEditingController _hs = TextEditingController(
    text: widget.preferences.bulkHsCategory,
  );
  late bool _barcodeFromSku = widget.preferences.bulkBarcodeFromSku;

  @override
  void dispose() {
    _keeta.dispose();
    _hs.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final defaults = BulkDefaults(
      keetaCategory: _keeta.text.trim(),
      hungerStationCategory: _hs.text.trim(),
      barcodeFromSku: _barcodeFromSku,
    );
    await widget.preferences.setBulkDefaults(
      keetaCategory: defaults.keetaCategory,
      hsCategory: defaults.hungerStationCategory,
      barcodeFromSku: defaults.barcodeFromSku,
    );
    if (!mounted) return;
    await context.read<BulkPublishCubit>().run(widget.products, defaults);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 700),
        child: Material(
          color: AppTheme.surface,
          elevation: 24,
          shadowColor: const Color(0x663D5AFE),
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: BlocBuilder<BulkPublishCubit, BulkPublishState>(
            builder: (context, state) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Header(state: state, total: widget.products.length),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        switchInCurve: Curves.easeOutCubic,
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween(
                              begin: const Offset(0.06, 0),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                        child: state.status == BulkStatus.idle
                            ? _Form(
                                key: const ValueKey('form'),
                                count: widget.products.length,
                                products: widget.products,
                                keeta: _keeta,
                                keetaOptional: widget.products.every(
                                  (p) => p.category.trim().isNotEmpty,
                                ),
                                hs: _hs,
                                barcodeFromSku: _barcodeFromSku,
                                onBarcodeChanged: (v) =>
                                    setState(() => _barcodeFromSku = v),
                              )
                            : _Progress(
                                key: const ValueKey('progress'),
                                state: state,
                              ),
                      ),
                    ),
                  ),
                ),
                _Actions(
                  state: state,
                  keeta: _keeta,
                  count: widget.products.length,
                  keetaOptional: widget.products.every(
                    (p) => p.category.trim().isNotEmpty,
                  ),
                  onStart: _start,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.state, required this.total});

  final BulkPublishState state;
  final int total;

  @override
  Widget build(BuildContext context) {
    final done = state.status == BulkStatus.done;
    final running = state.status == BulkStatus.running;
    final title = done
        ? (state.failures.isEmpty ? 'All done' : 'Finished with issues')
        : running
        ? 'Adding products…'
        : 'Add to all platforms';
    final subtitle = running || done
        ? '${state.done} of ${state.total} products processed'
        : '$total ${total == 1 ? 'product' : 'products'} ready to add';

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
      decoration: const BoxDecoration(gradient: _gradient),
      child: Row(
        children: [
          _HeaderIcon(
            running: running,
            done: done,
            hasFailures: state.failures.isNotEmpty,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: Text(
                    title,
                    key: ValueKey(title),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: Text(
                    subtitle,
                    key: ValueKey(subtitle),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const _PlatformChip(platform: 'keeta', label: 'Keeta'),
          const SizedBox(width: 8),
          const _PlatformChip(
            platform: 'hungerstation',
            label: 'HungerStation',
          ),
        ],
      ),
    );
  }
}

class _HeaderIcon extends StatefulWidget {
  const _HeaderIcon({
    required this.running,
    required this.done,
    required this.hasFailures,
  });

  final bool running;
  final bool done;
  final bool hasFailures;

  @override
  State<_HeaderIcon> createState() => _HeaderIconState();
}

class _HeaderIconState extends State<_HeaderIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_HeaderIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  /// Pulses only while the run is in progress.
  void _sync() {
    if (widget.running) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icon = widget.done
        ? (widget.hasFailures
              ? Icons.warning_amber_rounded
              : Icons.check_circle_rounded)
        : widget.running
        ? Icons.cloud_upload_rounded
        : Icons.add_business_rounded;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) => Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.35 * _pulse.value),
              blurRadius: 18 * _pulse.value,
              spreadRadius: 4 * _pulse.value,
            ),
          ],
        ),
        child: child,
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        transitionBuilder: (child, animation) => ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.elasticOut),
          child: child,
        ),
        child: Icon(icon, key: ValueKey(icon), color: Colors.white, size: 28),
      ),
    );
  }
}

class _PlatformChip extends StatelessWidget {
  const _PlatformChip({required this.platform, required this.label});

  final String platform;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: PlatformColors.of(platform),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: PlatformColors.of(platform),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Form step ───────────────────────────────────────────────────────────────

class _Form extends StatelessWidget {
  const _Form({
    super.key,
    required this.count,
    required this.products,
    required this.keeta,
    required this.keetaOptional,
    required this.hs,
    required this.barcodeFromSku,
    required this.onBarcodeChanged,
  });

  final int count;
  final List<ProductModel> products;
  final TextEditingController keeta;

  /// Every product brings its own category, so this one is only a fallback.
  final bool keetaOptional;
  final TextEditingController hs;
  final bool barcodeFromSku;
  final ValueChanged<bool> onBarcodeChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'A platform a product is already on is skipped. Fill in what the ERP '
          "doesn't have:",
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        _StaggeredIn(
          index: 0,
          child: _Field(
            controller: keeta,
            label: keetaOptional
                ? 'Keeta category (fallback)'
                : 'Keeta category *',
            helper: keetaOptional
                ? 'Each product goes in its ERP group category (created on Keeta if missing).'
                : 'Created on Keeta if missing. Products in an ERP group use the group name instead.',
            icon: Icons.category_outlined,
            color: PlatformColors.of('keeta'),
          ),
        ),
        const SizedBox(height: 14),
        _StaggeredIn(
          index: 1,
          child: ListenableBuilder(
            listenable: keeta,
            builder: (_, _) => CategoryTree(
              groups: groupByCategory([
                for (final p in products)
                  (p.category, p.name.isEmpty ? p.nameAr : p.name),
              ], fallback: keeta.text.trim()),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _StaggeredIn(
          index: 2,
          child: _Field(
            controller: hs,
            label: 'HungerStation category (optional)',
            helper: 'Must already exist there. Blank sends none.',
            icon: Icons.label_outline_rounded,
            color: PlatformColors.of('hungerstation'),
          ),
        ),
        const SizedBox(height: 14),
        _StaggeredIn(
          index: 3,
          child: _SwitchCard(
            value: barcodeFromSku,
            onChanged: onBarcodeChanged,
            title: 'Use the product number as barcode',
            subtitle:
                'HungerStation requires a barcode and the ERP has none. '
                'It may refuse a number that is not a real GTIN.',
          ),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.helper,
    required this.icon,
    required this.color,
  });

  final TextEditingController controller;
  final String label;
  final String helper;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: c, width: w),
    );
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        filled: true,
        fillColor: AppTheme.surfaceAlt,
        prefixIcon: Icon(icon, color: color),
        enabledBorder: border(AppTheme.border),
        focusedBorder: border(color, 2),
        border: border(AppTheme.border),
        floatingLabelStyle: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SwitchCard extends StatelessWidget {
  const _SwitchCard({
    required this.value,
    required this.onChanged,
    required this.title,
    required this.subtitle,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: BoxDecoration(
          color: value
              ? AppTheme.primary.withValues(alpha: 0.06)
              : AppTheme.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: value
                ? AppTheme.primary.withValues(alpha: 0.5)
                : AppTheme.border,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

/// Fades and slides a child in once, a little later for each [index].
class _StaggeredIn extends StatelessWidget {
  const _StaggeredIn({super.key, required this.index, required this.child});

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

// ── Progress step ───────────────────────────────────────────────────────────

class _Progress extends StatelessWidget {
  const _Progress({super.key, required this.state});

  final BulkPublishState state;

  @override
  Widget build(BuildContext context) {
    final strings = context.productsStrings;
    final common = context.commonStrings;
    final done = state.status == BulkStatus.done;
    final hasFailures = state.failures.isNotEmpty;

    return Column(
      children: [
        _Ring(
          progress: done ? 1 : state.progress,
          done: done,
          hasFailures: hasFailures,
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _Stat(
                value: state.added,
                label: 'Added',
                icon: Icons.check_circle_outline_rounded,
                color: AppTheme.success,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Stat(
                value: state.failures.length,
                label: 'Failed',
                icon: Icons.error_outline_rounded,
                color: AppTheme.coral,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Stat(
                value: state.skipped,
                label: 'Already there',
                icon: Icons.skip_next_rounded,
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ),
        if (hasFailures) ...[
          const SizedBox(height: 18),
          const Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              'Needs attention',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: AppTheme.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: state.failures.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final f = state.failures[i];
                final platform = common.platformName(f.platformId);
                return _StaggeredIn(
                  key: ValueKey('failure-$i'),
                  index: 0,
                  child: _FailureTile(
                    title: f.productName,
                    platformId: f.platformId,
                    platformName: platform,
                    message: strings.publishNotice(
                      f.outcome.notice,
                      platform,
                      f.outcome.detail,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({
    required this.progress,
    required this.done,
    required this.hasFailures,
  });

  final double progress;
  final bool done;
  final bool hasFailures;

  @override
  Widget build(BuildContext context) {
    final color = done
        ? (hasFailures ? AppTheme.warning : AppTheme.success)
        : AppTheme.primary;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: progress),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => SizedBox(
        width: 132,
        height: 132,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: value,
                strokeWidth: 11,
                strokeCap: StrokeCap.round,
                backgroundColor: color.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: CurvedAnimation(
                  parent: animation,
                  curve: Curves.elasticOut,
                ),
                child: child,
              ),
              child: done
                  ? Icon(
                      hasFailures
                          ? Icons.warning_amber_rounded
                          : Icons.check_rounded,
                      key: ValueKey(hasFailures),
                      size: 56,
                      color: color,
                    )
                  : Text(
                      '${(value * 100).round()}%',
                      key: const ValueKey('percent'),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  final int value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: animation,
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: Text(
              '$value',
              key: ValueKey(value),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FailureTile extends StatelessWidget {
  const _FailureTile({
    required this.title,
    required this.platformId,
    required this.platformName,
    required this.message,
  });

  final String title;
  final String platformId;
  final String platformName;
  final String message;

  @override
  Widget build(BuildContext context) {
    final color = PlatformColors.of(platformId);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                platformName,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            message,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFFB91C1C),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Actions ─────────────────────────────────────────────────────────────────

class _Actions extends StatelessWidget {
  const _Actions({
    required this.state,
    required this.keeta,
    required this.count,
    required this.keetaOptional,
    required this.onStart,
  });

  final BulkPublishState state;
  final TextEditingController keeta;
  final int count;
  final bool keetaOptional;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final Widget buttons;
    switch (state.status) {
      case BulkStatus.idle:
        buttons = Row(
          key: const ValueKey('idle'),
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.commonStrings.cancel),
            ),
            const SizedBox(width: 8),
            ListenableBuilder(
              listenable: keeta,
              builder: (_, _) => FilledButton.icon(
                onPressed: !keetaOptional && keeta.text.trim().isEmpty
                    ? null
                    : onStart,
                icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                label: Text(
                  'Add $count ${count == 1 ? 'product' : 'products'}',
                ),
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
            ),
          ],
        );
      case BulkStatus.running:
        buttons = Row(
          key: const ValueKey('running'),
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton.icon(
              onPressed: state.cancelled
                  ? null
                  : () => context.read<BulkPublishCubit>().cancel(),
              icon: const Icon(Icons.stop_circle_outlined, size: 18),
              label: Text(state.cancelled ? 'Stopping…' : 'Stop'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        );
      case BulkStatus.done:
        buttons = Row(
          key: const ValueKey('done'),
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.done_all_rounded, size: 18),
              label: const Text('Close'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 26,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: buttons,
      ),
    );
  }
}

// ── Category tree preview ───────────────────────────────────────────────────

/// Items grouped under their category name, in first-seen order. Items with
/// no category go under [fallback] (or "Uncategorized" when that is blank).
Map<String, List<String>> groupByCategory(
  Iterable<(String category, String name)> items, {
  required String fallback,
}) {
  final groups = <String, List<String>>{};
  for (final (category, name) in items) {
    final key = category.trim().isNotEmpty
        ? category.trim()
        : (fallback.isNotEmpty ? fallback : 'Uncategorized');
    groups.putIfAbsent(key, () => []).add(name);
  }
  return groups;
}

/// Categories as folders with their products beneath; tap a folder to
/// collapse it. Shows what Keeta's menu will look like after the add.
class CategoryTree extends StatefulWidget {
  const CategoryTree({
    super.key,
    required this.groups,
    this.accent = const Color(0xFF3D5AFE),
  });

  final Map<String, List<String>> groups;
  final Color accent;

  @override
  State<CategoryTree> createState() => _CategoryTreeState();
}

class _CategoryTreeState extends State<CategoryTree> {
  final Set<String> _collapsed = {};

  @override
  Widget build(BuildContext context) {
    final entries = widget.groups.entries.toList();
    return Container(
      decoration: BoxDecoration(
        color: widget.accent.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: widget.accent.withValues(alpha: 0.18)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_tree_outlined, size: 16, color: widget.accent),
              const SizedBox(width: 8),
              Text(
                'Keeta menu · ${entries.length} ${entries.length == 1 ? 'category' : 'categories'}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: widget.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (var i = 0; i < entries.length; i++)
                    _StaggeredIn(
                      key: ValueKey(entries[i].key),
                      index: i,
                      child: _CategoryNode(
                        name: entries[i].key,
                        items: entries[i].value,
                        accent: widget.accent,
                        expanded: !_collapsed.contains(entries[i].key),
                        onToggle: () => setState(() {
                          if (!_collapsed.remove(entries[i].key)) {
                            _collapsed.add(entries[i].key);
                          }
                        }),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryNode extends StatelessWidget {
  const _CategoryNode({
    required this.name,
    required this.items,
    required this.accent,
    required this.expanded,
    required this.onToggle,
  });

  final String name;
  final List<String> items;
  final Color accent;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                AnimatedRotation(
                  turns: expanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOutCubic,
                  child: const Icon(Icons.chevron_right_rounded, size: 18),
                ),
                const SizedBox(width: 4),
                Icon(Icons.folder_rounded, size: 18, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${items.length}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 240),
          sizeCurve: Curves.easeInOutCubic,
          crossFadeState: expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(
            padding: const EdgeInsetsDirectional.only(start: 30, bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Icon(
                          Icons.subdirectory_arrow_right_rounded,
                          size: 14,
                          color: accent.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppTheme.textSecondary,
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
      ],
    );
  }
}
