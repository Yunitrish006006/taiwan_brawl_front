import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/royale_models.dart';
import '../../services/api_client.dart';
import '../../services/locale_provider.dart';
import '../../services/royale_service.dart';
import 'royale_arena_page.dart';

class RoyaleLobbyPage extends StatefulWidget {
  const RoyaleLobbyPage({super.key, this.initialRoomCode});

  final String? initialRoomCode;

  @override
  State<RoyaleLobbyPage> createState() => _RoyaleLobbyPageState();
}

class _RoyaleLobbyPageState extends State<RoyaleLobbyPage> {
  late final RoyaleService _service;
  String _simulationMode = 'server';
  bool _isLoading = true;
  bool _isSubmitting = false;
  List<RoyaleDeck> _decks = const [];
  RoyaleDeck? _selectedDeck;
  final TextEditingController _roomCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _service = RoyaleService(ApiClient());
    _roomCodeController.text =
        widget.initialRoomCode?.trim().toUpperCase() ?? '';
    _loadDecks();
  }

  @override
  void dispose() {
    _roomCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadDecks() async {
    final t = context.read<LocaleProvider>().translation;
    setState(() {
      _isLoading = true;
    });

    try {
      final decks = await _service.fetchDecks();
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

  Future<void> _enterRoom(Future<RoyaleRoomSnapshot> Function() action) async {
    final t = context.read<LocaleProvider>().translation;
    if (_selectedDeck == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.text('Please create a deck first'))),
      );
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
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => RoyaleArenaPage(roomCode: room.code)),
      );
      if (mounted) {
        _loadDecks();
      }
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${t.text('Action failed')}: $e')));
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.watch<LocaleProvider>().translation;

    return Scaffold(
      appBar: AppBar(title: Text(t.text('Mini Royale Lobby'))),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF16324F),
                        Color(0xFF294C60),
                        Color(0xFF3E7C59),
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
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        t.text(
                          'Choose an 8-card deck. After creating the room, send the room code to your friend so both of you can get ready.',
                        ),
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<RoyaleDeck>(
                        key: ValueKey(_selectedDeck?.id),
                        initialValue: _selectedDeck,
                        dropdownColor: const Color(0xFF16324F),
                        decoration: InputDecoration(
                          labelText: t.text('Select Deck'),
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: _decks
                            .map(
                              (deck) => DropdownMenuItem<RoyaleDeck>(
                                value: deck,
                                child: Text(
                                  '${deck.name} (${deck.cards.length}/8)',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedDeck = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      Container(
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
                                  label: Text(
                                    _simulationModeLabel(t, 'server'),
                                  ),
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
                            Text(
                              _simulationMode == 'host'
                                  ? t.text(
                                      'Host simulation runs on your device. This experimental mode is currently available for bot matches only and locks after battle starts.',
                                    )
                                  : t.text(
                                      'Server simulation runs in the room server and is the default recommended mode.',
                                    ),
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isSubmitting || _selectedDeck == null
                              ? null
                              : () {
                                  if (_simulationMode == 'host') {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          t.text(
                                            'Host simulation is currently available for bot matches only',
                                          ),
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  _enterRoom(
                                    () => _service.createRoom(
                                      deckId: _selectedDeck!.id,
                                      simulationMode: _simulationMode,
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.add_circle_outline),
                          label: Text(t.text('Create Room')),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _isSubmitting || _selectedDeck == null
                              ? null
                              : () => _enterRoom(
                                  () => _service.createRoom(
                                    deckId: _selectedDeck!.id,
                                    vsBot: true,
                                    simulationMode: _simulationMode,
                                  ),
                                ),
                          icon: const Icon(Icons.smart_toy_outlined),
                          label: Text(t.text('Create Bot Match')),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.7,
                    ),
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
                          border: OutlineInputBorder(),
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
                                    roomCode: _roomCodeController.text
                                        .trim()
                                        .toUpperCase(),
                                    deckId: _selectedDeck!.id,
                                  ),
                                ),
                          icon: const Icon(Icons.login),
                          label: Text(t.text('Join Room')),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pushNamed('/royale-deck'),
                  icon: const Icon(Icons.style_outlined),
                  label: Text(t.text('Back to Deck Builder')),
                ),
              ],
            ),
    );
  }
}
