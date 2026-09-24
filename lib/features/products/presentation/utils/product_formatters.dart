import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

String formatSar(double value) => 'SAR ${value.toStringAsFixed(2)}';

Future<void> copyToClipboard(
  BuildContext context,
  String label,
  String value,
) async {
  await Clipboard.setData(ClipboardData(text: value));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('$label copied')));
}
