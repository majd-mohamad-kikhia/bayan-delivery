import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/store_model.dart';
import '../bloc/bayan_erp_bloc.dart';
import '../bloc/bayan_erp_state.dart';
import '_erp_table_shell.dart';

/// Tab content that displays the warehouses / stores list.
class StoresTabWidget extends StatelessWidget {
  const StoresTabWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BayanErpBloc, BayanErpState>(
      buildWhen: (p, c) =>
          p.storesStatus != c.storesStatus ||
          p.stores != c.stores ||
          p.storesError != c.storesError,
      builder: (context, state) => ErpTableShell(
        status: state.storesStatus,
        error: state.storesError,
        isEmpty: state.stores.isEmpty,
        emptyLabel: 'No warehouses found',
        child: _StoresGrid(stores: state.stores),
      ),
    );
  }
}

class _StoresGrid extends StatelessWidget {
  const _StoresGrid({required this.stores});

  final List<StoreModel> stores;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = (constraints.maxWidth / 240).floor().clamp(2, 6);
        return GridView.builder(
          padding: const EdgeInsets.all(24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.4,
          ),
          itemCount: stores.length,
          itemBuilder: (_, i) => _StoreCard(store: stores[i]),
        );
      },
    );
  }
}

class _StoreCard extends StatelessWidget {
  const _StoreCard({required this.store});

  final StoreModel store;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.warehouse_outlined, color: AppTheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text(
                    store.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppTheme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Store #${store.id}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
