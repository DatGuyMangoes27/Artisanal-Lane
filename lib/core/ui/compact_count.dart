/// Social-style count: 999, 1.2k, 12k, 1.2M.
String formatCompactCount(int count) {
  if (count < 1000) return '$count';
  String scaled(double value, String suffix) {
    final text = value >= 10
        ? value.floor().toString()
        : value.toStringAsFixed(1);
    return '${text.endsWith('.0') ? text.substring(0, text.length - 2) : text}$suffix';
  }

  if (count < 1000000) return scaled((count / 100).floor() / 10, 'k');
  return scaled((count / 100000).floor() / 10, 'M');
}

/// Short relative time for comments and posts: now, 5m, 3h, 2d, 4w, then a date.
String formatRelativeTime(DateTime time, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final diff = reference.difference(time.toLocal());
  if (diff.inMinutes < 1) return 'now';
  if (diff.inHours < 1) return '${diff.inMinutes}m';
  if (diff.inDays < 1) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  if (diff.inDays < 35) return '${diff.inDays ~/ 7}w';
  const months = [
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
  final local = time.toLocal();
  final label = '${local.day} ${months[local.month - 1]}';
  return local.year == reference.year ? label : '$label ${local.year}';
}
