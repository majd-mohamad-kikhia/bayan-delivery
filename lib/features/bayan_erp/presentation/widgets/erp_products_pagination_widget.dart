import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../bloc/bayan_erp_bloc.dart';
import '../bloc/bayan_erp_event.dart';
import '../bloc/bayan_erp_state.dart';

/// Footer for the products list: page-size picker, item range, and page buttons.
///
/// The API does not report a total count, so only pages up to the next
/// reachable one are numbered.
class ErpProductsPaginationWidget extends StatelessWidget {
  const ErpProductsPaginationWidget({super.key, this.showTopBorder = true});

  static const pageSizeOptions = [10, 20, 50, 100];

  final bool showTopBorder;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BayanErpBloc, BayanErpState>(
      buildWhen: (p, c) =>
          p.productsPage != c.productsPage ||
          p.productsPageSize != c.productsPageSize ||
          p.products.length != c.products.length ||
          p.productsStatus != c.productsStatus,
      builder: (context, state) {
        final bloc = context.read<BayanErpBloc>();
        final page = state.productsPage;
        final size = state.productsPageSize;
        final count = state.products.length;
        final isLoading = state.productsStatus == BayanErpStatus.loading;
        final hasNext = count >= size;
        final lastKnownPage = hasNext ? page + 1 : page;
        final first = page * size + (count == 0 ? 0 : 1);
        final last = page * size + count;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            border: showTopBorder
                ? const Border(top: BorderSide(color: AppTheme.border))
                : null,
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 10,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Showing', style: _mutedStyle),
                  const SizedBox(width: 8),
                  _PageSizeDropdown(
                    value: size,
                    enabled: !isLoading,
                    onChanged: (v) => bloc.add(BayanErpProductsPageSizeChanged(v)),
                  ),
                  const SizedBox(width: 8),
                  Text.rich(
                    TextSpan(
                      style: _mutedStyle,
                      children: [
                        const TextSpan(text: 'per page  ·  items '),
                        TextSpan(
                          text: count == 0 ? '0' : '$first–$last',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Page ${page + 1}', style: _mutedStyle),
                  const SizedBox(width: 14),
                  _PagerButton(
                    tooltip: 'Previous page',
                    onTap: page > 0 && !isLoading
                        ? () => bloc.add(const BayanErpPrevPageRequested())
                        : null,
                    child: const Icon(Icons.chevron_left_rounded, size: 20),
                  ),
                  for (final entry in _pageEntries(page, lastKnownPage)) ...[
                    const SizedBox(width: 6),
                    if (entry == null)
                      const SizedBox(
                        width: 24,
                        child: Text('…', textAlign: TextAlign.center, style: _mutedStyle),
                      )
                    else
                      _PagerButton(
                        selected: entry == page,
                        onTap: entry != page && !isLoading
                            ? () => bloc.add(BayanErpPageSelected(entry))
                            : null,
                        child: Text('${entry + 1}'),
                      ),
                  ],
                  const SizedBox(width: 6),
                  _PagerButton(
                    tooltip: 'Next page',
                    onTap: hasNext && !isLoading
                        ? () => bloc.add(const BayanErpNextPageRequested())
                        : null,
                    child: const Icon(Icons.chevron_right_rounded, size: 20),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Zero-based pages to number, with `null` marking a gap (`…`).
  static List<int?> _pageEntries(int current, int lastKnown) {
    final pages = {0, current - 1, current, current + 1, lastKnown}
        .where((p) => p >= 0 && p <= lastKnown)
        .toList()
      ..sort();
    final entries = <int?>[];
    int? previous;
    for (final p in pages) {
      if (previous != null && p - previous > 1) entries.add(null);
      entries.add(p);
      previous = p;
    }
    return entries;
  }
}

const _mutedStyle = TextStyle(fontSize: 13, color: AppTheme.textSecondary);

class _PageSizeDropdown extends StatelessWidget {
  const _PageSizeDropdown({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.only(left: 10, right: 4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          isDense: true,
          borderRadius: BorderRadius.circular(8),
          icon: const Icon(Icons.expand_more_rounded, size: 18),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
          onChanged: enabled ? (v) => v == null ? null : onChanged(v) : null,
          items: [
            for (final option in ErpProductsPaginationWidget.pageSizeOptions)
              DropdownMenuItem(value: option, child: Text('$option')),
          ],
        ),
      ),
    );
  }
}

class _PagerButton extends StatelessWidget {
  const _PagerButton({
    required this.child,
    required this.onTap,
    this.selected = false,
    this.tooltip,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool selected;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null || selected;
    final foreground = selected
        ? Colors.white
        : (enabled ? AppTheme.textPrimary : AppTheme.textMuted);

    final button = Material(
      color: selected ? AppTheme.primary : AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: selected ? AppTheme.primary : AppTheme.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 34,
          height: 34,
          child: Center(
            child: IconTheme.merge(
              data: IconThemeData(color: foreground),
              child: DefaultTextStyle.merge(
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: foreground,
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );

    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
