import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl_game_mini_royale/taiwan_brawl_game_mini_royale.dart';

class MemoryBackend implements MiniRoyalePlayerDataBackend {
  final values = <String, Object>{};

  @override
  Future<Object?> read(String key) async => values[key];

  @override
  Future<void> write(String key, Object value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

void main() {
  group('MiniRoyalePlayerDataRepository', () {
    test(
      'a delayed schema migration cannot overwrite a concurrent save',
      () async {
        final backend = DelayedReadBackend()
          ..values['profile:p:deck-draft:1'] = {
            'schemaVersion': 0,
            'data': {
              'slot': 1,
              'name': 'Legacy',
              'cards': ['old-card'],
            },
          };
        final repository = MiniRoyalePlayerDataRepository(backend: backend);

        final migrationRead = repository.readDeckDraft('p', 1);
        await backend.readStarted.future;
        final secondRepository = MiniRoyalePlayerDataRepository(
          backend: backend,
        );
        final save = secondRepository.writeDeckDraft(
          'p',
          const MiniRoyaleDeckDraft(
            slot: 1,
            name: 'New draft',
            cardIds: ['new-card'],
            heroId: 'hero',
          ),
        );
        await Future<void>.delayed(Duration.zero);
        backend.releaseRead.complete();

        expect((await migrationRead)?.cardIds, ['old-card']);
        await save;
        expect((await repository.readDeckDraft('p', 1))?.cardIds, ['new-card']);
      },
    );

    test(
      'a delayed schema migration cannot resurrect a concurrent delete',
      () async {
        final backend = DelayedReadBackend()
          ..values['profile:p:deck-draft:1'] = {
            'schemaVersion': 0,
            'data': {
              'slot': 1,
              'name': 'Legacy',
              'cards': ['old-card'],
            },
          };
        final repository = MiniRoyalePlayerDataRepository(backend: backend);

        final migrationRead = repository.readDeckDraft('p', 1);
        await backend.readStarted.future;
        final deletionRepository = MiniRoyalePlayerDataRepository(
          backend: backend,
        );
        final deletion = deletionRepository.deleteDeckDraft('p', 1);
        await Future<void>.delayed(Duration.zero);
        backend.releaseRead.complete();

        expect((await migrationRead)?.cardIds, ['old-card']);
        await deletion;
        expect(backend.values, isNot(contains('profile:p:deck-draft:1')));
      },
    );

    test('keeps drafts isolated by player profile', () async {
      final repository = MiniRoyalePlayerDataRepository(
        backend: MemoryBackend(),
      );
      const draft = MiniRoyaleDeckDraft(
        slot: 1,
        name: 'Offline draft',
        cardIds: ['a', 'b'],
        heroId: 'hero',
      );

      await repository.writeDeckDraft('player-a', draft);

      expect(await repository.readDeckDraft('player-a', 1), isNotNull);
      expect(await repository.readDeckDraft('player-b', 1), isNull);
    });

    test('migrates schema zero card list and writes current schema', () async {
      final backend = MemoryBackend()
        ..values['profile:p:deck-draft:2'] = {
          'schemaVersion': 0,
          'data': {
            'slot': 2,
            'name': 'Legacy',
            'cards': ['x'],
          },
        };
      final repository = MiniRoyalePlayerDataRepository(backend: backend);

      final draft = await repository.readDeckDraft('p', 2);

      expect(draft?.cardIds, ['x']);
      expect(draft?.heroId, 'ordinary_person');
      expect(
        (backend.values['profile:p:deck-draft:2'] as Map)['schemaVersion'],
        miniRoyaleDataSchemaVersion,
      );
    });

    test(
      'refuses a future schema without deleting the stored record',
      () async {
        final backend = MemoryBackend()
          ..values['profile:p:deck-draft:1'] = {
            'schemaVersion': miniRoyaleDataSchemaVersion + 1,
            'data': <String, Object?>{},
          };
        final repository = MiniRoyalePlayerDataRepository(backend: backend);

        await expectLater(
          repository.readDeckDraft('p', 1),
          throwsFormatException,
        );
        expect(backend.values, contains('profile:p:deck-draft:1'));
      },
    );

    test(
      'preserves invalid legacy data when migration validation fails',
      () async {
        final legacy = <String, Object?>{
          'schemaVersion': 0,
          'data': {
            'slot': 1,
            'name': 'Broken legacy draft',
            'cards': ['valid', 42],
          },
        };
        final backend = MemoryBackend()
          ..values['profile:p:deck-draft:1'] = legacy;
        final repository = MiniRoyalePlayerDataRepository(backend: backend);

        await expectLater(
          repository.readDeckDraft('p', 1),
          throwsFormatException,
        );

        expect(backend.values['profile:p:deck-draft:1'], same(legacy));
        expect((legacy['data'] as Map)['cards'], ['valid', 42]);
      },
    );

    test('rejects a draft stored under a different slot key', () async {
      final record = <String, Object?>{
        'schemaVersion': 0,
        'data': {
          'slot': 2,
          'name': 'Wrong slot',
          'cards': ['x'],
        },
      };
      final backend = MemoryBackend()
        ..values['profile:p:deck-draft:1'] = record;
      final repository = MiniRoyalePlayerDataRepository(backend: backend);

      await expectLater(
        repository.readDeckDraft('p', 1),
        throwsFormatException,
      );

      expect(backend.values['profile:p:deck-draft:1'], same(record));
    });
  });
}

class DelayedReadBackend implements MiniRoyalePlayerDataBackend {
  final values = <String, Object>{};
  final readStarted = Completer<void>();
  final releaseRead = Completer<void>();

  @override
  Future<Object?> read(String key) async {
    final snapshot = values[key];
    if (!readStarted.isCompleted) readStarted.complete();
    await releaseRead.future;
    return snapshot;
  }

  @override
  Future<void> write(String key, Object value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}
