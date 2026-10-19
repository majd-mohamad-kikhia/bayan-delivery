import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/locale_context.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/platform_colors.dart';
import '../../../orders/presentation/widgets/orders_dialog_shell.dart';
import '../../../products/data/platform_sync_service.dart';
import '../../../products/presentation/cubit/platform_sync_cubit.dart';
import 'erp_registration_widgets.dart';

String _t(BuildContext context, String en, String ar) =>
    context.isArabic ? ar : en;

String _money(int minor) => (minor / 100).toStringAsFixed(2);

/// "Platforms up to date" / "3 prices sent" / "1 failed": whether what changed
/// in Al-Bayan has reached Keeta and HungerStation. Tap for the details.
class PlatformSyncChip extends StatelessWidget {
  const PlatformSyncChip({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlatformSyncCubit, PlatformSyncState>(
      builder: (context, state) {
        final (IconData icon, Color color, String text) = switch (state) {
          PlatformSyncState(running: true) => (
            Icons.sync_rounded,
            AppTheme.primary,
            _t(context, 'Syncing platforms…', 'مزامنة المنصات…'),
          ),
          PlatformSyncState(error: != null) => (
            Icons.cloud_off_rounded,
            AppTheme.coral,
            _t(
              context,
              'Platform sync: cannot read Bayan',
              'مزامنة المنصات: تعذّرت قراءة بيان',
            ),
          ),
          PlatformSyncState(lastFailed: > 0) => (
            Icons.warning_amber_rounded,
            AppTheme.coral,
            _t(
              context,
              '${state.lastFailed} not sent to platforms',
              '${state.lastFailed} لم تُرسل للمنصات',
            ),
          ),
          PlatformSyncState(lastAdded: > 0) => (
            Icons.add_business_rounded,
            const Color(0xFF16A34A),
            _t(
              context,
              '${state.lastAdded} new product(s) added to platforms',
              'أُضيف ${state.lastAdded} منتج جديد للمنصات',
            ),
          ),
          PlatformSyncState(lastSent: > 0) => (
            Icons.cloud_done_rounded,
            const Color(0xFF16A34A),
            _t(
              context,
              '${state.lastSent} change(s) sent to platforms',
              'أُرسل ${state.lastSent} تغيير للمنصات',
            ),
          ),
          _ => (
            Icons.cloud_done_outlined,
            AppTheme.textMuted,
            state.lastRun == null
                ? _t(context, 'Platform sync starting…', 'مزامنة المنصات تبدأ…')
                : _t(context, 'Platforms up to date', 'المنصات محدّثة'),
          ),
        };
        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => showPlatformSyncDialog(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                state.running
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (state.newProducts.isNotEmpty && !state.running) ...[
                  const SizedBox(width: 8),
                  Tooltip(
                    message: _t(
                      context,
                      'Add the new products to all platforms',
                      'أضف المنتجات الجديدة إلى كل المنصات',
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => addNewProductsToPlatforms(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.add_business_outlined,
                              size: 13,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _t(
                                context,
                                'Add ${state.newProducts.length} new',
                                'أضف ${state.newProducts.length} جديد',
                              ),
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Puts the items found new in Al-Bayan on the platforms: the same review and
/// progress as the "Add to all platforms" button, then re-checks what changed.
Future<void> addNewProductsToPlatforms(BuildContext context) async {
  final cubit = context.read<PlatformSyncCubit>();
  final state = cubit.state;
  await reviewAndAddToPlatforms(
    context,
    universe: state.catalog,
    candidates: state.newProducts,
  );
  await cubit.runNow();
}

Future<void> showPlatformSyncDialog(BuildContext context) {
  final cubit = context.read<PlatformSyncCubit>();
  return showOrdersDialog<void>(
    context,
    builder: (_) =>
        BlocProvider.value(value: cubit, child: const _SyncDialog()),
  );
}

class _SyncDialog extends StatelessWidget {
  const _SyncDialog();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlatformSyncCubit, PlatformSyncState>(
      builder: (context, state) {
        final last = state.lastRun;
        return OrdersDialogShell(
          icon: Icons.sync_alt_rounded,
          title: _t(context, 'Sync with platforms', 'المزامنة مع المنصات'),
          subtitle: last == null
              ? _t(context, 'Not run yet', 'لم تعمل بعد')
              : '${_t(context, 'Last run', 'آخر تشغيل')} ${last.hour.toString().padLeft(2, '0')}:${last.minute.toString().padLeft(2, '0')}  ·  ${_t(context, 'every 3 minutes', 'كل 3 دقائق')}',
          maxWidth: 680,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_t(context, 'Close', 'إغلاق')),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: state.running
                  ? null
                  : () => context.read<PlatformSyncCubit>().runNow(),
              icon: state.running
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.sync_rounded, size: 18),
              label: Text(_t(context, 'Sync now', 'زامن الآن')),
              style: dialogButtonStyle,
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _t(
                  context,
                  'When a product you already added changes in Al-Bayan (price, or name on Keeta), the change is sent to the platforms.',
                  'عندما يتغيّر منتج أضفته سابقاً في بيان (السعر، أو الاسم في كيتا)، يُرسل التغيير إلى المنصات.',
                ),
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
              ),
              if (state.error != null) ...[
                const SizedBox(height: 12),
                Text(
                  state.error!,
                  style: const TextStyle(color: AppTheme.coral, fontSize: 12.5),
                ),
              ],
              const SizedBox(height: 16),
              _AutoAddCard(state: state),
              const SizedBox(height: 18),
              Text(
                _t(context, 'Recent changes', 'آخر التغييرات'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              if (state.log.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    _t(
                      context,
                      'Nothing has changed yet.',
                      'لم يتغيّر شيء بعد.',
                    ),
                    style: const TextStyle(color: AppTheme.textMuted),
                  ),
                )
              else
                for (final change in state.log.take(30))
                  _ChangeRow(change: change),
              if (state.newProducts.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  _t(
                    context,
                    state.autoAdd
                        ? 'Waiting: not added yet (${state.newProducts.length})'
                        : 'New in Al-Bayan, not on any platform (${state.newProducts.length})',
                    state.autoAdd
                        ? 'بانتظار الإضافة (${state.newProducts.length})'
                        : 'جديدة في بيان وليست على أي منصة (${state.newProducts.length})',
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  _t(
                    context,
                    state.autoAdd
                        ? 'They are added on the next run. One with no price, or no group (and no fallback category), stays here until fixed.'
                        : 'Each goes into a Keeta category named after its Al-Bayan group.',
                    state.autoAdd
                        ? 'تُضاف في التشغيل القادم. المنتج بلا سعر أو بلا مجموعة يبقى هنا حتى يُصلَح.'
                        : 'كل منتج يدخل تصنيفاً في كيتا باسم مجموعته في بيان.',
                  ),
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FilledButton.icon(
                    onPressed: state.running
                        ? null
                        : () => addNewProductsToPlatforms(context),
                    icon: const Icon(Icons.add_business_outlined, size: 18),
                    label: Text(
                      _t(
                        context,
                        'Add ${state.newProducts.length} to all platforms',
                        'إضافة ${state.newProducts.length} إلى كل المنصات',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final name in [
                      for (final p in state.newProducts.take(24)) p.name.trim(),
                    ])
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceAlt,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Text(
                          name.isEmpty ? '—' : name,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    if (state.newProducts.length > 24)
                      Text(
                        '+${state.newProducts.length - 24}',
                        style: const TextStyle(color: AppTheme.textMuted),
                      ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ChangeRow extends StatelessWidget {
  const _ChangeRow({required this.change});

  final SyncChange change;

  @override
  Widget build(BuildContext context) {
    final platformColor = PlatformColors.of(change.platform);
    final platformLabel = change.platform == 'keeta'
        ? 'Keeta'
        : 'HungerStation';
    final what = [
      if (change.priceChanged)
        '${_money(change.oldPriceMinor ?? 0)} → ${_money(change.newPriceMinor ?? 0)}',
      if (change.nameChanged && change.oldName != null)
        '“${change.oldName}” → “${change.newName}”',
    ].join('   ');
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: change.ok
            ? AppTheme.surface
            : AppTheme.coral.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: change.ok
              ? AppTheme.border
              : AppTheme.coral.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            change.ok ? Icons.check_circle_rounded : Icons.error_rounded,
            size: 18,
            color: change.ok ? const Color(0xFF16A34A) : AppTheme.coral,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  change.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  change.ok ? what : '$what  ·  ${change.error ?? ''}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: change.ok ? AppTheme.textSecondary : AppTheme.coral,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: platformColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              platformLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: platformColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The switch for adding new products automatically, and what it did lately.
class _AutoAddCard extends StatelessWidget {
  const _AutoAddCard({required this.state});

  final PlatformSyncState state;

  @override
  Widget build(BuildContext context) {
    final recent = state.autoLog.take(8).toList();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: state.autoAdd
            ? const Color(0xFF16A34A).withValues(alpha: 0.06)
            : AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: state.autoAdd
              ? const Color(0xFF16A34A).withValues(alpha: 0.3)
              : AppTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.add_business_rounded,
                size: 20,
                color: Color(0xFF16A34A),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t(
                        context,
                        'Add new products automatically',
                        'إضافة المنتجات الجديدة تلقائياً',
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      _t(
                        context,
                        'A product new in Al-Bayan goes to Keeta and HungerStation by itself, in the category of its group.',
                        'المنتج الجديد في بيان يذهب إلى كيتا وهنقرستيشن تلقائياً، في تصنيف مجموعته.',
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: state.autoAdd,
                onChanged: (v) =>
                    context.read<PlatformSyncCubit>().setAutoAdd(v),
              ),
            ],
          ),
          if (state.autoNote != null) ...[
            const SizedBox(height: 8),
            Text(
              state.autoNote!,
              style: const TextStyle(fontSize: 12, color: AppTheme.coral),
            ),
          ],
          if (recent.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final e in recent)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(
                      e.ok
                          ? Icons.check_circle_rounded
                          : (e.skipped
                                ? Icons.pause_circle_outline_rounded
                                : Icons.error_rounded),
                      size: 15,
                      color: e.ok
                          ? const Color(0xFF16A34A)
                          : (e.skipped ? AppTheme.textMuted : AppTheme.coral),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        e.ok ? e.name : '${e.name}  ·  ${e.error}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: e.ok
                              ? AppTheme.textPrimary
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
