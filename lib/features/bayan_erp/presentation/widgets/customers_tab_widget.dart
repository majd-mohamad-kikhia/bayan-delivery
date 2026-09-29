import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/customer_model.dart';
import '../bloc/bayan_erp_bloc.dart';
import '../bloc/bayan_erp_state.dart';
import '_erp_table_shell.dart';

/// Tab content that displays the accounts / customers list.
class CustomersTabWidget extends StatelessWidget {
  const CustomersTabWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BayanErpBloc, BayanErpState>(
      buildWhen: (p, c) =>
          p.customersStatus != c.customersStatus ||
          p.customers != c.customers ||
          p.customersError != c.customersError,
      builder: (context, state) => ErpTableShell(
        status: state.customersStatus,
        error: state.customersError,
        isEmpty: state.customers.isEmpty,
        emptyLabel: 'No customers found',
        child: _CustomersTable(rows: state.customers),
      ),
    );
  }
}

class _CustomersTable extends StatelessWidget {
  const _CustomersTable({required this.rows});

  final List<CustomerModel> rows;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor: WidgetStatePropertyAll(AppTheme.surfaceAlt),
          headingTextStyle: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          dataRowMinHeight: 44,
          dataRowMaxHeight: 44,
          columnSpacing: 24,
          columns: const [
            DataColumn(label: Text('ID')),
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Phone')),
            DataColumn(label: Text('Address')),
            DataColumn(label: Text('Balance'), numeric: true),
            DataColumn(label: Text('Group ID'), numeric: true),
            DataColumn(label: Text('Price Tier')),
          ],
          rows: [
            for (final c in rows)
              DataRow(cells: [
                DataCell(Text('${c.id}', style: _monoStyle)),
                DataCell(_ArabicText(c.name)),
                DataCell(Text(c.phone.isEmpty ? '—' : c.phone)),
                DataCell(
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 200),
                    child: Text(
                      c.address.isEmpty ? '—' : c.address,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(_BalanceChip(c.balance)),
                DataCell(Text(c.groupId == 0 ? '—' : '${c.groupId}', style: _monoStyle)),
                DataCell(_PriceKindBadge(c.priceKind)),
              ]),
          ],
        ),
      ),
    );
  }
}

// ─── Shared micro-widgets ─────────────────────────────────────────────────────

const _monoStyle = TextStyle(
  fontFamily: 'monospace',
  fontSize: 12,
  color: AppTheme.textSecondary,
);

class _ArabicText extends StatelessWidget {
  const _ArabicText(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Text(text, overflow: TextOverflow.ellipsis),
      );
}

class _BalanceChip extends StatelessWidget {
  const _BalanceChip(this.balance);
  final double balance;

  @override
  Widget build(BuildContext context) {
    final isPositive = balance >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isPositive ? const Color(0xFFDCFCE7) : const Color(0xFFFFE4E4),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        balance.toStringAsFixed(0),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isPositive ? const Color(0xFF15803D) : AppTheme.coral,
        ),
      ),
    );
  }
}

class _PriceKindBadge extends StatelessWidget {
  const _PriceKindBadge(this.kind);
  final String kind;

  @override
  Widget build(BuildContext context) {
    if (kind.isEmpty) return const Text('—', style: TextStyle(color: AppTheme.textMuted));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Text(
        kind,
        style: const TextStyle(
          fontSize: 11,
          color: AppTheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
