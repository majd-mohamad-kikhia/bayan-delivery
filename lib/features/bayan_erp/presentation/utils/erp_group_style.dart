import 'package:flutter/material.dart';

/// Stable colour + icon per product group, so rows from the same group match.
class ErpGroupStyle {
  const ErpGroupStyle(this.background, this.foreground, this.icon);

  final Color background;
  final Color foreground;
  final IconData icon;

  static const _palette = [
    ErpGroupStyle(Color(0xFFF1F5F9), Color(0xFF475569), Icons.inventory_2_outlined),
    ErpGroupStyle(Color(0xFFEFF6FF), Color(0xFF2563EB), Icons.category_outlined),
    ErpGroupStyle(Color(0xFFFFFBEB), Color(0xFFD97706), Icons.handyman_outlined),
    ErpGroupStyle(Color(0xFFF5F3FF), Color(0xFF7C3AED), Icons.science_outlined),
    ErpGroupStyle(Color(0xFFECFDF5), Color(0xFF059669), Icons.local_offer_outlined),
    ErpGroupStyle(Color(0xFFFDF2F8), Color(0xFFDB2777), Icons.shopping_bag_outlined),
    ErpGroupStyle(Color(0xFFECFEFF), Color(0xFF0891B2), Icons.widgets_outlined),
  ];

  static ErpGroupStyle of(int groupId) => _palette[groupId.abs() % _palette.length];
}
