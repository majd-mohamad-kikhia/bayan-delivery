import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/localization/locale_context.dart';
import '../../../../core/widgets/app_snack_bar.dart';

Future<void> copyToClipboard(
  BuildContext context,
  String label,
  String value,
) async {
  await Clipboard.setData(ClipboardData(text: value));
  if (!context.mounted) return;
  AppSnackBar.success(context, context.commonStrings.copied(label));
}
