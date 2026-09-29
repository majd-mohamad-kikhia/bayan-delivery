abstract final class ErpFormatters {
  /// Whole number with thousands separators, e.g. `7500` → `7,500`.
  static String amount(num value) {
    final digits = value.abs().round().toString();
    final buffer = StringBuffer(value < 0 ? '-' : '');
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  static String quantity(double value) =>
      value == value.truncateToDouble() ? amount(value) : value.toStringAsFixed(2);
}
