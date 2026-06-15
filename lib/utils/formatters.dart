String formatPlaytime(int minutes) {
  if (minutes <= 0) {
    return '0h';
  }
  final hours = minutes / 60;
  if (hours < 10) {
    return '${hours.toStringAsFixed(1)}h';
  }
  return '${hours.round()}h';
}

String formatDateTime(DateTime? value) {
  if (value == null) {
    return '从未同步';
  }
  final local = value.toLocal();
  return '${local.year}-${_two(local.month)}-${_two(local.day)} '
      '${_two(local.hour)}:${_two(local.minute)}';
}

String formatLastPlayed(DateTime value) {
  if (value.millisecondsSinceEpoch <= 0) {
    return '未玩过';
  }
  final local = value.toLocal();
  return '${local.year}-${_two(local.month)}-${_two(local.day)}';
}

String formatCompactNumber(int value) {
  if (value >= 10000) {
    final wan = value / 10000;
    return '${wan.toStringAsFixed(wan >= 10 ? 0 : 1)}万';
  }
  return '$value';
}

String formatReviewLabel(String value) {
  return switch (value) {
    'Overwhelmingly Positive' => '好评如潮',
    'Very Positive' => '特别好评',
    'Positive' => '好评',
    'Mostly Positive' => '多半好评',
    'Mixed' => '褒贬不一',
    'Mostly Negative' => '多半差评',
    'Negative' => '差评',
    'Very Negative' => '特别差评',
    'Overwhelmingly Negative' => '差评如潮',
    _ => value,
  };
}

String _two(int value) => value.toString().padLeft(2, '0');
