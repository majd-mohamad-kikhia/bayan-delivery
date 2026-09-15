import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../cubit/keeta_shop_cubit.dart';
import 'business_hours_list.dart';
import 'emergency_status_dialog.dart';
import 'shop_status_badge.dart';

void showKeetaShopPanel(BuildContext context, {required String dongleNumber}) {
  final cubit = context.read<KeetaShopCubit>();
  cubit.load(dongleNumber: dongleNumber);

  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Keeta shops',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 260),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero)
              .animate(curved),
          child: child,
        ),
      );
    },
    pageBuilder: (context, _, __) => BlocProvider.value(
      value: cubit,
      child: const _KeetaShopPanel(),
    ),
  );
}

class _KeetaShopPanel extends StatelessWidget {
  const _KeetaShopPanel();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
        child: Material(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: BlocConsumer<KeetaShopCubit, KeetaShopState>(
            listenWhen: (p, c) => c.actionError != null && p.actionError != c.actionError,
            listener: (context, state) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(content: Text(state.actionError!), backgroundColor: AppTheme.coral),
                );
              context.read<KeetaShopCubit>().clearActionError();
            },
            builder: (context, state) {
              return Column(
                children: [
                  const _Header(),
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
  const _Header();

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
              color: const Color(0xFF6D28D9).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.storefront_outlined, color: Color(0xFF6D28D9), size: 18),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Keeta Shops',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                ),
                Text(
                  'Branches · hours · emergency status',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => context.read<KeetaShopCubit>().load(),
            icon: const Icon(Icons.refresh_rounded, size: 18),
          ),
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

  final KeetaShopState state;

  @override
  Widget build(BuildContext context) {
    if (state.status == KeetaShopLoadStatus.loading ||
        state.status == KeetaShopLoadStatus.initial) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (state.status == KeetaShopLoadStatus.failure) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                state.errorMessage ?? 'Failed to load shops',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              TextButton(
                onPressed: () => context.read<KeetaShopCubit>().load(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.shops.isEmpty) {
      return const Center(
        child: Text('No authorized shops found', style: TextStyle(color: AppTheme.textMuted)),
      );
    }

    final shop = state.selectedShop;
    final status = state.shopStatus;
    final available = status?.isAvailable ?? false;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Label('Branch'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                isExpanded: true,
                value: state.selectedShopId,
                items: [
                  for (final s in state.shops)
                    DropdownMenuItem(
                      value: s.id,
                      child: Text('${s.name}  ·  #${s.id}', overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (id) {
                  if (id != null) context.read<KeetaShopCubit>().selectShop(id);
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Branch status',
                        style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                      ),
                    ),
                    if (status != null) ShopStatusBadge(isAvailable: available),
                  ],
                ),
                if (shop?.address != null) ...[
                  const SizedBox(height: 8),
                  Text(shop!.address!, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _ActionBtn(
                        label: 'Emergency Close',
                        color: AppTheme.coral,
                        enabled: status != null && available && !state.isUpdatingStatus,
                        loading: state.isUpdatingStatus && available,
                        onTap: () async {
                          final ok = await confirmEmergencyStatusChange(
                            context,
                            closing: true,
                            shopName: shop?.name ?? 'shop',
                          );
                          if (ok && context.mounted) {
                            await context.read<KeetaShopCubit>().setAvailable(available: false);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionBtn(
                        label: 'Reopen',
                        color: const Color(0xFF22C55E),
                        enabled: status != null && !available && !state.isUpdatingStatus,
                        loading: state.isUpdatingStatus && !available,
                        onTap: () async {
                          final ok = await confirmEmergencyStatusChange(
                            context,
                            closing: false,
                            shopName: shop?.name ?? 'shop',
                          );
                          if (ok && context.mounted) {
                            await context.read<KeetaShopCubit>().setAvailable(available: true);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const _Label('Business hours (local time)'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: status == null
                ? const Text('Loading hours…', style: TextStyle(color: AppTheme.textMuted, fontSize: 13))
                : BusinessHoursList(weekHours: status.weekHours),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppTheme.textMuted,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
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
          height: 40,
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
              : Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ),
      ),
    );
  }
}
