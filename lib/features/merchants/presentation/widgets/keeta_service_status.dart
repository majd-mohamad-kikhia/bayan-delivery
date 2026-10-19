import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/localization/locale_context.dart';
import '../../../../core/platforms/platforms.dart';
import '../../../../core/theme/app_theme.dart';

/// Keeta tracks **delivery** and **pickup** separately (`deliveryRestStatus`,
/// `pickupRestStatus`): 0 = not offered, 1 = available, 2 = unavailable.
/// Read from the store details. Keeta's suspend / reactivate calls change both
/// together, so this is a read-only view: splitting them needs Keeta's
/// dashboard.
class KeetaServiceStatus extends StatefulWidget {
  const KeetaServiceStatus({super.key, required this.shopId});

  final int shopId;

  @override
  State<KeetaServiceStatus> createState() => _KeetaServiceStatusState();
}

class _KeetaServiceStatusState extends State<KeetaServiceStatus> {
  late Future<Map<String, dynamic>> _details = _load();

  Future<Map<String, dynamic>> _load() =>
      context.read<PlatformApis>().keeta.shop.details(widget.shopId);

  @override
  Widget build(BuildContext context) {
    String t(String en, String ar) => context.isArabic ? ar : en;
    return FutureBuilder<Map<String, dynamic>>(
      future: _details,
      builder: (context, snapshot) {
        final data = snapshot.data;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      t('Delivery & pickup', 'التوصيل والاستلام'),
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: t('Refresh', 'تحديث'),
                    onPressed: () => setState(() => _details = _load()),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (snapshot.connectionState != ConnectionState.done)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(minHeight: 2),
                )
              else if (data == null || snapshot.hasError)
                Text(
                  t('Could not read the status from Keeta', 'تعذّرت قراءة الحالة من كيتا'),
                  style: const TextStyle(color: AppTheme.coral, fontSize: 12.5),
                )
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: _ServiceChip(
                        icon: Icons.delivery_dining_rounded,
                        label: t('Delivery', 'التوصيل'),
                        status: (data['deliveryRestStatus'] as num?)?.toInt(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ServiceChip(
                        icon: Icons.shopping_bag_outlined,
                        label: t('Pickup', 'الاستلام'),
                        status: (data['pickupRestStatus'] as num?)?.toInt(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  t(
                    'Keeta changes delivery and pickup together from here. To split them, use the Keeta dashboard.',
                    'كيتا تغيّر التوصيل والاستلام معاً من هنا. لفصلهما استخدم لوحة تحكم كيتا.',
                  ),
                  style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted, height: 1.4),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ServiceChip extends StatelessWidget {
  const _ServiceChip({required this.icon, required this.label, required this.status});

  final IconData icon;
  final String label;

  /// 0 not offered, 1 available, 2 unavailable, null unknown.
  final int? status;

  @override
  Widget build(BuildContext context) {
    String t(String en, String ar) => context.isArabic ? ar : en;
    final (color, text) = switch (status) {
      1 => (const Color(0xFF16A34A), t('Available', 'متاح')),
      2 => (AppTheme.coral, t('Unavailable', 'غير متاح')),
      0 => (AppTheme.textMuted, t('Not offered', 'غير مفعّل')),
      _ => (AppTheme.textMuted, t('Unknown', 'غير معروف')),
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                Text(text, style: TextStyle(fontWeight: FontWeight.w800, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
