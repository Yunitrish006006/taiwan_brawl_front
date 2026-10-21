import 'package:flutter/material.dart';

import 'royale_models.dart';

/// Package-owned waiting-room presentation. The host supplies localized copy,
/// the arena preview and account/social actions without exposing its services.
class MiniRoyaleRoomLobby extends StatelessWidget {
  const MiniRoyaleRoomLobby({
    super.key,
    required this.room,
    required this.arenaPreview,
    required this.labels,
    required this.isReadySubmitting,
    required this.canAddFriend,
    required this.onAddFriend,
    required this.onReady,
  });

  final RoyaleRoomSnapshot room;
  final Widget arenaPreview;
  final Map<String, String> labels;
  final bool isReadySubmitting;
  final bool Function(RoyalePlayerView player) canAddFriend;
  final ValueChanged<RoyalePlayerView> onAddFriend;
  final VoidCallback onReady;

  String _label(String key) => labels[key] ?? key;

  Color _sideColor(String side) => side == 'left'
      ? const Color(0xFF25B7D3)
      : const Color(0xFFE25555);

  @override
  Widget build(BuildContext context) {
    final isHostMode = room.simulationMode == 'host';
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF0E223A),
                    Color(0xFF1C4261),
                    Color(0xFF266A66),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x44000000),
                    blurRadius: 28,
                    offset: Offset(0, 16),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'ROOM ${room.code}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                      Text(
                        _label('Battle starts as soon as both players are ready'),
                        style: const TextStyle(color: Colors.white70),
                      ),
                      _StatusPill(
                        label: _label(
                          isHostMode
                              ? 'Host Simulation (Experimental)'
                              : 'Server Simulation',
                        ),
                        color: isHostMode
                            ? const Color(0xFFB084F5)
                            : const Color(0xFF48C7F4),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _label('Mini Royale Lobby'),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 20),
                  arenaPreview,
                  const SizedBox(height: 18),
                  ...room.players.map(_playerRow),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: isReadySubmitting ? null : onReady,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFFB703),
                        foregroundColor: const Color(0xFF1F2937),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      icon: const Icon(Icons.flash_on_rounded),
                      label: Text(
                        _label(isReadySubmitting ? 'Sending...' : 'Ready to Battle'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _playerRow(RoyalePlayerView player) {
    final sideColor = _sideColor(player.side);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: sideColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          _SideBadge(side: player.side, color: sideColor),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  player.deckName,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          _StatusPill(
            label: _label(player.ready ? 'Ready' : 'Waiting'),
            color: player.ready
                ? const Color(0xFF3ECF8E)
                : const Color(0xFFF8B64C),
          ),
          const SizedBox(width: 8),
          _StatusPill(
            label: _label(player.connected ? 'Online' : 'Offline'),
            color: player.connected
                ? const Color(0xFF48C7F4)
                : const Color(0xFF7B8794),
          ),
          if (canAddFriend(player)) ...[
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () => onAddFriend(player),
              icon: const Icon(Icons.person_add_alt_1, size: 18),
              label: Text(_label('Add Friend Button')),
            ),
          ],
        ],
      ),
    );
  }
}

class _SideBadge extends StatelessWidget {
  const _SideBadge({required this.side, required this.color});

  final String side;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    height: 42,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    child: Text(
      side.toUpperCase(),
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withValues(alpha: 0.55)),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
    ),
  );
}
