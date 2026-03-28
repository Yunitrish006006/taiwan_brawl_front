import 'package:flutter/material.dart';

import '../../models/royale_models.dart';
import '../../services/api_client.dart';
import '../../services/royale_service.dart';
import 'royale_arena_page.dart';

class RoyaleLobbyPage extends StatefulWidget {
  const RoyaleLobbyPage({super.key});

  @override
  State<RoyaleLobbyPage> createState() => _RoyaleLobbyPageState();
}

class _RoyaleLobbyPageState extends State<RoyaleLobbyPage> {
  late final RoyaleService _service;
  bool _isLoading = true;
  bool _isSubmitting = false;
  List<RoyaleDeck> _decks = const [];
  RoyaleDeck? _selectedDeck;
  final TextEditingController _roomCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _service = RoyaleService(ApiClient());
    _loadDecks();
  }

  @override
  void dispose() {
    _roomCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadDecks() async {
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('載入牌組失敗: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _enterRoom(Future<RoyaleRoomSnapshot> Function() action) async {
    if (_selectedDeck == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請先建立一組牌組')));
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
      ).showSnackBar(SnackBar(content: Text('操作失敗: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Mini Royale 房間大廳')),
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
                        '建立 1v1 房間',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '選一組 8 張牌的牌組，建立房間後把房碼丟給朋友就能開始準備。',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<RoyaleDeck>(
                        key: ValueKey(_selectedDeck?.id),
                        initialValue: _selectedDeck,
                        dropdownColor: const Color(0xFF16324F),
                        decoration: const InputDecoration(
                          labelText: '選擇牌組',
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
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isSubmitting || _selectedDeck == null
                              ? null
                              : () => _enterRoom(
                                  () => _service.createRoom(
                                    deckId: _selectedDeck!.id,
                                  ),
                                ),
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text('建立房間'),
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
                      Text('加入朋友房間', style: theme.textTheme.titleLarge),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _roomCodeController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: '輸入 6 碼房碼',
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
                          label: const Text('加入房間'),
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
                  label: const Text('回牌組編輯'),
                ),
              ],
            ),
    );
  }
}
