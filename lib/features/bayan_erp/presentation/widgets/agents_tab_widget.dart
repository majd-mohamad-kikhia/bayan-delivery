import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/agent_model.dart';
import '../bloc/bayan_erp_bloc.dart';
import '../bloc/bayan_erp_state.dart';
import '_erp_table_shell.dart';

/// Tab content that displays registered clients (agents).
class AgentsTabWidget extends StatelessWidget {
  const AgentsTabWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BayanErpBloc, BayanErpState>(
      buildWhen: (p, c) =>
          p.agentsStatus != c.agentsStatus ||
          p.agents != c.agents ||
          p.agentsError != c.agentsError,
      builder: (context, state) => ErpTableShell(
        status: state.agentsStatus,
        error: state.agentsError,
        isEmpty: state.agents.isEmpty,
        emptyLabel: 'No agents found',
        child: _AgentsTable(rows: state.agents),
      ),
    );
  }
}

class _AgentsTable extends StatelessWidget {
  const _AgentsTable({required this.rows});

  final List<AgentModel> rows;

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
            DataColumn(label: Text('Gender')),
            DataColumn(label: Text('Points'), numeric: true),
            DataColumn(label: Text('Birthday')),
          ],
          rows: [
            for (final a in rows)
              DataRow(cells: [
                DataCell(Text('${a.id}', style: _monoStyle)),
                DataCell(_ArabicText(a.name)),
                DataCell(_PhoneCell(a.phone)),
                DataCell(
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 180),
                    child: Text(
                      a.address.isEmpty ? '—' : a.address,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(_GenderBadge(a.gender)),
                DataCell(_PointsCell(a.totalPoints)),
                DataCell(_DateCell(a.birthday)),
              ]),
          ],
        ),
      ),
    );
  }
}

const _monoStyle = TextStyle(
  fontFamily: 'monospace',
  fontSize: 12,
  color: AppTheme.textSecondary,
);

class _ArabicText extends StatelessWidget {
  const _ArabicText(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 200),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Text(text, overflow: TextOverflow.ellipsis),
        ),
      );
}

class _PhoneCell extends StatelessWidget {
  const _PhoneCell(this.phone);
  final String phone;

  @override
  Widget build(BuildContext context) {
    if (phone.isEmpty) return const Text('—', style: TextStyle(color: AppTheme.textMuted));
    return Text(phone, style: const TextStyle(fontSize: 12));
  }
}

class _GenderBadge extends StatelessWidget {
  const _GenderBadge(this.gender);
  final int gender;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (gender) {
      1 => ('Male', const Color(0xFF3B82F6)),
      2 => ('Female', const Color(0xFFEC4899)),
      _ => ('—', AppTheme.textMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _PointsCell extends StatelessWidget {
  const _PointsCell(this.points);
  final double? points;

  @override
  Widget build(BuildContext context) {
    if (points == null) return const Text('—', style: TextStyle(color: AppTheme.textMuted));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, size: 13, color: Color(0xFFF59E0B)),
        const SizedBox(width: 3),
        Text(points!.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _DateCell extends StatelessWidget {
  const _DateCell(this.date);
  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    if (date == null) return const Text('—', style: TextStyle(color: AppTheme.textMuted));
    return Text(
      '${date!.year}-${date!.month.toString().padLeft(2, '0')}-${date!.day.toString().padLeft(2, '0')}',
      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
    );
  }
}
