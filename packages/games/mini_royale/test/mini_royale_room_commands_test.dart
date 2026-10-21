import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl_game_mini_royale/taiwan_brawl_game_mini_royale.dart';

void main() {
  test('encodes game play and discard actions as room wire commands', () {
    final play = MiniRoyalePlayCommand(
      cards: const [],
      cardIds: const ['unit-1', 'spell-2'],
      dropX: 0.4,
      dropY: 0.3,
      lanePosition: 0.6,
    );

    expect(MiniRoyaleRoomCommandCodec.encodePlayCombo(play), {
      'type': 'play_combo',
      'cardIds': ['unit-1', 'spell-2'],
      'lanePosition': 0.6,
      'dropX': 0.4,
      'dropY': 0.3,
    });
    expect(MiniRoyaleRoomCommandCodec.encodeDiscardCard('unit-1'), {
      'type': 'discard_card',
      'cardId': 'unit-1',
    });
  });

  test(
    'decodes typed host commands and rejects malformed or unknown commands',
    () {
      expect(
        MiniRoyaleRoomCommandCodec.decodeHostCommand({
          'type': 'discard_card',
          'side': 'right',
          'cardId': 'unit-1',
        }),
        isA<MiniRoyaleRemoteDiscardCommand>()
            .having((command) => command.side, 'side', 'right')
            .having((command) => command.cardId, 'cardId', 'unit-1'),
      );
      expect(
        MiniRoyaleRoomCommandCodec.decodeHostCommand({
          'type': 'play_combo',
          'side': 'right',
          'cardIds': ['unit-1'],
          'dropX': 0.25,
          'dropY': 0.5,
        }),
        isA<MiniRoyaleRemotePlayCommand>()
            .having((command) => command.cardIds, 'cardIds', ['unit-1'])
            .having((command) => command.dropX, 'dropX', 0.25)
            .having((command) => command.dropY, 'dropY', 0.5),
      );
      expect(
        MiniRoyaleRoomCommandCodec.decodeHostCommand({
          'type': 'play_combo',
          'cardIds': ['unit-1'],
          'dropX': double.nan,
          'dropY': 0.5,
        }),
        isNull,
      );
      expect(
        MiniRoyaleRoomCommandCodec.decodeHostCommand({'type': 'unknown'}),
        isNull,
      );
    },
  );
}
