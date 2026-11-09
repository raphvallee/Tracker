const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

int _daysBetween(DateTime from, DateTime to) => DateTime(
  to.year,
  to.month,
  to.day,
).difference(DateTime(from.year, from.month, from.day)).inDays;

/// "today", "yesterday", a weekday within the last week, else "Mar 3"
/// (with the year when it is not this year's).
String dayLabel(DateTime date, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final days = _daysBetween(date, today);
  if (days <= 0) return 'today';
  if (days == 1) return 'yesterday';
  if (days < 7) return _weekdays[date.weekday - 1];
  final month = '${_months[date.month - 1]} ${date.day}';
  return date.year == today.year ? month : '$month, ${date.year}';
}

/// "today", "yesterday", "3 days ago", "2 weeks ago", "5 months ago".
String agoLabel(DateTime date, {DateTime? now}) {
  final days = _daysBetween(date, now ?? DateTime.now());
  if (days <= 0) return 'today';
  if (days == 1) return 'yesterday';
  if (days < 14) return '$days days ago';
  if (days < 60) return '${days ~/ 7} weeks ago';
  if (days < 730) return '${days ~/ 30} months ago';
  return '${days ~/ 365} years ago';
}
