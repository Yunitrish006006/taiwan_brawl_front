import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:taiwan_brawl_game_archery/taiwan_brawl_game_archery.dart';
import 'package:user_ui_settings/user_ui_settings.dart';

void main() {
  test(
    'a delayed schema migration cannot overwrite a concurrent save',
    () async {
      final backend = _DelayedReadArcheryBackend();
      final repository = ArcheryPlayerDataRepository(backend: backend);
      backend.values['profile:player:progress'] = {
        'schemaVersion': 0,
        'data': {'best_score': 75},
      };

      final migrationRead = repository.readProgress('player');
      await backend.readStarted.future;
      // A separately constructed repository can share the same Hive box in
      // another route; serialization must cover the shared package namespace.
      final secondRepository = ArcheryPlayerDataRepository(backend: backend);
      final save = secondRepository.writeProgress(
        'player',
        const ArcheryPlayerProgress(highScore: 88),
      );
      await Future<void>.delayed(Duration.zero);
      backend.releaseRead.complete();

      expect((await migrationRead).highScore, 75);
      await save;
      expect((await repository.readProgress('player')).highScore, 88);
    },
  );

  test(
    'a delayed schema migration cannot resurrect a concurrent delete',
    () async {
      final backend = _DelayedReadArcheryBackend();
      final repository = ArcheryPlayerDataRepository(backend: backend);
      backend.values['profile:player:progress'] = {
        'schemaVersion': 0,
        'data': {'best_score': 75},
      };

      final migrationRead = repository.readProgress('player');
      await backend.readStarted.future;
      final deletionRepository = ArcheryPlayerDataRepository(backend: backend);
      final deletion = deletionRepository.deleteProgress('player');
      await Future<void>.delayed(Duration.zero);
      backend.releaseRead.complete();

      expect((await migrationRead).highScore, 75);
      await deletion;
      expect(backend.values, isNot(contains('profile:player:progress')));
    },
  );

  test(
    'Archery player data is profile-scoped and migrated by its package',
    () async {
      final backend = _MemoryArcheryBackend();
      final repository = ArcheryPlayerDataRepository(backend: backend);
      backend.values['profile:legacy:progress'] = {
        'schemaVersion': 0,
        'data': {'best_score': 75},
      };

      expect((await repository.readProgress('legacy')).highScore, 75);
      expect(backend.values['profile:legacy:progress'], {
        'schemaVersion': archeryGameDataSchemaVersion,
        'data': {'highScore': 75},
      });
      expect((await repository.readProgress('another-profile')).highScore, 0);
      await repository.writeProgress(
        'another-profile',
        const ArcheryPlayerProgress(highScore: 12),
      );
      expect((await repository.readProgress('legacy')).highScore, 75);
    },
  );

  test(
    'Archery package owns its independent module and data-schema versions',
    () {
      expect(archeryGameManifest.moduleId, 'game.archery');
      expect(archeryGameManifest.packageVersion, '0.1.0');
      expect(archeryGameManifest.minimumShellVersion, '0.132.0');
      expect(archeryGameManifest.dataSchemaVersion, 1);
      expect(archeryGameSupportedResourceSchemas, {archeryRulesResourceId: 1});
      expect(archeryGameManifest.toJson(), {
        'moduleId': 'game.archery',
        'manifestVersion': 1,
        'kind': 'game',
        'publisher': 'taiwan-brawl',
        'packageVersion': '0.1.0',
        'minimumShellVersion': '0.132.0',
        'hostApiRange': '>=1.0.0 <2.0.0',
        'dependencies': const <Object>[],
        'dataSchemaVersion': 1,
        'platforms': archeryGameSupportedPlatforms,
        'resources': const <Object>[],
      });
    },
  );

  test('module manifest version stays aligned with the package release', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final packageVersion = RegExp(
      r'^version:\s*(\S+)\s*$',
      multiLine: true,
    ).firstMatch(pubspec)?.group(1);

    expect(packageVersion, isNotNull);
    expect(archeryGameManifest.packageVersion, packageVersion);
  });

  testWidgets('game input waits for the active rules version to load', (
    tester,
  ) async {
    final locale = LocaleProvider(
      defaultLocale: 'en',
      translationResolver: (_) => const {},
    );
    addTearDown(locale.dispose);
    final payload = Completer<String?>();

    await tester.pumpWidget(
      ChangeNotifierProvider<LocaleProvider>.value(
        value: locale,
        child: MaterialApp(
          home: ArcheryGamePage(
            rulesContentSource: _DelayedRulesSource(payload.future),
          ),
        ),
      ),
    );

    expect(
      find.byWidgetPredicate(
        (widget) => widget is IgnorePointer && widget.ignoring,
      ),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    payload.complete(jsonEncode(ArcheryRules.builtIn.toJson()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 32));

    expect(
      find.byWidgetPredicate(
        (widget) => widget is IgnorePointer && widget.ignoring,
      ),
      findsNothing,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _DelayedRulesSource implements ArcheryRulesContentSource {
  const _DelayedRulesSource(this.payload);

  final Future<String?> payload;

  @override
  Future<String?> readActiveRulesJson() => payload;
}

class _MemoryArcheryBackend implements ArcheryPlayerDataBackend {
  final values = <String, Object>{};

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<Object?> read(String key) async => values[key];

  @override
  Future<void> write(String key, Object value) async {
    values[key] = value;
  }
}

class _DelayedReadArcheryBackend implements ArcheryPlayerDataBackend {
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
