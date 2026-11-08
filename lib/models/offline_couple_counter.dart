/// A display projection only. It deliberately has no account/relationship ID.
class OfflineCoupleCounter {
  const OfflineCoupleCounter({
    required this.startedOn,
    required this.lastSyncedAt,
  });
  final String startedOn;
  final DateTime lastSyncedAt;
  factory OfflineCoupleCounter.fromJson(Map<String, dynamic> json) {
    if (json.length != 3 ||
        json['schemaVersion'] != 1 ||
        !json.keys.every(
          {'schemaVersion', 'startedOn', 'lastSyncedAt'}.contains,
        )) {
      throw const FormatException('Invalid offline counter projection');
    }
    final date = json['startedOn'] as String;
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) {
      throw const FormatException('Invalid start date');
    }
    final parts = date.split('-').map(int.parse).toList();
    final value = DateTime.utc(parts[0], parts[1], parts[2]);
    if (parts[0] < 1900 ||
        value.year != parts[0] ||
        value.month != parts[1] ||
        value.day != parts[2]) {
      throw const FormatException('Invalid start date');
    }
    return OfflineCoupleCounter(
      startedOn: date,
      lastSyncedAt: DateTime.parse(json['lastSyncedAt'] as String),
    );
  }
  int dayCount(DateTime localToday) {
    final parts = startedOn.split('-').map(int.parse).toList();
    final days =
        DateTime.utc(
          localToday.year,
          localToday.month,
          localToday.day,
        ).difference(DateTime.utc(parts[0], parts[1], parts[2])).inDays +
        1;
    return days < 1 ? 1 : days;
  }
}
