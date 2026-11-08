/// A server-confirmed relationship. The date is a calendar date, not an instant.
class CoupleRelationship {
  const CoupleRelationship({
    required this.id,
    required this.partnerUserId,
    required this.startedOn,
    required this.status,
    required this.version,
    required this.updatedAt,
    this.endedAt,
    this.partnerName,
  });

  final String id;
  final int partnerUserId;
  final String startedOn;
  final String status;
  final int version;
  final DateTime updatedAt;
  final DateTime? endedAt;
  final String? partnerName;

  factory CoupleRelationship.fromJson(Map<String, dynamic> json) {
    final date = json['startedOn'] as String;
    final parts = date.split('-');
    if (parts.length != 3 || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) {
      throw const FormatException('Invalid relationship date');
    }
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final day = int.parse(parts[2]);
    final parsed = DateTime.utc(year, month, day);
    if (year < 1900 ||
        parsed.year != year ||
        parsed.month != month ||
        parsed.day != day) {
      throw const FormatException('Invalid relationship date');
    }
    final status = json['status'] as String;
    if (status != 'active' && status != 'ended') {
      throw const FormatException('Invalid relationship status');
    }
    if ((json['partnerUserId'] as int) <= 0 ||
        (json['version'] as int) <= 0 ||
        (json['id'] as String).isEmpty) {
      throw const FormatException('Invalid relationship identity');
    }
    return CoupleRelationship(
      id: json['id'] as String,
      partnerUserId: json['partnerUserId'] as int,
      startedOn: date,
      status: status,
      version: json['version'] as int,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      endedAt: json['endedAt'] == null
          ? null
          : DateTime.parse(json['endedAt'] as String),
      partnerName: json['partnerName'] as String?,
    );
  }

  int dayCount(DateTime localToday) {
    if (status != 'active') throw StateError('Relationship is not active');
    final parts = startedOn.split('-').map(int.parse).toList();
    final start = DateTime.utc(parts[0], parts[1], parts[2]);
    final today = DateTime.utc(
      localToday.year,
      localToday.month,
      localToday.day,
    );
    final days = today.difference(start).inDays + 1;
    return days < 1 ? 1 : days;
  }
}
