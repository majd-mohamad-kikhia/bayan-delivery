import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/hs_vendor_status_model.dart';
import '../l10n/merchants_strings.dart';
import 'hs_dialog_widget.dart';

/// Asks for a HungerStation `closed_reason`. Resolves to the raw reason
/// code, or null when dismissed.
Future<String?> showHsClosedReasonPicker(
  BuildContext context, {
  required String confirmLabel,
}) {
  return showHsDialog<String>(
    context,
    barrierLabel: context.merchantsStrings.closedReasonTitle,
    builder: (_) => _ClosedReasonDialog(confirmLabel: confirmLabel),
  );
}

class _ReasonVisual {
  const _ReasonVisual(this.icon, this.color);

  final IconData icon;
  final Color color;
}

const Map<String, _ReasonVisual> _visuals = {
  'TOO_BUSY_NO_DRIVERS': _ReasonVisual(Icons.delivery_dining_outlined, Color(0xFFF59E0B)),
  'TOO_BUSY_KITCHEN': _ReasonVisual(Icons.soup_kitchen_outlined, hsOrange),
  'UPDATES_IN_MENU': _ReasonVisual(Icons.restaurant_menu_outlined, Color(0xFF3D5AFE)),
  'TECHNICAL_PROBLEM': _ReasonVisual(Icons.build_circle_outlined, Color(0xFF8B5CF6)),
  'CLOSED': _ReasonVisual(Icons.lock_outline_rounded, Color(0xFF64748B)),
  'OTHER': _ReasonVisual(Icons.more_horiz_rounded, Color(0xFF475569)),
  'BAD_WEATHER': _ReasonVisual(Icons.thunderstorm_outlined, Color(0xFF0EA5E9)),
  'HOLIDAY_SPECIAL_DAY': _ReasonVisual(Icons.celebration_outlined, Color(0xFFEC4899)),
};

const _fallbackVisual = _ReasonVisual(Icons.info_outline_rounded, AppTheme.textSecondary);

class _ClosedReasonDialog extends StatefulWidget {
  const _ClosedReasonDialog({required this.confirmLabel});

  final String confirmLabel;

  @override
  State<_ClosedReasonDialog> createState() => _ClosedReasonDialogState();
}

class _ClosedReasonDialogState extends State<_ClosedReasonDialog> {
  String? _selected;

  void _select(String reason) {
    if (_selected != reason) setState(() => _selected = reason);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.merchantsStrings;
    return HsDialogFrameWidget(
      maxWidth: 560,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HsDialogHeaderWidget(
            icon: Icons.do_not_disturb_on_outlined,
            title: s.closedReasonTitle,
            subtitle: s.closedReasonSubtitle,
          ),
          const Divider(height: 1, color: AppTheme.border),
          Flexible(
            child: _ReasonGrid(selected: _selected, onSelect: _select),
          ),
          const Divider(height: 1, color: AppTheme.border),
          HsDialogFooterWidget(
            confirmLabel: widget.confirmLabel,
            onConfirm: _selected == null
                ? null
                : () => Navigator.of(context).pop(_selected),
          ),
        ],
      ),
    );
  }
}

class _ReasonGrid extends StatelessWidget {
  const _ReasonGrid({required this.selected, required this.onSelect});

  final String? selected;
  final ValueChanged<String> onSelect;

  static const double _spacing = 10;
  static const double _padding = 20;
  static const double _twoColumnBreakpoint = 440;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth - _padding * 2;
        final columns = constraints.maxWidth >= _twoColumnBreakpoint ? 2 : 1;
        final tileWidth = (contentWidth - _spacing * (columns - 1)) / columns;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(_padding),
          child: Wrap(
            spacing: _spacing,
            runSpacing: _spacing,
            children: [
              for (final reason in HsClosedReasons.values)
                SizedBox(
                  width: tileWidth,
                  child: _ReasonTile(
                    reason: reason,
                    selected: reason == selected,
                    onTap: () => onSelect(reason),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ReasonTile extends StatelessWidget {
  const _ReasonTile({
    required this.reason,
    required this.selected,
    required this.onTap,
  });

  final String reason;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visual = _visuals[reason] ?? _fallbackVisual;
    final color = visual.color;
    final radius = BorderRadius.circular(14);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        hoverColor: color.withValues(alpha: 0.05),
        splashColor: color.withValues(alpha: 0.12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.08) : AppTheme.surfaceAlt,
            borderRadius: radius,
            border: Border.all(
              color: selected ? color : AppTheme.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: selected ? 0.18 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(visual.icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.merchantsStrings.closedReason(reason),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: selected
                    ? Icon(
                        Icons.check_circle_rounded,
                        key: const ValueKey('on'),
                        color: color,
                        size: 20,
                      )
                    : const Icon(
                        Icons.radio_button_unchecked_rounded,
                        key: ValueKey('off'),
                        color: AppTheme.border,
                        size: 20,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
