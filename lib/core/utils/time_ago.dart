import '../localization/common_strings.dart';

/// Minimal relative-time formatter — avoids pulling in intl/timeago for one
/// string.
String timeAgo(DateTime time, CommonStrings strings) {
  final diff = DateTime.now().difference(time);

  if (diff.inSeconds < 5) return strings.justNow;
  if (diff.inMinutes < 1) return strings.secondsAgo(diff.inSeconds);
  if (diff.inHours < 1) return strings.minutesAgo(diff.inMinutes);
  if (diff.inDays < 1) return strings.hoursAgo(diff.inHours);
  if (diff.inDays < 7) return strings.daysAgo(diff.inDays);

  final d = time.toLocal();
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
