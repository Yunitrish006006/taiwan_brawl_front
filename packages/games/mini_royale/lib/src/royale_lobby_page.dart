import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'mini_royale_service.dart';
import 'mini_royale_localizations.dart';
import 'royale_models.dart';

class MiniRoyaleLobbyPage extends StatefulWidget {
  const MiniRoyaleLobbyPage({
    super.key,
    this.initialRoomCode,
    this.initialHeroId,
    this.initialHeroName,
    this.service,
    this.onOpenRoom,
    this.errorMessage,
    this.requiresGameUpdate,
    this.onOpenGameLibrary,
    this.llmBotConfigured = false,
  });

  final String? initialRoomCode;
  final String? initialHeroId;
  final String? initialHeroName;
  final MiniRoyaleService? service;
  final Future<void> Function(String roomCode)? onOpenRoom;
  final String Function(Object error)? errorMessage;
  final bool Function(Object error)? requiresGameUpdate;
  final VoidCallback? onOpenGameLibrary;
  final bool llmBotConfigured;

  @override
  State<MiniRoyaleLobbyPage> createState() => _RoyaleLobbyPageState();
}

class _RoyaleLobbyPageState extends State<MiniRoyaleLobbyPage> {
  late final MiniRoyaleService _service;
  String _simulationMode = 'server';
  String _botController = 'heuristic';
  bool _isLoading = true;
  bool _isSubmitting = false;
  List<RoyaleDeck> _decks = const [];
  RoyaleDeck? _selectedDeck;
  final TextEditingController _roomCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? context.read<MiniRoyaleService>();
    _roomCodeController.text =
        widget.initialRoomCode?.trim().toUpperCase() ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadLobbyData();
      }
    });
  }

  @override
  void dispose() {
    _roomCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadLobbyData() async {
    final t = MiniRoyaleLocalizations.fromContext(context, listen: false);
    setState(() {
      _isLoading = true;
    });

    try {
      final decks = await _service.fetchDeckSummaries();
      setState(() {
        _decks = decks;
        _selectedDeck = decks.isNotEmpty ? decks.first : null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t.text('Failed to load decks')}: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _enterRoom(Future<RoyaleRoomSnapshot> Function() action) async {
    final t = MiniRoyaleLocalizations.fromContext(context, listen: false);
    if (_selectedDeck == null) {
      _showSnackBar(t.text('Please create a deck first'));
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final room = await action();
      if (!mounted) {
        return;
      }
      final onOpenRoom = widget.onOpenRoom;
      if (onOpenRoom == null) {
        throw StateError('The host must provide room navigation.');
      }
      await onOpenRoom(room.code);
      if (mounted) {
        _loadLobbyData();
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      final message = widget.errorMessage?.call(e) ?? e.toString();
      final updateRequired = widget.requiresGameUpdate?.call(e) ?? false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${t.text('Action failed')}: $message'),
          action: updateRequired && widget.onOpenGameLibrary != null
              ? SnackBarAction(
                  label: t.text('Open Game Library'),
                  onPressed: widget.onOpenGameLibrary!,
                )
              : null,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String _simulationModeLabel(MiniRoyaleLocalizations t, String mode) {
    return mode == 'host'
        ? t.text('Host Simulation (Experimental)')
        : t.text('Server Simulation');
  }

  InputDecoration _dropdownDecoration(String labelText) {
    return InputDecoration(
      labelText: labelText,
      border: const OutlineInputBorder(),
      filled: true,
    );
  }

  Widget _buildDeckDropdown(MiniRoyaleLocalizations t) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dropdownTextStyle = theme.textTheme.titleMedium?.copyWith(
      color: scheme.onSurface,
    );
    final dropdownTheme = theme.copyWith(
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        fillColor: scheme.surface,
      ),
    );

    return Theme(
      data: dropdownTheme,
      child: DropdownButtonFormField<RoyaleDeck>(
        key: ValueKey(_selectedDeck?.id),
        initialValue: _selectedDeck,
        dropdownColor: scheme.surface,
        iconEnabledColor: scheme.onSurface,
        iconDisabledColor: scheme.onSurface.withValues(alpha: 0.38),
        style: dropdownTextStyle,
        decoration: _dropdownDecoration(t.text('Select Deck')),
        items: _decks
            .map(
              (deck) => DropdownMenuItem<RoyaleDeck>(
                value: deck,
                child: Text('${deck.name} (${deck.cardCount}/8)'),
              ),
            )
            .toList(),
        onChanged: (value) {
          setState(() {
            _selectedDeck = value;
          });
        },
      ),
    );
  }

  String get _heroId => widget.initialHeroId ?? 'ordinary_person';

  Widget _buildSelectedHeroChip(MiniRoyaleLocalizations t) {
    final heroName = widget.initialHeroName ?? _heroId;
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.person_outlined, size: 16, color: scheme.primary),
        const SizedBox(width: 6),
        Text(
          '${t.text('Hero')}: ',
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
        ),
        Text(
          heroName,
          style: TextStyle(
            color: scheme.primary,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => Navigator.of(context).pushNamed('/royale-deck'),
          child: Text(
            t.text('Change'),
            style: TextStyle(
              color: scheme.primary,
              fontSize: 12,
              decoration: TextDecoration.underline,
              decorationColor: scheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSimulationModeCard(MiniRoyaleLocalizations t) {
    final scheme = Theme.of(context).colorScheme;
    final description = _simulationMode == 'host'
        ? t.text(
            'Host simulation runs on the room host device. This experimental mode locks after battle starts.',
          )
        : t.text(
            'Server simulation runs in the room server and is the default recommended mode.',
          );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.text('Simulation Mode'),
            style: TextStyle(
              color: scheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            segments: [
              ButtonSegment<String>(
                value: 'server',
                label: Text(_simulationModeLabel(t, 'server')),
                icon: const Icon(Icons.cloud_done_outlined),
              ),
              ButtonSegment<String>(
                value: 'host',
                label: Text(_simulationModeLabel(t, 'host')),
                icon: const Icon(Icons.memory_rounded),
              ),
            ],
            selected: {_simulationMode},
            onSelectionChanged: (selection) {
              setState(() {
                _simulationMode = selection.first;
              });
            },
          ),
          const SizedBox(height: 10),
          Text(description, style: TextStyle(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildCreateRoomButton(
    MiniRoyaleLocalizations t, {
    required bool vsBot,
  }) {
    final label = vsBot ? t.text('Create Bot Match') : t.text('Create Room');
    final icon = vsBot
        ? const Icon(Icons.smart_toy_outlined)
        : const Icon(Icons.add_circle_outline);
    final llmConfigured = widget.llmBotConfigured;
    final createDisabledByBotConfig =
        vsBot && _botController == 'llm' && !llmConfigured;

    return SizedBox(
      width: double.infinity,
      child: (vsBot ? FilledButton.icon : ElevatedButton.icon)(
        onPressed:
            _isSubmitting || _selectedDeck == null || createDisabledByBotConfig
            ? null
            : () => _enterRoom(
                () => _service.createRoom(
                  deckId: _selectedDeck!.id,
                  heroId: _heroId,
                  vsBot: vsBot,
                  botController: vsBot ? _botController : 'heuristic',
                  simulationMode: vsBot ? 'host' : _simulationMode,
                ),
              ),
        icon: icon,
        label: Text(label),
      ),
    );
  }

  Widget _buildBotMatchModeHint(MiniRoyaleLocalizations t) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(Icons.memory_rounded, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t.text('Host Simulation (Experimental)'),
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  t.text(
                    'Host simulation runs on the room host device. This experimental mode locks after battle starts.',
                  ),
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _botControllerLabel(MiniRoyaleLocalizations t, String value) {
    return value == 'llm' ? t.text('LLM Bot') : t.text('Heuristic Bot');
  }

  Widget _buildBotControllerCard(MiniRoyaleLocalizations t) {
    final scheme = Theme.of(context).colorScheme;
    final llmConfigured = widget.llmBotConfigured;
    final description = _botController == 'llm'
        ? t.text(
            'LLM Bot uses your saved OpenAI-compatible API key and model settings to choose from legal battle actions.',
          )
        : t.text(
            'Heuristic Bot uses the built-in combat logic and does not require any external API key.',
          );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.text('Bot Controller'),
            style: TextStyle(
              color: scheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            segments: [
              ButtonSegment<String>(
                value: 'heuristic',
                icon: const Icon(Icons.psychology_alt_outlined),
                label: Text(_botControllerLabel(t, 'heuristic')),
              ),
              ButtonSegment<String>(
                value: 'llm',
                icon: const Icon(Icons.auto_awesome_outlined),
                label: Text(_botControllerLabel(t, 'llm')),
              ),
            ],
            selected: {_botController},
            onSelectionChanged: (selection) {
              setState(() {
                _botController = selection.first;
              });
            },
          ),
          const SizedBox(height: 10),
          Text(description, style: TextStyle(color: scheme.onSurfaceVariant)),
          if (_botController == 'llm' && !llmConfigured) ...[
            const SizedBox(height: 10),
            Text(
              t.text(
                'LLM bot requires a saved API key. Open Profile > Display Settings > LLM Bot Settings first.',
              ),
              style: TextStyle(
                color: scheme.tertiary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCreateRoomPanel(
    ThemeData theme,
    MiniRoyaleLocalizations t,
    String locale,
  ) {
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            scheme.primaryContainer,
            scheme.secondaryContainer,
            scheme.tertiaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.text('Create a 1v1 Room'),
            style: theme.textTheme.headlineSmall?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            t.text(
              'Choose an 8-card deck. After creating the room, open the drawer inside the room and invite a friend from your friend list.',
            ),
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          _buildDeckDropdown(t),
          const SizedBox(height: 12),
          _buildSelectedHeroChip(t),
          const SizedBox(height: 16),
          Text(
            t.text('Create Room'),
            style: theme.textTheme.titleMedium?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          _buildSimulationModeCard(t),
          const SizedBox(height: 16),
          _buildCreateRoomButton(t, vsBot: false),
          const SizedBox(height: 18),
          Divider(color: scheme.outlineVariant, height: 1),
          const SizedBox(height: 18),
          Text(
            t.text('Create Bot Match'),
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          _buildBotControllerCard(t),
          const SizedBox(height: 10),
          _buildBotMatchModeHint(t),
          const SizedBox(height: 16),
          _buildCreateRoomButton(t, vsBot: true),
        ],
      ),
    );
  }

  Widget _buildJoinRoomPanel(ThemeData theme, MiniRoyaleLocalizations t) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.text('Join a Friend\'s Room'),
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _roomCodeController,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: t.text('Enter a 6-character room code'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isSubmitting || _selectedDeck == null
                  ? null
                  : () => _enterRoom(
                      () => _service.joinRoom(
                        roomCode: _roomCodeController.text.trim().toUpperCase(),
                        deckId: _selectedDeck!.id,
                        heroId: _heroId,
                      ),
                    ),
              icon: const Icon(Icons.login),
              label: Text(t.text('Join Room')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLobbyBody(ThemeData theme, MiniRoyaleLocalizations t) {
    final locale = MiniRoyaleLocalizations.fromContext(context).locale;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildCreateRoomPanel(theme, t, locale),
        const SizedBox(height: 20),
        _buildJoinRoomPanel(theme, t),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).pushNamed('/royale-deck'),
          icon: const Icon(Icons.style_outlined),
          label: Text(t.text('Back to Deck Builder')),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = MiniRoyaleLocalizations.fromContext(context);

    return Scaffold(
      appBar: AppBar(title: Text(t.text('Mini Royale Lobby'))),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildLobbyBody(theme, t),
    );
  }
}
