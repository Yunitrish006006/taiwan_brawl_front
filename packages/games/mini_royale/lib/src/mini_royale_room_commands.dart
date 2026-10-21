import 'battle_selection.dart';

/// Mini Royale's real-time room command wire format. Transport stays host-owned;
/// game-specific command vocabulary and payload fields stay in this package.
class MiniRoyaleRoomCommandCodec {
  const MiniRoyaleRoomCommandCodec._();

  static Map<String, Object> encodePlayCombo(MiniRoyalePlayCommand command) => {
    'type': 'play_combo',
    'cardIds': command.cardIds,
    'lanePosition': command.lanePosition,
    'dropX': command.dropX,
    'dropY': command.dropY,
  };

  static Map<String, Object> encodeDiscardCard(String cardId) => {
    'type': 'discard_card',
    'cardId': cardId,
  };

  static MiniRoyaleRemoteRoomCommand? decodeHostCommand(
    Map<String, dynamic>? json,
  ) {
    if (json == null) return null;
    final side = json['side'];
    if (side != null && side is! String) return null;
    switch (json['type']) {
      case 'discard_card':
        final cardId = json['cardId'];
        if (cardId is! String || cardId.isEmpty) return null;
        return MiniRoyaleRemoteDiscardCommand(
          side: side as String? ?? 'right',
          cardId: cardId,
        );
      case 'play_combo':
        final rawIds = json['cardIds'];
        final dropX = json['dropX'];
        final dropY = json['dropY'];
        if (rawIds is! List ||
            rawIds.isEmpty ||
            rawIds.any((id) => id is! String) ||
            dropX is! num ||
            dropY is! num ||
            !dropX.toDouble().isFinite ||
            !dropY.toDouble().isFinite) {
          return null;
        }
        return MiniRoyaleRemotePlayCommand(
          side: side as String? ?? 'right',
          cardIds: List<String>.unmodifiable(rawIds.cast<String>()),
          dropX: dropX.toDouble(),
          dropY: dropY.toDouble(),
        );
      default:
        return null;
    }
  }
}

sealed class MiniRoyaleRemoteRoomCommand {
  const MiniRoyaleRemoteRoomCommand({required this.side});

  final String side;
}

final class MiniRoyaleRemoteDiscardCommand extends MiniRoyaleRemoteRoomCommand {
  const MiniRoyaleRemoteDiscardCommand({
    required super.side,
    required this.cardId,
  });

  final String cardId;
}

final class MiniRoyaleRemotePlayCommand extends MiniRoyaleRemoteRoomCommand {
  const MiniRoyaleRemotePlayCommand({
    required super.side,
    required this.cardIds,
    required this.dropX,
    required this.dropY,
  });

  final List<String> cardIds;
  final double dropX;
  final double dropY;
}
