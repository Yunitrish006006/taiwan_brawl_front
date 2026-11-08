/// Stable paging position for history rows that may share a timestamp.
class MessageHistoryCursor {
  const MessageHistoryCursor({required this.createdAt, required this.rowId});

  final String createdAt;
  final int rowId;

  factory MessageHistoryCursor.fromJson(Map<String, dynamic> json) {
    final createdAt = json['createdAt'];
    final rowId = json['id'];
    if (createdAt is! String || rowId is! num || !rowId.isFinite) {
      throw const FormatException('History cursor is invalid.');
    }
    return MessageHistoryCursor(createdAt: createdAt, rowId: rowId.toInt());
  }

  Map<String, Object?> toJson() => {'createdAt': createdAt, 'id': rowId};

  @override
  bool operator ==(Object other) =>
      other is MessageHistoryCursor &&
      other.createdAt == createdAt &&
      other.rowId == rowId;

  @override
  int get hashCode => Object.hash(createdAt, rowId);
}

/// A chronological history page and its opaque continuation state.
class MessageHistoryPage<T> {
  MessageHistoryPage({
    required List<T> messages,
    required this.hasMore,
    required this.nextCursor,
  }) : messages = List.unmodifiable(messages) {
    if (hasMore != (nextCursor != null)) {
      throw ArgumentError('A continuing history page must include a cursor.');
    }
  }

  final List<T> messages;
  final bool hasMore;
  final MessageHistoryCursor? nextCursor;
}
