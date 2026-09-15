import 'package:flutter/material.dart';

Future<String?> showDongleSettingsDialog(BuildContext context, {required String current}) {
  final controller = TextEditingController(text: current);

  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Restaurant dongle'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Dongle number',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final value = controller.text.trim();
            Navigator.of(context).pop(value.isEmpty ? null : value);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
