import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl_game_mini_royale/taiwan_brawl_game_mini_royale.dart';

void main() {
  const room = RoyaleRoomSnapshot(
    code: 'TEST',
    status: 'lobby',
    simulationMode: 'server',
    hostUserId: 1,
    viewerSide: 'left',
    players: [],
    battle: null,
  );
  const labels = {
    'Battle starts as soon as both players are ready': 'Ready when both are',
    'Host Simulation (Experimental)': 'Host mode',
    'Server Simulation': 'Server mode',
    'Mini Royale Lobby': 'Lobby title',
    'Ready': 'Ready',
    'Waiting': 'Waiting',
    'Online': 'Online',
    'Offline': 'Offline',
    'Add Friend Button': 'Add friend',
    'Sending...': 'Sending',
    'Ready to Battle': 'Start ready',
  };

  testWidgets('package lobby renders host copy and delegates ready action', (
    tester,
  ) async {
    var readyCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MiniRoyaleRoomLobby(
            room: room,
            arenaPreview: const SizedBox(height: 80, key: Key('arena-preview')),
            labels: labels,
            isReadySubmitting: false,
            canAddFriend: (_) => false,
            onAddFriend: (_) {},
            onReady: () => readyCalls++,
          ),
        ),
      ),
    );

    expect(find.text('ROOM TEST'), findsOneWidget);
    expect(find.text('Lobby title'), findsOneWidget);
    expect(find.byKey(const Key('arena-preview')), findsOneWidget);
    await tester.tap(find.text('Start ready'));
    expect(readyCalls, 1);
  });

  testWidgets('package lobby disables ready action while submission is active', (
    tester,
  ) async {
    var readyCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MiniRoyaleRoomLobby(
            room: room,
            arenaPreview: const SizedBox.shrink(),
            labels: labels,
            isReadySubmitting: true,
            canAddFriend: (_) => false,
            onAddFriend: (_) {},
            onReady: () => readyCalls++,
          ),
        ),
      ),
    );

    expect(find.text('Sending'), findsOneWidget);
    await tester.tap(find.text('Sending'));
    expect(readyCalls, 0);
  });
}
