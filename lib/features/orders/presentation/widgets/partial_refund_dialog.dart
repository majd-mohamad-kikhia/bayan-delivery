import 'package:flutter/material.dart';

import '../../../../core/localization/locale_context.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/repositories/orders_repository.dart';
import '../l10n/orders_strings.dart';
import 'orders_dialog_shell.dart';

/// Pick the items (and how many of each) to refund, and why. Resolves to the
/// action payload `{ products, partRefundType, partRefundReason? }`, or null.
Future<Map<String, Object?>?> showPartialRefundDialog(
  BuildContext context, {
  required Future<List<RefundableLine>> lines,
}) {
  return showOrdersDialog<Map<String, Object?>>(
    context,
    builder: (_) => _PartialRefundDialog(lines: lines),
  );
}

class _PartialRefundDialog extends StatefulWidget {
  const _PartialRefundDialog({required this.lines});

  final Future<List<RefundableLine>> lines;

  @override
  State<_PartialRefundDialog> createState() => _PartialRefundDialogState();
}

class _PartialRefundDialogState extends State<_PartialRefundDialog> {
  final Map<int, int> _counts = {};
  final _other = TextEditingController();
  int _reason = 200001;
  List<RefundableLine>? _loaded;
  Object? _error;

  @override
  void initState() {
    super.initState();
    widget.lines
        .then((value) {
          if (mounted) setState(() => _loaded = value);
        })
        .catchError((Object e) {
          if (mounted) setState(() => _error = e);
        });
  }

  @override
  void dispose() {
    _other.dispose();
    super.dispose();
  }

  double _total(List<RefundableLine> lines) => [
    for (final line in lines)
      (_counts[line.orderProductId] ?? 0) * line.unitPrice,
  ].fold(0, (a, b) => a + b);

  bool get _picked => _counts.values.any((c) => c > 0);

  bool get _valid =>
      _picked && (_reason != 200000 || _other.text.trim().isNotEmpty);

  void _submit() {
    Navigator.of(context).pop(<String, Object?>{
      'products': [
        for (final entry in _counts.entries)
          if (entry.value > 0)
            {'orderProductId': entry.key, 'refundCount': entry.value},
      ],
      'partRefundType': _reason,
      if (_reason == 200000) 'partRefundReason': _other.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.ordersStrings;
    final common = context.commonStrings;
    final lines = _loaded;
    final reasons = [
      (200001, s.refundReasonSlow),
      (200002, s.refundReasonIngredients),
      (200003, s.refundReasonMissing),
      (200004, s.refundReasonWrong),
      (200000, s.refundReasonOther),
    ];

    return OrdersDialogShell(
      icon: Icons.payments_outlined,
      title: s.refundTitle,
      subtitle: s.refundSubtitle,
      maxWidth: 600,
      actions: [
        if (lines != null && lines.isNotEmpty) ...[
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                '${s.refundTotal}  ${common.money(_total(lines))}',
                key: ValueKey(_total(lines)),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(common.cancel),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: _valid ? _submit : null,
          icon: const Icon(Icons.undo_rounded, size: 18),
          label: Text(s.refundApply),
          style: dialogButtonStyle,
        ),
      ],
      child: AnimatedSize(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: _error != null
            ? Text('$_error', style: const TextStyle(color: AppTheme.coral))
            : lines == null
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 14),
                    Text(
                      s.refundLoading,
                      style: const TextStyle(color: AppTheme.textMuted),
                    ),
                  ],
                ),
              )
            : lines.every((l) => l.refundable == 0)
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  s.refundNothing,
                  style: const TextStyle(color: AppTheme.textMuted),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final line in lines)
                    _LineRow(
                      line: line,
                      count: _counts[line.orderProductId] ?? 0,
                      onChanged: (c) =>
                          setState(() => _counts[line.orderProductId] = c),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    s.refundReason,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (code, label) in reasons)
                        ChoiceChip(
                          label: Text(label),
                          selected: _reason == code,
                          showCheckmark: false,
                          selectedColor: AppTheme.primary,
                          labelStyle: TextStyle(
                            color: _reason == code
                                ? Colors.white
                                : AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: (_) => setState(() => _reason = code),
                        ),
                    ],
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    alignment: Alignment.topCenter,
                    child: _reason == 200000
                        ? Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: TextField(
                              controller: _other,
                              onChanged: (_) => setState(() {}),
                              maxLines: 2,
                              decoration: InputDecoration(
                                labelText: s.refundDescribe,
                              ),
                            ),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                ],
              ),
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({
    required this.line,
    required this.count,
    required this.onChanged,
  });

  final RefundableLine line;
  final int count;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = context.ordersStrings;
    final common = context.commonStrings;
    final disabled = line.refundable == 0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: count > 0
            ? AppTheme.primary.withValues(alpha: 0.07)
            : AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: count > 0 ? AppTheme.primary : AppTheme.border,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: disabled ? AppTheme.textMuted : AppTheme.textPrimary,
                  ),
                ),
                Text(
                  '${common.money(line.unitPrice)} × ${line.count}'
                  '${line.refunded > 0 ? '  ·  ${line.refunded} ${s.refundAlready}' : ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: count > 0 ? () => onChanged(count - 1) : null,
            icon: const Icon(Icons.remove_circle_outline_rounded),
          ),
          SizedBox(
            width: 24,
            child: Text(
              '$count',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            onPressed: count < line.refundable
                ? () => onChanged(count + 1)
                : null,
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
    );
  }
}
