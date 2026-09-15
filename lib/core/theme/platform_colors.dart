import 'package:flutter/material.dart';

/// Central place for platform branding so a new delivery platform (Careem,
/// etc.) is a one-line addition, not a hunt through every widget.
class PlatformColors {
  const PlatformColors._();

  static const List<String> all = ['keeta', 'hungerstation', 'careem'];

  static const Map<String, Color> _colors = {
    'keeta': Color(0xFF6D28D9),
    'hungerstation': Color(0xFFEA580C),
    'careem': Color(0xFF00A651),
  };

  static const Color _fallback = Color(0xFF475569);

  static Color of(String platform) => _colors[platform] ?? _fallback;

  static String label(String platform) {
    switch (platform) {
      case 'keeta':
        return 'Keeta';
      case 'hungerstation':
        return 'HungerStation';
      case 'careem':
        return 'Careem';
      default:
        return platform;
    }
  }
}
