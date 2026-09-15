/// Minimal relative-time formatter — avoids pulling in intl/timeago for one
/// string.
String timeAgo(DateTime time) {
  final diff = DateTime.now().difference(time);

  if (diff.inSeconds < 5) return 'just now';
  if (diff.inMinutes < 1) return '${diff.inSeconds}s ago';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';

  final d = time.toLocal();
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
