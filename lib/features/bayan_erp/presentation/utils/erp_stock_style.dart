import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/erp_product_model.dart';

extension ErpStockLevelStyle on ErpStockLevel {
  String get label => switch (this) {
        ErpStockLevel.available => 'In stock',
        ErpStockLevel.low => 'Low stock',
        ErpStockLevel.out => 'Out of stock',
      };

  Color get color => switch (this) {
        ErpStockLevel.available => const Color(0xFF16A34A),
        ErpStockLevel.low => const Color(0xFFF59E0B),
        ErpStockLevel.out => AppTheme.coral,
      };

  IconData get icon => switch (this) {
        ErpStockLevel.available => Icons.check_circle_rounded,
        ErpStockLevel.low => Icons.warning_amber_rounded,
        ErpStockLevel.out => Icons.remove_circle_rounded,
      };
}
