/// 格式化时长（秒 → mm:ss 或 h:mm:ss）
String formatDuration(int totalSeconds) {
  final h = totalSeconds ~/ 3600;
  final m = (totalSeconds % 3600) ~/ 60;
  final s = totalSeconds % 60;
  if (h > 0) {
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// 格式化 Duration 对象
String formatPositionDuration(Duration duration) {
  return formatDuration(duration.inSeconds);
}

/// Nullable variant — returns empty string when [totalSeconds] is null.
String formatDurationOrEmpty(int? totalSeconds) =>
    totalSeconds != null ? formatDuration(totalSeconds) : '';
