import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/salesman_model.dart';
import '../bloc/bayan_erp_bloc.dart';
import '../bloc/bayan_erp_state.dart';
import '_erp_table_shell.dart';

/// Tab content displaying the list of salesmen / delivery agents.
class SalesmanTabWidget extends StatelessWidget {
  const SalesmanTabWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BayanErpBloc, BayanErpState>(
      buildWhen: (p, c) =>
          p.salesmenStatus != c.salesmenStatus ||
          p.salesmen != c.salesmen ||
          p.salesmenError != c.salesmenError,
      builder: (context, state) => ErpTableShell(
        status: state.salesmenStatus,
        error: state.salesmenError,
        isEmpty: state.salesmen.isEmpty,
        emptyLabel: 'No salesmen found',
        child: _SalesmenTable(rows: state.salesmen),
      ),
    );
  }
}

class _SalesmenTable extends StatelessWidget {
  const _SalesmenTable({required this.rows});

  final List<SalesmanModel> rows;

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
          dataRowMinHeight: 48,
          dataRowMaxHeight: 48,
          columnSpacing: 32,
          columns: const [
            DataColumn(label: Text('ID')),
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Phone')),
          ],
          rows: [
            for (final s in rows)
              DataRow(cells: [
                DataCell(_IdBadge(s.id)),
                DataCell(_SalesmanNameCell(name: s.name)),
                DataCell(_PhoneCell(s.phone)),
              ]),
          ],
        ),
      ),
    );
  }
}

class _IdBadge extends StatelessWidget {
  const _IdBadge(this.id);
  final int id;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppTheme.sidebarItem,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '#$id',
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            color: AppTheme.sidebarText,
          ),
        ),
      );
}

class _SalesmanNameCell extends StatelessWidget {
  const _SalesmanNameCell({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircleAvatar(
            radius: 14,
            backgroundColor: Color(0x203D5AFE),
            child: Icon(Icons.person_outline, size: 14, color: AppTheme.primary),
          ),
          const SizedBox(width: 8),
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      );
}

class _PhoneCell extends StatelessWidget {
  const _PhoneCell(this.phone);
  final String phone;

  @override
  Widget build(BuildContext context) {
    if (phone.isEmpty) {
      return const Text('—', style: TextStyle(color: AppTheme.textMuted));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.phone_outlined, size: 13, color: AppTheme.textSecondary),
        const SizedBox(width: 4),
        Text(phone, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}
