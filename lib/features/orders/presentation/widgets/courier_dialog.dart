import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/locale_context.dart';
import '../../../../core/storage/app_preferences.dart';
import '../../../../core/theme/app_theme.dart';
import '../l10n/orders_strings.dart';
import 'orders_dialog_shell.dart';

enum CourierDialogMode { dispatch, deliver, update }

/// Asks for the courier details Keeta shows the customer (self-delivery).
/// Resolves to the `courierInfo` map, an empty map when nothing was filled in
/// and that is allowed, or null when cancelled.
Future<Map<String, Object?>?> showCourierDialog(
  BuildContext context, {
  required CourierDialogMode mode,
}) {
  final preferences = context.read<AppPreferences>();
  return showOrdersDialog<Map<String, Object?>>(
    context,
    builder: (_) => _CourierDialog(mode: mode, preferences: preferences),
  );
}

class _CourierDialog extends StatefulWidget {
  const _CourierDialog({required this.mode, required this.preferences});

  final CourierDialogMode mode;
  final AppPreferences preferences;

  @override
  State<_CourierDialog> createState() => _CourierDialogState();
}

class _CourierDialogState extends State<_CourierDialog> {
  late final Map<String, Object?> _last = widget.preferences.lastCourier;
  late final _name = TextEditingController(
    text: '${_last['courierName'] ?? ''}',
  );
  late final _phone = TextEditingController(
    text: '${_last['courierPhone'] ?? ''}',
  );
  late final _plate = TextEditingController(
    text: '${_last['vehiclePlateNumber'] ?? ''}',
  );
  late int _vehicle = (_last['courierVehicle'] as num?)?.toInt() ?? 3;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _plate.dispose();
    super.dispose();
  }

  Map<String, Object?> _info() => {
    if (_name.text.trim().isNotEmpty) 'courierName': _name.text.trim(),
    if (_phone.text.trim().isNotEmpty) ...{
      'courierPhone': _phone.text.trim(),
      'courierPhoneInterCode': '966',
    },
    'courierVehicle': _vehicle,
    if (_plate.text.trim().isNotEmpty) 'vehiclePlateNumber': _plate.text.trim(),
  };

  Future<void> _submit() async {
    final info = _info();
    final hasDetail =
        _name.text.trim().isNotEmpty ||
        _phone.text.trim().isNotEmpty ||
        _plate.text.trim().isNotEmpty;
    // Dispatch and update need something to show the customer; delivery doesn't.
    if (!hasDetail && widget.mode != CourierDialogMode.deliver) {
      setState(() => _error = context.ordersStrings.courierNeedsOne);
      return;
    }
    if (hasDetail) await widget.preferences.setLastCourier(info);
    if (!mounted) return;
    Navigator.of(context).pop(hasDetail ? info : <String, Object?>{});
  }

  @override
  Widget build(BuildContext context) {
    final s = context.ordersStrings;
    final (subtitle, confirm, icon) = switch (widget.mode) {
      CourierDialogMode.dispatch => (
        s.courierDispatchSubtitle,
        s.courierConfirmDispatch,
        Icons.two_wheeler_rounded,
      ),
      CourierDialogMode.deliver => (
        s.courierDeliverSubtitle,
        s.courierConfirmDeliver,
        Icons.task_alt_rounded,
      ),
      CourierDialogMode.update => (
        s.courierUpdateSubtitle,
        s.courierConfirmUpdate,
        Icons.badge_outlined,
      ),
    };
    final vehicles = [
      (1, Icons.directions_walk_rounded, s.vehicleWalking),
      (2, Icons.pedal_bike_rounded, s.vehicleBicycle),
      (3, Icons.two_wheeler_rounded, s.vehicleMotorcycle),
      (4, Icons.directions_car_rounded, s.vehicleCar),
    ];

    return OrdersDialogShell(
      icon: icon,
      title: s.courierDialogTitle,
      subtitle: subtitle,
      maxWidth: 520,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.commonStrings.cancel),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: _submit,
          icon: Icon(icon, size: 18),
          label: Text(confirm),
          style: dialogButtonStyle,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _name,
            decoration: InputDecoration(
              labelText: s.courierName,
              prefixIcon: const Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: s.courierPhone,
              prefixIcon: const Icon(Icons.phone_outlined),
              prefixText: '+966  ',
            ),
          ),
          const SizedBox(height: 16),
          Text(
            s.courierVehicle,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (value, vehicleIcon, label) in vehicles)
                ChoiceChip(
                  avatar: Icon(
                    vehicleIcon,
                    size: 18,
                    color: _vehicle == value
                        ? Colors.white
                        : AppTheme.textSecondary,
                  ),
                  label: Text(label),
                  selected: _vehicle == value,
                  showCheckmark: false,
                  selectedColor: AppTheme.primary,
                  labelStyle: TextStyle(
                    color: _vehicle == value
                        ? Colors.white
                        : AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                  onSelected: (_) => setState(() => _vehicle = value),
                ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _plate,
            decoration: InputDecoration(
              labelText: s.courierPlate,
              prefixIcon: const Icon(Icons.pin_outlined),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            alignment: Alignment.topCenter,
            child: _error == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: AppTheme.coral,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
