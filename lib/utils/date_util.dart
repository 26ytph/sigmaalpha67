String toLocalDateString([DateTime? d]) {
  final x = d ?? DateTime.now();
  final y = x.year.toString().padLeft(4, '0');
  final m = x.month.toString().padLeft(2, '0');
  final day = x.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

String addDays(String dateString, int days) {
  final parts = dateString.split('-').map(int.parse).toList();
  final dt = DateTime(parts[0], parts[1], parts[2]);
  final next = dt.add(Duration(days: days));
  return toLocalDateString(next);
}

bool isYesterday(String? prev, [String? today]) {
  final t = today ?? toLocalDateString();
  if (prev == null || prev.isEmpty) return false;
  return prev == addDays(t, -1);
}
