import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/hs_vendor_status_model.dart';
import '../cubit/hs_outlet_cubit.dart';

void showHsOutletPanel(BuildContext context, {required String dongleNumber}) {
  final cubit = context.read<HsOutletCubit>();
  cubit.load(dongleNumber: dongleNumber);

  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'HungerStation outlet',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 260),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
          child: child,
        ),
      );
    },
    pageBuilder: (context, _, __) => BlocProvider.value(
      value: cubit,
      child: const _HsOutletPanel(),
    ),
  );
}

class _HsOutletPanel extends StatelessWidget {
  const _HsOutletPanel();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 640),
        child: Material(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: BlocConsumer<HsOutletCubit, HsOutletState>(
            listenWhen: (p, c) => c.actionError != null && p.actionError != c.actionError,
            listener: (context, state) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(content: Text(state.actionError!), backgroundColor: AppTheme.coral),
                );
              context.read<HsOutletCubit>().clearActionError();
            },
            builder: (context, state) {
              return Column(
                children: [
                  _Header(onRefresh: () => context.read<HsOutletCubit>().load()),
                  const Divider(height: 1, color: AppTheme.border),
                  Expanded(child: _Body(state: state)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFEA580C).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.storefront_outlined, color: Color(0xFFEA580C), size: 18),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HungerStation Outlet',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                ),
                Text(
                  'Open / close vendor status',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          IconButton(onPressed: onRefresh, icon: const Icon(Icons.refresh_rounded, size: 18)),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state});

  final HsOutletState state;

  @override
  Widget build(BuildContext context) {
    if (state.status == HsOutletLoadStatus.loading ||
        state.status == HsOutletLoadStatus.initial) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (state.status == HsOutletLoadStatus.failure) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                state.errorMessage ?? 'Failed to load outlet',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              TextButton(
                onPressed: () => context.read<HsOutletCubit>().load(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final vendor = state.vendorStatus!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatusCard(vendor: vendor),
          const SizedBox(height: 16),
          const Text(
            'UPDATE STATUS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.textMuted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          _QuickAction(
            label: 'Reopen (OPEN)',
            color: const Color(0xFF22C55E),
            enabled: !vendor.isOpen && !state.isUpdating,
            loading: state.isUpdating,
            onTap: () => context.read<HsOutletCubit>().updateStatus(status: 'OPEN'),
          ),
          const SizedBox(height: 8),
          _QuickAction(
            label: 'Close for today',
            color: AppTheme.coral,
            enabled: vendor.isOpen && !state.isUpdating,
            loading: false,
            onTap: () => _closeToday(context),
          ),
          const SizedBox(height: 8),
          _QuickAction(
            label: 'Close until…',
            color: const Color(0xFFF59E0B),
            enabled: vendor.isOpen && !state.isUpdating,
            loading: false,
            onTap: () => _closeUntil(context),
          ),
        ],
      ),
    );
  }

  Future<void> _closeToday(BuildContext context) async {
    final reason = await _pickReason(context);
    if (reason == null || !context.mounted) return;
    await context.read<HsOutletCubit>().updateStatus(
          status: 'CLOSED_TODAY',
          closedReason: reason,
        );
  }

  Future<void> _closeUntil(BuildContext context) async {
    final reason = await _pickReason(context);
    if (reason == null || !context.mounted) return;

    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(hours: 2)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (date == null || !context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 2))),
    );
    if (time == null || !context.mounted) return;

    final until = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    await context.read<HsOutletCubit>().updateStatus(
          status: 'CLOSED_UNTIL',
          closedReason: reason,
          closedUntil: until,
        );
  }

  Future<String?> _pickReason(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Closed reason',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
            for (final reason in HsClosedReasons.values)
              ListTile(
                title: Text(HsClosedReasons.label(reason)),
                onTap: () => Navigator.pop(context, reason),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.vendor});

  final HsVendorStatusModel vendor;

  @override
  Widget build(BuildContext context) {
    final open = vendor.isOpen;
    final color = open ? const Color(0xFF22C55E) : AppTheme.coral;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Vendor status',
                  style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  vendor.status,
                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Vendor: ${vendor.vendorId}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          Text('Chain: ${vendor.chainId}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          if (vendor.closedReason != null)
            Text(
              'Reason: ${HsClosedReasons.label(vendor.closedReason!)}',
              style: const TextStyle(fontSize: 12, color: AppTheme.coral),
            ),
          if (vendor.closedUntil != null)
            Text(
              'Until: ${vendor.closedUntil!.toLocal()}',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.label,
    required this.color,
    required this.enabled,
    required this.loading,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool enabled;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: enabled || loading ? 1 : 0.4,
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: loading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: color),
                )
              : Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        ),
      ),
    );
  }
}
