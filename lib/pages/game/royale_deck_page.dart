import 'package:flutter/material.dart';

import '../../models/royale_models.dart';
import '../../services/api_client.dart';
import '../../services/royale_service.dart';

class RoyaleDeckPage extends StatefulWidget {
  const RoyaleDeckPage({super.key});

  @override
  State<RoyaleDeckPage> createState() => _RoyaleDeckPageState();
}

class _RoyaleDeckPageState extends State<RoyaleDeckPage> {
  late final RoyaleService _service;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  List<RoyaleCard> _cards = const [];
  final TextEditingController _nameController = TextEditingController(
    text: 'Battle Deck',
  );
  final List<String> _selectedCardIds = [];

  @override
  void initState() {
    super.initState();
    _service = RoyaleService(ApiClient());
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final cards = await _service.fetchCards();
      final decks = await _service.fetchDecks();
      final selected = decks.isNotEmpty
          ? decks.first.cards.map((card) => card.id).toList()
          : cards.take(8).map((card) => card.id).toList();

      setState(() {
        _cards = cards;
        _selectedCardIds
          ..clear()
          ..addAll(selected);
        if (decks.isNotEmpty) {
          _nameController.text = decks.first.name;
        }
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
      });
    } catch (e) {
      setState(() {
        _error = '載入牌組失敗: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  RoyaleCard? _findCard(String id) {
    for (final card in _cards) {
      if (card.id == id) {
        return card;
      }
    }
    return null;
  }

  void _toggleCard(RoyaleCard card) {
    setState(() {
      if (_selectedCardIds.contains(card.id)) {
        _selectedCardIds.remove(card.id);
        return;
      }
      if (_selectedCardIds.length >= 8) {
        return;
      }
      _selectedCardIds.add(card.id);
    });
  }

  Future<void> _save() async {
    if (_selectedCardIds.length != 8) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('牌組必須剛好 8 張')));
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final deck = await _service.saveDeck(
        name: _nameController.text.trim().isEmpty
            ? 'Battle Deck'
            : _nameController.text.trim(),
        slot: 1,
        cardIds: _selectedCardIds,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _nameController.text = deck.name;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('牌組已儲存')));
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Color _cardColor(String type, ColorScheme scheme) {
    switch (type) {
      case 'tank':
        return const Color(0xFF5C6BC0);
      case 'ranged':
        return const Color(0xFF00897B);
      case 'swarm':
        return const Color(0xFFE65100);
      case 'spell':
        return const Color(0xFFC62828);
      default:
        return const Color(0xFF6D4C41);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Mini Royale 牌組編輯')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: '牌組名稱',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '已選牌組 ${_selectedCardIds.length}/8',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _selectedCardIds
                              .map((cardId) => _findCard(cardId))
                              .whereType<RoyaleCard>()
                              .map(
                                (card) => InputChip(
                                  label: Text(
                                    '${card.name} ${card.elixirCost}',
                                  ),
                                  onDeleted: () => _toggleCard(card),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _save,
                          icon: const Icon(Icons.save_outlined),
                          label: Text(_isSaving ? '儲存中...' : '儲存牌組'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () =>
                            Navigator.of(context).pushNamed('/royale-lobby'),
                        icon: const Icon(Icons.sports_esports_outlined),
                        label: const Text('前往房間'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('可選卡牌', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.55,
                        ),
                    itemCount: _cards.length,
                    itemBuilder: (context, index) {
                      final card = _cards[index];
                      final selected = _selectedCardIds.contains(card.id);
                      final color = _cardColor(card.type, theme.colorScheme);
                      return InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => _toggleCard(card),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: color.withValues(
                              alpha: selected ? 0.88 : 0.72,
                            ),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: selected
                                  ? theme.colorScheme.primary
                                  : Colors.white.withValues(alpha: 0.2),
                              width: selected ? 2.4 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      card.name,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                  CircleAvatar(
                                    radius: 15,
                                    backgroundColor: Colors.black.withValues(
                                      alpha: 0.18,
                                    ),
                                    child: Text(
                                      '${card.elixirCost}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Text(
                                '類型: ${card.type}',
                                style: const TextStyle(color: Colors.white),
                              ),
                              Text(
                                card.type == 'spell'
                                    ? '法術傷害 ${card.spellDamage}'
                                    : '生命 ${card.hp} / 傷害 ${card.damage}',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}
