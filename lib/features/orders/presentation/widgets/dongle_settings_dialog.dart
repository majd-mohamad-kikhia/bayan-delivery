import 'package:flutter/material.dart';

import '../../../../core/localization/locale_context.dart';
import '../l10n/orders_strings.dart';

Future<String?> showDongleSettingsDialog(BuildContext context, {required String current}) {
  final controller = TextEditingController(text: current);

  return showDialog<String>(
    context: context,
    builder: (context) {
      final s = context.ordersStrings;
      final common = context.commonStrings;
      return AlertDialog(
        title: Text(s.dongleDialogTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: s.dongleNumber,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(common.cancel),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              Navigator.of(context).pop(value.isEmpty ? null : value);
            },
            child: Text(common.save),
          ),
        ],
      );
    },
  );
}
