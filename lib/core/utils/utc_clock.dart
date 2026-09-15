/// Formats a Keeta UTC clock string ("HH:mm" / "HH:mm:ss") into local time.
String formatUtcClockLocal(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '—';
  final parts = raw.trim().split(':');
  if (parts.length < 2) return raw;

  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return raw;

  final local = DateTime.utc(2000, 1, 1, hour, minute).toLocal();
  final h = local.hour.toString().padLeft(2, '0');
  final m = local.minute.toString().padLeft(2, '0');
  return '$h:$m';
}
