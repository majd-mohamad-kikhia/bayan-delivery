import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/erp_product_model.dart';
import '../bloc/bayan_erp_bloc.dart';
import '../bloc/bayan_erp_event.dart';
import '../bloc/bayan_erp_state.dart';
import '../utils/erp_stock_style.dart';

enum ErpProductsViewMode { grid, table }

class ErpProductsToolbarWidget extends StatelessWidget {
  const ErpProductsToolbarWidget({
    super.key,
    required this.viewMode,
    required this.onViewModeChanged,
  });

  final ErpProductsViewMode viewMode;
  final ValueChanged<ErpProductsViewMode> onViewModeChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const _SearchField(),
          const _StockFilterChips(),
          _ViewModeToggle(value: viewMode, onChanged: onViewModeChanged),
        ],
      ),
    );
  }
}

// ─── Search ───────────────────────────────────────────────────────────────────

class _SearchField extends StatefulWidget {
  const _SearchField();

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  late final TextEditingController _controller =
      TextEditingController(text: context.read<BayanErpBloc>().state.productsQuery);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) =>
      context.read<BayanErpBloc>().add(BayanErpProductsSearchChanged(value));

  @override
  Widget build(BuildContext context) {
    return BlocListener<BayanErpBloc, BayanErpState>(
      listenWhen: (p, c) => p.productsQuery != c.productsQuery,
      listener: (_, state) {
        if (_controller.text != state.productsQuery) _controller.text = state.productsQuery;
      },
      child: SizedBox(
        width: 320,
        height: 42,
        child: TextField(
          controller: _controller,
          onChanged: _onChanged,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: AppTheme.surface,
            hintText: 'Search by name, short name or ID',
            hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
            prefixIcon: const Icon(Icons.search_rounded, size: 19, color: AppTheme.textMuted),
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (_, value, _) => value.text.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.close_rounded, size: 16),
                      onPressed: () {
                        _controller.clear();
                        _onChanged('');
                      },
                    ),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Stock filter chips ───────────────────────────────────────────────────────

class _StockFilterChips extends StatelessWidget {
  const _StockFilterChips();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BayanErpBloc, BayanErpState>(
      buildWhen: (p, c) =>
          p.products != c.products || p.productsStockFilter != c.productsStockFilter,
      builder: (context, state) {
        final summary = state.productsStockSummary;
        final selected = state.productsStockFilter;
        void select(ErpStockLevel? level) =>
            context.read<BayanErpBloc>().add(BayanErpProductsStockFilterChanged(level));

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _FilterChip(
              label: 'All',
              count: state.products.length,
              color: AppTheme.primary,
              selected: selected == null,
              onTap: () => select(null),
            ),
            for (final (level, count) in [
              (ErpStockLevel.available, summary.available),
              (ErpStockLevel.low, summary.low),
              (ErpStockLevel.out, summary.out),
            ])
              _FilterChip(
                label: level.label,
                count: count,
                color: level.color,
                selected: selected == level,
                onTap: () => select(selected == level ? null : level),
              ),
          ],
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.fromLTRB(12, 7, 7, 7),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.12) : AppTheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? color : AppTheme.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? color : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                constraints: const BoxConstraints(minWidth: 22),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected ? color : AppTheme.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── View mode toggle ─────────────────────────────────────────────────────────

class _ViewModeToggle extends StatelessWidget {
  const _ViewModeToggle({required this.value, required this.onChanged});

  final ErpProductsViewMode value;
  final ValueChanged<ErpProductsViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ErpProductsViewMode>(
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        backgroundColor: AppTheme.surface,
        selectedBackgroundColor: AppTheme.primary.withValues(alpha: 0.12),
        selectedForegroundColor: AppTheme.primary,
        foregroundColor: AppTheme.textSecondary,
        side: const BorderSide(color: AppTheme.border),
        visualDensity: VisualDensity.compact,
      ),
      segments: const [
        ButtonSegment(
          value: ErpProductsViewMode.grid,
          icon: Icon(Icons.grid_view_rounded, size: 18),
          tooltip: 'Grid view',
        ),
        ButtonSegment(
          value: ErpProductsViewMode.table,
          icon: Icon(Icons.table_rows_rounded, size: 18),
          tooltip: 'Table view',
        ),
      ],
      selected: {value},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}
