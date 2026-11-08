import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:taiwan_brawl/game_modules/archery_hive_progress_backend.dart';
import 'package:taiwan_brawl/game_modules/mini_royale_platform_adapters.dart';
import 'package:taiwan_brawl_game_archery/taiwan_brawl_game_archery.dart';
import 'package:taiwan_brawl_game_mini_royale/taiwan_brawl_game_mini_royale.dart';
import 'package:taiwan_brawl/game_modules/street_scrap_hive_progress_store.dart';
import 'package:taiwan_brawl/services/game_resource_content_store.dart';
import 'package:taiwan_brawl_game_street_scrap/street_scrap_progress.dart';

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

  test('all peer game progress persists in isolated game stores', () async {
    const profileId = 'same-account';
    const streetScrapSlot =
        'game.street-scrap/profile-digest/same-account-digest';
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
    final streetScrap = HiveStreetScrapProgressStore();
    final streetScrapSave = StreetScrapProgressSnapshot.create(
      rulesetVersion: 1,
      contentVersions: const {
        'game.street-scrap.content.chapters-0-4': '0.1.0',
      },
      revision: 1,
      savedAt: DateTime.utc(2026, 10, 27),
      state: const {'marker': 'street-scrap-only'},
      commandReceipts: const {},
    );
    expect(
      await streetScrap.compareAndSwap(
        slotKey: streetScrapSlot,
        expectedRevision: null,
        nextSnapshot: streetScrapSave.toJson(),
      ),
      isTrue,
    );

    expect((await archery.readProgress(profileId)).highScore, 17);
    expect((await royale.readDeckDraft(profileId, 1))?.cardIds, [
      'knight',
      'archer',
    ]);
    expect((await streetScrap.read(streetScrapSlot))!['state'], {
      'marker': 'street-scrap-only',
    });

    final archeryBox = await Hive.openBox<dynamic>('archery_player_data_v1');
    final royaleBox = await Hive.openBox<dynamic>('mini_royale_player_data_v1');
    final streetScrapBox = await Hive.openBox<String>('street_scrap_saves_v1');
    expect(archeryBox.keys, ['profile:$profileId:progress']);
    expect(royaleBox.keys, ['profile:$profileId:deck-draft:1']);
    expect(streetScrapBox.keys, ['save:$streetScrapSlot']);
    expect(archeryBox.get('profile:$profileId:deck-draft:1'), isNull);
    expect(royaleBox.get('profile:$profileId:progress'), isNull);
    expect(streetScrapBox.get('save:profile:$profileId:progress'), isNull);
    expect(streetScrapBox.get('save:profile:$profileId:deck-draft:1'), isNull);
  });

  test(
    'removing one optional game resource preserves every peer save and other resources',
    () async {
      const profileId = 'same-account';
      const streetScrapSlot =
          'game.street-scrap/profile-digest/same-account-digest';
      const streetScrapContent = 'game.street-scrap.content.chapters-0-4';
      const streetScrapArt = 'game.street-scrap.art.material-atlas';
      const archeryContent = 'game.archery.content';

      final archery = ArcheryPlayerDataRepository(
        backend: HiveArcheryPlayerDataBackend(),
      );
      final royale = MiniRoyalePlayerDataRepository(
        backend: HiveMiniRoyalePlayerDataBackend(),
      );
      final streetScrap = HiveStreetScrapProgressStore();
      final snapshot = StreetScrapProgressSnapshot.create(
        rulesetVersion: 1,
        contentVersions: const {streetScrapContent: '0.1.0'},
        revision: 1,
        savedAt: DateTime.utc(2026, 10, 28),
        state: const {'chapter': 2, 'marker': 'keep-player-progress'},
        commandReceipts: const {},
      );

      await archery.writeProgress(
        profileId,
        const ArcheryPlayerProgress(highScore: 31),
      );
      await royale.writeDeckDraft(
        profileId,
        const MiniRoyaleDeckDraft(
          slot: 1,
          name: 'Keep this deck',
          cardIds: ['knight', 'archer'],
          heroId: 'ordinary_person',
        ),
      );
      expect(
        await streetScrap.compareAndSwap(
          slotKey: streetScrapSlot,
          expectedRevision: null,
          nextSnapshot: snapshot.toJson(),
        ),
        isTrue,
      );

      final resources = HiveGameResourceContentStore(
        contentBoxName: 'isolated_resource_content_test',
        pointerBoxName: 'isolated_resource_pointers_test',
      );
      for (final entry in [
        (streetScrapContent, '0.1.0', [1, 2]),
        (streetScrapArt, '0.3.0', [3, 4]),
        (archeryContent, '2.0.0', [5, 6]),
      ]) {
        await resources.writeStaged(
          entry.$1 == archeryContent ? 'game.archery' : 'game.street-scrap',
          entry.$1,
          entry.$2,
          Uint8List.fromList(entry.$3),
        );
        await resources.activate(
          entry.$1 == archeryContent ? 'game.archery' : 'game.street-scrap',
          entry.$1,
          entry.$2,
        );
      }

      await resources.remove('game.street-scrap', streetScrapArt);

      await Hive.close();
      Hive.init(hiveDirectory.path);

      final restoredArchery = ArcheryPlayerDataRepository(
        backend: HiveArcheryPlayerDataBackend(),
      );
      final restoredRoyale = MiniRoyalePlayerDataRepository(
        backend: HiveMiniRoyalePlayerDataBackend(),
      );
      final restoredStreetScrap = HiveStreetScrapProgressStore();
      final restoredResources = HiveGameResourceContentStore(
        contentBoxName: 'isolated_resource_content_test',
        pointerBoxName: 'isolated_resource_pointers_test',
      );

      expect(await restoredResources.readActiveSet('game.street-scrap'), {
        streetScrapContent: '0.1.0',
      });
      expect(
        await restoredResources.readActive(
          'game.street-scrap',
          streetScrapContent,
        ),
        Uint8List.fromList([1, 2]),
      );
      expect(
        await restoredResources.readActive('game.street-scrap', streetScrapArt),
        isNull,
      );
      expect(
        await restoredResources.readActive('game.archery', archeryContent),
        Uint8List.fromList([5, 6]),
      );

      expect((await restoredArchery.readProgress(profileId)).highScore, 31);
      expect(
        (await restoredRoyale.readDeckDraft(profileId, 1))?.name,
        'Keep this deck',
      );
      expect(
        (await restoredStreetScrap.read(streetScrapSlot))!['revision'],
        snapshot.revision,
      );
      expect(
        ((await restoredStreetScrap.read(streetScrapSlot))!['state']
            as Map)['marker'],
        'keep-player-progress',
      );
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
