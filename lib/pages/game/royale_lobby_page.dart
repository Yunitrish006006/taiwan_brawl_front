import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/royale_models.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/locale_provider.dart';
import '../../services/royale_service.dart';
import 'royale_arena_page.dart' deferred as royale_arena_lib;

class RoyaleLobbyPage extends StatefulWidget {
  const RoyaleLobbyPage({super.key, this.initialRoomCode});

  final String? initialRoomCode;

  @override
  State<RoyaleLobbyPage> createState() => _RoyaleLobbyPageState();
}

class _RoyaleLobbyPageState extends State<RoyaleLobbyPage> {
  late final RoyaleService _service;
  String _simulationMode = 'server';
  String _botController = 'heuristic';
  bool _isLoading = true;
  bool _isSubmitting = false;
  List<RoyaleDeck> _decks = const [];
  List<RoyaleHero> _heroes = const [];
  RoyaleDeck? _selectedDeck;
  RoyaleHero? _selectedHero;
  final TextEditingController _roomCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _service = RoyaleService(ApiClient());
    _roomCodeController.text =
        widget.initialRoomCode?.trim().toUpperCase() ?? '';
    _loadLobbyData();
  }

  @override
  void dispose() {
    _roomCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadLobbyData() async {
    final t = context.read<LocaleProvider>().translation;
    setState(() {
      _isLoading = true;
    });

    try {
      final results = await Future.wait([
        _service.fetchDecks(),
        _service.fetchHeroes(),
      ]);
      final decks = results[0] as List<RoyaleDeck>;
      final heroes = results[1] as List<RoyaleHero>;
      final defaultHero = heroes.where((hero) => hero.id == 'ordinary_person');
      setState(() {
        _decks = decks;
        _heroes = heroes;
        _selectedDeck = decks.isNotEmpty ? decks.first : null;
        _selectedHero = defaultHero.isNotEmpty
            ? defaultHero.first
            : (heroes.isNotEmpty ? heroes.first : null);
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
    final t = context.read<LocaleProvider>().translation;
    if (_selectedDeck == null) {
      _showSnackBar(t.text('Please create a deck first'));
      return;
    }
    if (_selectedHero == null) {
      _showSnackBar(t.text('Please select a hero first'));
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
      await royale_arena_lib.loadLibrary();
      if (!mounted) {
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => royale_arena_lib.RoyaleArenaPage(roomCode: room.code),
        ),
      );
      if (mounted) {
        _loadLobbyData();
      }
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      _showSnackBar(e.message);
    } catch (e) {
      if (!mounted) {
        return;
      }
      _showSnackBar('${t.text('Action failed')}: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String _simulationModeLabel(Map<String, String> t, String mode) {
    return mode == 'host'
        ? t.text('Host Simulation (Experimental)')
        : t.text('Server Simulation');
  }

  InputDecoration _dropdownDecoration(String labelText) {
    return InputDecoration(
      labelText: labelText,
      border: const OutlineInputBorder(),
      filled: true,
      fillColor: Colors.white,
    );
  }

  Widget _buildDeckDropdown(Map<String, String> t) {
    return DropdownButtonFormField<RoyaleDeck>(
      key: ValueKey(_selectedDeck?.id),
      initialValue: _selectedDeck,
      dropdownColor: const Color(0xFF16324F),
      decoration: _dropdownDecoration(t.text('Select Deck')),
      items: _decks
          .map(
            (deck) => DropdownMenuItem<RoyaleDeck>(
              value: deck,
              child: Text('${deck.name} (${deck.cards.length}/8)'),
            ),
          )
          .toList(),
      onChanged: (value) {
        setState(() {
          _selectedDeck = value;
        });
      },
    );
  }

  String _heroMeterSummary(RoyaleResourceDefinition value) {
    return '${value.initial.toStringAsFixed(1)} / ${value.max.toStringAsFixed(1)} / ${value.regenPerSecond.toStringAsFixed(1)}';
  }

  Widget _buildHeroSelector(Map<String, String> t, String locale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.text('Select Hero'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _heroes.map((hero) {
            final selected = _selectedHero?.id == hero.id;
            return SizedBox(
              width: 240,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  setState(() {
                    _selectedHero = hero;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.18)
                        : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFFFFD166)
                          : Colors.white.withValues(alpha: 0.14),
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hero.localizedName(locale),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hero.localizedBonusSummary(locale),
                        style: const TextStyle(
                          color: Color(0xFFFFD166),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${t.text('Physical Health')} ${_heroMeterSummary(hero.physicalHealth)}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${t.text('Spirit Health')} ${_heroMeterSummary(hero.spiritHealth)}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${t.text('Physical Energy')} ${_heroMeterSummary(hero.physicalEnergy)}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${t.text('Spirit Energy')} ${_heroMeterSummary(hero.spiritEnergy)}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${t.text('Money')} ${_heroMeterSummary(hero.money)}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSimulationModeCard(Map<String, String> t) {
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
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.text('Simulation Mode'),
            style: const TextStyle(
              color: Colors.white,
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
          Text(description, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildCreateRoomButton(Map<String, String> t, {required bool vsBot}) {
    final label = vsBot ? t.text('Create Bot Match') : t.text('Create Room');
    final icon = vsBot
        ? const Icon(Icons.smart_toy_outlined)
        : const Icon(Icons.add_circle_outline);
    final currentUser = context.watch<AuthService>().user;
    final llmConfigured = currentUser?.hasLlmApiKey ?? false;
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
                  heroId: _selectedHero!.id,
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

  Widget _buildBotMatchModeHint(Map<String, String> t) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.memory_rounded, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t.text('Host Simulation (Experimental)'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  t.text(
                    'Host simulation runs on the room host device. This experimental mode locks after battle starts.',
                  ),
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _botControllerLabel(Map<String, String> t, String value) {
    return value == 'llm' ? t.text('LLM Bot') : t.text('Heuristic Bot');
  }

  Widget _buildBotControllerCard(Map<String, String> t) {
    final currentUser = context.watch<AuthService>().user;
    final llmConfigured = currentUser?.hasLlmApiKey ?? false;
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
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.text('Bot Controller'),
            style: const TextStyle(
              color: Colors.white,
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
          Text(description, style: const TextStyle(color: Colors.white70)),
          if (_botController == 'llm' && !llmConfigured) ...[
            const SizedBox(height: 10),
            Text(
              t.text(
                'LLM bot requires a saved API key. Open Profile > Display Settings > LLM Bot Settings first.',
              ),
              style: const TextStyle(
                color: Color(0xFFFFD166),
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
    Map<String, String> t,
    String locale,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF16324F), Color(0xFF294C60), Color(0xFF3E7C59)],
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
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            t.text(
              'Choose an 8-card deck. After creating the room, open the drawer inside the room and invite a friend from your friend list.',
            ),
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          _buildDeckDropdown(t),
          const SizedBox(height: 16),
          _buildHeroSelector(t, locale),
          const SizedBox(height: 16),
          Text(
            t.text('Create Room'),
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          _buildSimulationModeCard(t),
          const SizedBox(height: 16),
          _buildCreateRoomButton(t, vsBot: false),
          const SizedBox(height: 18),
          Divider(color: Colors.white.withValues(alpha: 0.16), height: 1),
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

  Widget _buildJoinRoomPanel(ThemeData theme, Map<String, String> t) {
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
                        heroId: _selectedHero!.id,
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

  Widget _buildLobbyBody(ThemeData theme, Map<String, String> t) {
    final locale = context.watch<LocaleProvider>().locale;
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
    final t = context.watch<LocaleProvider>().translation;

    return Scaffold(
      appBar: AppBar(title: Text(t.text('Mini Royale Lobby'))),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildLobbyBody(theme, t),
    );
  }
}
