import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:taiwan_brawl/game_modules/archery_hive_progress_backend.dart';
import 'package:taiwan_brawl/game_modules/mini_royale_platform_adapters.dart';
import 'package:taiwan_brawl_game_archery/taiwan_brawl_game_archery.dart';
import 'package:taiwan_brawl_game_mini_royale/taiwan_brawl_game_mini_royale.dart';

void main() {
  late Directory hiveDirectory;

  setUp(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'taiwan-brawl-game-data-',
    );
    Hive.init(hiveDirectory.path);
  });

  tearDown(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  test(
    'Archery and Mini Royale data persist in isolated game stores',
    () async {
      const profileId = 'same-account';
      final archery = ArcheryPlayerDataRepository(
        backend: HiveArcheryPlayerDataBackend(),
      );
      final royale = MiniRoyalePlayerDataRepository(
        backend: HiveMiniRoyalePlayerDataBackend(),
      );

      await archery.writeProgress(
        profileId,
        const ArcheryPlayerProgress(highScore: 17),
      );
      await royale.writeDeckDraft(
        profileId,
        const MiniRoyaleDeckDraft(
          slot: 1,
          name: 'Local Draft',
          cardIds: ['knight', 'archer'],
          heroId: 'ordinary_person',
        ),
      );

      expect((await archery.readProgress(profileId)).highScore, 17);
      expect((await royale.readDeckDraft(profileId, 1))?.cardIds, [
        'knight',
        'archer',
      ]);

      final archeryBox = await Hive.openBox<dynamic>('archery_player_data_v1');
      final royaleBox = await Hive.openBox<dynamic>(
        'mini_royale_player_data_v1',
      );
      expect(archeryBox.keys, ['profile:$profileId:progress']);
      expect(royaleBox.keys, ['profile:$profileId:deck-draft:1']);
      expect(archeryBox.get('profile:$profileId:deck-draft:1'), isNull);
      expect(royaleBox.get('profile:$profileId:progress'), isNull);
    },
  );

  test('Hive adapter keeps a malformed legacy draft for recovery', () async {
    const key = 'profile:recoverable:deck-draft:1';
    final box = await Hive.openBox<dynamic>('mini_royale_player_data_v1');
    final legacy = <String, Object?>{
      'schemaVersion': 0,
      'data': {
        'slot': 1,
        'name': 'Needs repair',
        'cards': ['valid', 42],
      },
    };
    await box.put(key, legacy);
    final repository = MiniRoyalePlayerDataRepository(
      backend: HiveMiniRoyalePlayerDataBackend(),
    );

    await expectLater(
      repository.readDeckDraft('recoverable', 1),
      throwsFormatException,
    );

    expect(box.get(key), legacy);
  });

  test(
    'Hive adapter rejects profile data stored under the wrong slot',
    () async {
      const key = 'profile:recoverable:deck-draft:1';
      final box = await Hive.openBox<dynamic>('mini_royale_player_data_v1');
      final mismatched = <String, Object?>{
        'schemaVersion': 0,
        'data': {
          'slot': 2,
          'name': 'Wrong slot',
          'cards': ['valid'],
        },
      };
      await box.put(key, mismatched);
      final repository = MiniRoyalePlayerDataRepository(
        backend: HiveMiniRoyalePlayerDataBackend(),
      );

      await expectLater(
        repository.readDeckDraft('recoverable', 1),
        throwsFormatException,
      );

      expect(box.get(key), mismatched);
    },
  );
}
