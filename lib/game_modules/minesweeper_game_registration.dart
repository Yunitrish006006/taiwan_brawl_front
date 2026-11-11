import 'package:flutter/material.dart';
import 'package:taiwan_brawl_minesweeper/taiwan_brawl_minesweeper_flutter.dart';

import 'game_module_home_entry.dart';
import 'game_module_manifest.dart';
import 'game_module_registration.dart';

const minesweeperGameModuleId = 'game.minesweeper';

final minesweeperGameRegistration = GameModuleRegistration(
  manifest: GameModuleManifest(
    moduleId: minesweeperGameModuleId,
    displayName: '踩地雷',
    description: '在固定格子大小的棋盤中找出所有地雷。',
    packageVersion: '0.1.0',
    minimumShellVersion: '0.132.0',
    dataSchemaVersion: 1,
    platforms: allGamePlatforms,
    supportedResourceSchemas: const {},
    resources: const [],
  ),
  routes: const {'/minesweeper': _minesweeperRoute},
  homeEntries: const [
    GameModuleHomeEntry(
      moduleId: minesweeperGameModuleId,
      titleKey: '踩地雷',
      descriptionKey: '選擇棋盤尺寸，找出所有地雷。',
      tag: 'SOLO',
      icon: Icons.grid_3x3,
      accentColor: Color(0xFFE6BE5B),
      routeName: '/minesweeper',
    ),
  ],
);

Widget _minesweeperRoute(BuildContext context) => const MinesweeperHome();
