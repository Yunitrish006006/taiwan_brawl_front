import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/royale_field_event_info.dart';
import '../../models/royale_models.dart';
import '../../services/api_client.dart';
import '../../services/locale_provider.dart';
import '../../services/royale_service.dart';

class RoyaleDeckPage extends StatefulWidget {
  const RoyaleDeckPage({super.key});

  @override
  State<RoyaleDeckPage> createState() => _RoyaleDeckPageState();
}

class _RoyaleDeckPageState extends State<RoyaleDeckPage> {
  static const int _maxDeckSlots = 3;
  static const String _categoryAll = 'all';
  static const String _categoryUnit = 'unit';
  static const String _categoryEquipment = 'equipment';
  static const String _categorySpell = 'spell';
  static const String _categoryBuilding = 'building';
  static const String _categoryJob = 'job';
  static const String _categoryFieldEvent = 'field_event';

  late final RoyaleService _service;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasLoadedDecksOnce = false;
  String? _error;
  List<RoyaleCard> _cards = const [];
  List<RoyaleDeck> _decks = const [];
  List<RoyaleHero> _heroes = const [];
  String _selectedHeroId = 'ordinary_person';
  final TextEditingController _nameController = TextEditingController(
    text: 'Battle Deck',
  );
  final List<String> _selectedCardIds = [];
  int _activeSlot = 1;
  String? _previewCardId;
  String _cardCategoryFilter = _categoryAll;
  int? _energyFilter;

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
    final t = context.read<LocaleProvider>().translation;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final cards = await _service.fetchCards();
      final decks = await _service.fetchDecks();
      final heroes = await _service.fetchHeroes();
      final sortedDecks = [...decks]..sort((a, b) => a.slot.compareTo(b.slot));
      final targetSlot = _resolveSlotForLoad(sortedDecks);
      final deck = _deckForSlot(targetSlot, decks: sortedDecks);
      final selected =
          deck?.cards.map((card) => card.id).toList() ??
          _defaultSelectedCardIds(cards);
      final deckName = deck?.name ?? _defaultDeckName(targetSlot);

      setState(() {
        _cards = cards;
        _decks = sortedDecks;
        _heroes = heroes;
        _selectedHeroId = heroes.any((h) => h.id == _selectedHeroId)
            ? _selectedHeroId
            : (heroes.isNotEmpty ? heroes.first.id : 'ordinary_person');
        _activeSlot = targetSlot;
        _selectedCardIds
          ..clear()
          ..addAll(selected);
        _nameController.text = deckName;
        _previewCardId = _defaultPreviewCardId(
          selectedCardIds: selected,
          cards: cards,
        );
        _hasLoadedDecksOnce = true;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
      });
    } catch (e) {
      setState(() {
        _error = '${t.text('Failed to load decks')}: $e';
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

  RoyaleDeck? _deckForSlot(int slot, {List<RoyaleDeck>? decks}) {
    for (final deck in decks ?? _decks) {
      if (deck.slot == slot) {
        return deck;
      }
    }
    return null;
  }

  int _resolveSlotForLoad(List<RoyaleDeck> decks) {
    if (_hasLoadedDecksOnce) {
      return _activeSlot;
    }
    if (decks.isEmpty) {
      return 1;
    }
    return decks.first.slot;
  }

  List<String> _defaultSelectedCardIds(List<RoyaleCard> cards) {
    return cards.take(8).map((card) => card.id).toList(growable: false);
  }

  String? _defaultPreviewCardId({
    required List<String> selectedCardIds,
    required List<RoyaleCard> cards,
  }) {
    if (selectedCardIds.isNotEmpty) {
      return selectedCardIds.first;
    }
    if (cards.isNotEmpty) {
      return cards.first.id;
    }
    return null;
  }

  String _defaultDeckName(int slot) {
    return slot == 1 ? 'Battle Deck' : 'Battle Deck $slot';
  }

  int? get _nextAvailableSlot {
    for (var slot = 1; slot <= _maxDeckSlots; slot++) {
      if (_deckForSlot(slot) == null) {
        return slot;
      }
    }
    return null;
  }

  void _activateSlot(int slot) {
    final deck = _deckForSlot(slot);
    final selectedCardIds =
        deck?.cards.map((card) => card.id).toList() ??
        _defaultSelectedCardIds(_cards);

    setState(() {
      _activeSlot = slot;
      _selectedCardIds
        ..clear()
        ..addAll(selectedCardIds);
      _nameController.text = deck?.name ?? _defaultDeckName(slot);
      _previewCardId = _defaultPreviewCardId(
        selectedCardIds: selectedCardIds,
        cards: _cards,
      );
    });
  }

  void _startNewDeck() {
    final t = context.read<LocaleProvider>().translation;
    final nextAvailableSlot = _nextAvailableSlot;
    if (nextAvailableSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.text('You can only save up to 3 decks'))),
      );
      return;
    }
    _activateSlot(nextAvailableSlot);
  }

  void _toggleCard(RoyaleCard card) {
    setState(() {
      _previewCardId = card.id;
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
    final t = context.read<LocaleProvider>().translation;
    if (_selectedCardIds.length != 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.text('Deck must contain exactly 8 cards'))),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final deck = await _service.saveDeck(
        name: _nameController.text.trim().isEmpty
            ? _defaultDeckName(_activeSlot)
            : _nameController.text.trim(),
        slot: _activeSlot,
        cardIds: _selectedCardIds,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _decks = ([..._decks.where((entry) => entry.slot != deck.slot), deck]
          ..sort((a, b) => a.slot.compareTo(b.slot)));
        _nameController.text = deck.name;
        _activeSlot = deck.slot;
        _selectedCardIds
          ..clear()
          ..addAll(deck.cards.map((card) => card.id));
        _previewCardId = _defaultPreviewCardId(
          selectedCardIds: _selectedCardIds,
          cards: _cards,
        );
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.text('Deck saved'))));
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

  List<RoyaleCard> get _selectedCards {
    return _selectedCardIds
        .map((cardId) => _findCard(cardId))
        .whereType<RoyaleCard>()
        .toList(growable: false);
  }

  RoyaleCard? get _previewCard {
    final previewCardId = _previewCardId;
    if (previewCardId != null) {
      final previewCard = _findCard(previewCardId);
      if (previewCard != null) {
        return previewCard;
      }
    }
    final selectedCards = _selectedCards;
    if (selectedCards.isNotEmpty) {
      return selectedCards.first;
    }
    if (_cards.isNotEmpty) {
      return _cards.first;
    }
    return null;
  }

  int _selectedIndexFor(String cardId) {
    return _selectedCardIds.indexOf(cardId);
  }

  bool _isSelectedCard(String cardId) {
    return _selectedIndexFor(cardId) >= 0;
  }

  void _setPreviewCard(RoyaleCard card) {
    if (_previewCardId == card.id) {
      return;
    }
    setState(() {
      _previewCardId = card.id;
    });
  }

  bool _isUnitCard(RoyaleCard card) {
    return card.type != 'spell' &&
        card.type != 'equipment' &&
        card.type != 'building' &&
        !card.isJob;
  }

  bool _matchesCategoryFilter(RoyaleCard card) {
    switch (_cardCategoryFilter) {
      case _categoryUnit:
        return _isUnitCard(card);
      case _categoryEquipment:
        return card.type == 'equipment';
      case _categorySpell:
        return card.type == 'spell';
      case _categoryBuilding:
        return card.type == 'building';
      case _categoryJob:
        return card.isJob;
      case _categoryFieldEvent:
        return false; // field events not in card list
      case _categoryAll:
      default:
        return true;
    }
  }

  bool _matchesEnergyFilter(RoyaleCard card) {
    final energyFilter = _energyFilter;
    if (energyFilter == null) {
      return true;
    }
    if (energyFilter >= 5) {
      return card.energyCost >= 5;
    }
    return card.energyCost == energyFilter;
  }

  List<RoyaleCard> get _filteredCards {
    return _cards
        .where(_matchesCategoryFilter)
        .where(_matchesEnergyFilter)
        .toList(growable: false);
  }

  String _heroMeterSummary(RoyaleResourceDefinition value) {
    return '${value.initial.toStringAsFixed(1)} / ${value.max.toStringAsFixed(1)} / ${value.regenPerSecond.toStringAsFixed(1)}';
  }

  Widget _buildHeroCard(RoyaleHero hero, ThemeData theme, String locale) {
    final isSelected = _selectedHeroId == hero.id;
    return SizedBox(
      width: 220,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => setState(() => _selectedHeroId = hero.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.6,
                    ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        hero.localizedName(locale),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  hero.localizedBonusSummary(locale),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                _buildHeroStatRow(
                  theme,
                  icon: Icons.favorite_border_rounded,
                  label: 'PH',
                  value: _heroMeterSummary(hero.physicalHealth),
                ),
                const SizedBox(height: 2),
                _buildHeroStatRow(
                  theme,
                  icon: Icons.psychology_outlined,
                  label: 'SH',
                  value: _heroMeterSummary(hero.spiritHealth),
                ),
                const SizedBox(height: 2),
                _buildHeroStatRow(
                  theme,
                  icon: Icons.bolt_rounded,
                  label: 'PE',
                  value: _heroMeterSummary(hero.physicalEnergy),
                ),
                const SizedBox(height: 2),
                _buildHeroStatRow(
                  theme,
                  icon: Icons.auto_awesome_rounded,
                  label: 'SP',
                  value: _heroMeterSummary(hero.spiritEnergy),
                ),
                const SizedBox(height: 2),
                _buildHeroStatRow(
                  theme,
                  icon: Icons.attach_money_rounded,
                  label: r'$',
                  value: _heroMeterSummary(hero.money),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroStatRow(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 12, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroSection(
    ThemeData theme,
    Map<String, String> t,
    String locale,
  ) {
    if (_heroes.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.text('Select Hero'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 232,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _heroes.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) =>
                  _buildHeroCard(_heroes[index], theme, locale),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeckSlotCard(
    int slot,
    ThemeData theme,
    Map<String, String> t, {
    required double width,
  }) {
    final deck = _deckForSlot(slot);
    final isActive = _activeSlot == slot;
    final isEmpty = deck == null;

    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _isSaving ? null : () => _activateSlot(slot),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isActive
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.6,
                    ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isActive
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
                width: isActive ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '#$slot',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isActive
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      isEmpty
                          ? Icons.add_circle_outline_rounded
                          : Icons.style_outlined,
                      size: 18,
                      color: isActive
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  deck?.name ?? t.text('New Deck'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  deck == null ? '8/8' : '${deck.cards.length}/8',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeckSlotSection(ThemeData theme, Map<String, String> t) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _isSaving || _nextAvailableSlot == null
                  ? null
                  : _startNewDeck,
              icon: const Icon(Icons.add_rounded),
              label: Text(t.text('New Deck')),
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final singleColumn = constraints.maxWidth < 560;
              final slotWidth = singleColumn
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 24) / 3;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: List.generate(
                  _maxDeckSlots,
                  (index) =>
                      _buildDeckSlotCard(index + 1, theme, t, width: slotWidth),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return FilterChip(
      selected: selected,
      onSelected: (_) => onTap(),
      avatar: icon == null ? null : Icon(icon, size: 16),
      label: Text(label),
      showCheckmark: false,
    );
  }

  Widget _buildCardFilterSection(ThemeData theme, Map<String, String> t) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.text('Type'),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFilterChip(
                label: t.text('All'),
                selected: _cardCategoryFilter == _categoryAll,
                onTap: () => setState(() {
                  _cardCategoryFilter = _categoryAll;
                }),
                icon: Icons.apps_rounded,
              ),
              _buildFilterChip(
                label: t.text('Unit'),
                selected: _cardCategoryFilter == _categoryUnit,
                onTap: () => setState(() {
                  _cardCategoryFilter = _categoryUnit;
                }),
                icon: Icons.shield_outlined,
              ),
              _buildFilterChip(
                label: t.text('Equipment'),
                selected: _cardCategoryFilter == _categoryEquipment,
                onTap: () => setState(() {
                  _cardCategoryFilter = _categoryEquipment;
                }),
                icon: Icons.auto_fix_high_rounded,
              ),
              _buildFilterChip(
                label: t.text('Spell'),
                selected: _cardCategoryFilter == _categorySpell,
                onTap: () => setState(() {
                  _cardCategoryFilter = _categorySpell;
                }),
                icon: Icons.local_fire_department_outlined,
              ),
              _buildFilterChip(
                label: t.text('Building'),
                selected: _cardCategoryFilter == _categoryBuilding,
                onTap: () => setState(() {
                  _cardCategoryFilter = _categoryBuilding;
                }),
                icon: Icons.fort_outlined,
              ),
              _buildFilterChip(
                label: t.text('Job'),
                selected: _cardCategoryFilter == _categoryJob,
                onTap: () => setState(() {
                  _cardCategoryFilter = _categoryJob;
                }),
                icon: Icons.work_outline_rounded,
              ),
              _buildFilterChip(
                label: t.text('Field Event'),
                selected: _cardCategoryFilter == _categoryFieldEvent,
                onTap: () => setState(() {
                  _cardCategoryFilter = _categoryFieldEvent;
                }),
                icon: Icons.casino_outlined,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            t.text('Energy Cost'),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFilterChip(
                label: t.text('All'),
                selected: _energyFilter == null,
                onTap: () => setState(() {
                  _energyFilter = null;
                }),
                icon: Icons.tune_rounded,
              ),
              for (final value in [1, 2, 3, 4])
                _buildFilterChip(
                  label: '$value',
                  selected: _energyFilter == value,
                  onTap: () => setState(() {
                    _energyFilter = value;
                  }),
                  icon: Icons.bolt_rounded,
                ),
              _buildFilterChip(
                label: '5+',
                selected: _energyFilter == 5,
                onTap: () => setState(() {
                  _energyFilter = 5;
                }),
                icon: Icons.bolt_rounded,
              ),
            ],
          ),
        ],
      ),
    );
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
      case 'job':
        return const Color(0xFF6D8E23);
      default:
        return const Color(0xFF6D4C41);
    }
  }

  String _cardTypeLabel(Map<String, String> t, RoyaleCard card) {
    switch (card.type) {
      case 'tank':
        return t.text('Tank');
      case 'ranged':
        return t.text('Ranged');
      case 'swarm':
        return t.text('Swarm');
      case 'spell':
        return t.text('Spell');
      case 'equipment':
        return t.text('Equipment');
      case 'job':
        return t.text('Job');
      default:
        return t.text('Melee');
    }
  }

  String _energyTypeLabel(Map<String, String> t, RoyaleCard card) {
    if (card.usesMoney) {
      return t.text('Money');
    }
    return card.usesSpiritEnergy
        ? t.text('Spirit Energy')
        : t.text('Physical Energy');
  }

  String _energyTypeShortLabel(String locale, RoyaleCard card) {
    if (locale == 'ja') {
      return card.usesMoney ? '金' : card.usesSpiritEnergy ? '精' : '体';
    }
    if (locale == 'zh-Hant') {
      return card.usesMoney ? '金' : card.usesSpiritEnergy ? '精' : '生';
    }
    return card.usesMoney ? r'$' : card.usesSpiritEnergy ? 'SP' : 'PH';
  }

  String _energyCostLabel(
    Map<String, String> t,
    RoyaleCard card,
    String locale, {
    bool compact = false,
  }) {
    if (compact) {
      return '${_energyTypeShortLabel(locale, card)} ${card.energyCost}';
    }
    return '${_energyTypeLabel(t, card)} ${card.energyCost}';
  }

  String _jobProfileLabel(Map<String, String> t, RoyaleCard card) {
    switch (card.effectKind) {
      case 'job_delivery':
        return t.text('Delivery Gig');
      case 'job_day_labor':
        return t.text('Day Labor');
      case 'job_part_time':
      default:
        return t.text('Part-time Shift');
    }
  }

  String _cardSummary(Map<String, String> t, RoyaleCard card) {
    if (card.isJob) {
      return '${_jobProfileLabel(t, card)} · ${t.text('Base Pay')} ${card.effectValue.toInt()}';
    }
    if (card.type == 'spell') {
      return '${t.text('Spell Damage')} ${card.spellDamage}';
    }
    if (card.type == 'equipment') {
      switch (card.effectKind) {
        case 'damage_boost':
          return '${t.text('Equipment: +Damage')} ${card.effectValue.toInt()}';
        case 'health_boost':
          return '${t.text('Equipment: +Health')} ${card.effectValue.toInt()}';
        case 'speed_boost':
          return '${t.text('Equipment: +Speed')} ${(card.effectValue * 100).toInt()}%';
        default:
          return t.text('Equipment Card');
      }
    }
    final spawnText = card.spawnCount > 1 ? ' x${card.spawnCount}' : '';
    return '${t.text('HP')} ${card.hp} / ${t.text('Damage')} ${card.damage}$spawnText';
  }

  String _targetRuleLabel(Map<String, String> t, RoyaleCard card) {
    switch (card.targetRule) {
      case 'ground':
        return t.text('Ground');
      case 'area':
        return t.text('Area');
      case 'tower':
        return t.text('Enemy Base');
      case 'ally_combo':
        return t.text('Ally Combo');
      case 'self':
        return t.text('Self');
      default:
        return card.targetRule;
    }
  }

  Widget _buildDetailStatTile(
    ThemeData theme, {
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      width: 132,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedDeckCard(
    RoyaleCard card,
    ThemeData theme,
    String locale,
  ) {
    final selectionIndex = _selectedIndexFor(card.id);
    final isPreviewed = _previewCard?.id == card.id;

    return SizedBox(
      width: 156,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _setPreviewCard(card),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isPreviewed
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isPreviewed
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
                width: isPreviewed ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${selectionIndex + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => _toggleCard(card),
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
                  ],
                ),
                Expanded(
                  child: Center(
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: _cardColor(
                          card.type,
                          theme.colorScheme,
                        ).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: card.imageUrl != null && card.imageUrl!.isNotEmpty
                          ? Image.network(
                              card.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.image_not_supported_outlined,
                              ),
                            )
                          : const Icon(Icons.style_outlined),
                    ),
                  ),
                ),
                Text(
                  card.localizedName(locale),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_cardTypeLabel(context.read<LocaleProvider>().translation, card)}  •  ${_energyCostLabel(context.read<LocaleProvider>().translation, card, locale, compact: true)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedDeckSection(
    ThemeData theme,
    Map<String, String> t,
    String locale,
  ) {
    final selectedCards = _selectedCards;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${t.text('Selected Cards')} ${selectedCards.length}/8',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 168,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: selectedCards.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) =>
                  _buildSelectedDeckCard(selectedCards[index], theme, locale),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewPanel(
    ThemeData theme,
    Map<String, String> t,
    String locale,
  ) {
    final card = _previewCard;
    if (card == null) {
      return const SizedBox.shrink();
    }

    final selectionIndex = _selectedIndexFor(card.id);
    final isSelected = selectionIndex >= 0;
    final canAdd = isSelected || _selectedCardIds.length < 8;

    final detailTiles = <Widget>[
      _buildDetailStatTile(
        theme,
        label: t.text('Energy Cost'),
        value: _energyCostLabel(t, card, locale),
        icon: Icons.bolt_rounded,
      ),
      _buildDetailStatTile(
        theme,
        label: t.text('Type'),
        value: _cardTypeLabel(t, card),
        icon: Icons.category_outlined,
      ),
      _buildDetailStatTile(
        theme,
        label: t.text('Target Rule'),
        value: _targetRuleLabel(t, card),
        icon: Icons.my_location_rounded,
      ),
    ];

    if (card.isJob) {
      detailTiles.addAll([
        _buildDetailStatTile(
          theme,
          label: t.text('Work Profile'),
          value: _jobProfileLabel(t, card),
          icon: Icons.work_outline_rounded,
        ),
        _buildDetailStatTile(
          theme,
          label: t.text('Base Pay'),
          value: '${card.effectValue.toInt()}',
          icon: Icons.attach_money_rounded,
        ),
      ]);
    } else if (card.type == 'spell') {
      detailTiles.addAll([
        _buildDetailStatTile(
          theme,
          label: t.text('Spell Damage'),
          value: '${card.spellDamage}',
          icon: Icons.local_fire_department_outlined,
        ),
        _buildDetailStatTile(
          theme,
          label: t.text('Area'),
          value: '${card.spellRadius}',
          icon: Icons.blur_circular_rounded,
        ),
      ]);
    } else if (card.type == 'equipment') {
      detailTiles.add(
        _buildDetailStatTile(
          theme,
          label: t.text('Equipment'),
          value: _cardSummary(t, card),
          icon: Icons.auto_fix_high_rounded,
        ),
      );
    } else {
      detailTiles.addAll([
        _buildDetailStatTile(
          theme,
          label: t.text('HP'),
          value: '${card.hp}',
          icon: Icons.favorite_border_rounded,
        ),
        _buildDetailStatTile(
          theme,
          label: t.text('Damage'),
          value: '${card.damage}',
          icon: Icons.flash_on_outlined,
        ),
        _buildDetailStatTile(
          theme,
          label: t.text('Attack Range'),
          value: '${card.attackRange}',
          icon: Icons.straighten_rounded,
        ),
        _buildDetailStatTile(
          theme,
          label: t.text('Attack Speed'),
          value: card.attackSpeed.toStringAsFixed(2),
          icon: Icons.speed_rounded,
        ),
        _buildDetailStatTile(
          theme,
          label: t.text('Move Speed'),
          value: '${card.moveSpeed}',
          icon: Icons.directions_run_rounded,
        ),
        if (card.spawnCount > 1)
          _buildDetailStatTile(
            theme,
            label: t.text('Spawn Count'),
            value: '${card.spawnCount}',
            icon: Icons.groups_2_outlined,
          ),
      ]);
    }

    final previewCardArt = Container(
      width: 112,
      height: 112,
      decoration: BoxDecoration(
        color: _cardColor(card.type, theme.colorScheme).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(22),
      ),
      clipBehavior: Clip.antiAlias,
      child: card.imageUrl != null && card.imageUrl!.isNotEmpty
          ? Image.network(
              card.imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.image_not_supported_outlined, size: 34),
            )
          : const Icon(Icons.style_outlined, size: 38),
    );

    final previewInfo = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.text('Card Details'),
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          card.localizedName(locale),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _cardSummary(t, card),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(
              avatar: const Icon(Icons.style_outlined, size: 18),
              label: Text(_cardTypeLabel(t, card)),
            ),
            Chip(
              avatar: const Icon(Icons.badge_outlined, size: 18),
              label: Text('${t.text('Card ID')}: ${card.id}'),
            ),
            if (isSelected)
              Chip(
                avatar: const Icon(Icons.check_circle_outline, size: 18),
                label: Text('#${selectionIndex + 1} / 8'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            FilledButton.icon(
              onPressed: canAdd ? () => _toggleCard(card) : null,
              icon: Icon(
                isSelected ? Icons.remove_circle_outline : Icons.add_rounded,
              ),
              label: Text(isSelected ? t.text('Remove') : t.text('Add')),
            ),
          ],
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 720;
              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    previewCardArt,
                    const SizedBox(height: 16),
                    previewInfo,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  previewCardArt,
                  const SizedBox(width: 18),
                  Expanded(child: previewInfo),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Wrap(spacing: 10, runSpacing: 10, children: detailTiles),
        ],
      ),
    );
  }

  Widget _buildAvailableCardTile(
    RoyaleCard card,
    ThemeData theme,
    Map<String, String> t,
    String locale,
  ) {
    final isSelected = _isSelectedCard(card.id);
    final selectionIndex = _selectedIndexFor(card.id);
    final isPreviewed = _previewCard?.id == card.id;
    final color = _cardColor(card.type, theme.colorScheme);
    final canAdd = isSelected || _selectedCardIds.length < 8;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _setPreviewCard(card),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isPreviewed ? 0.9 : 0.76),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isPreviewed
                  ? theme.colorScheme.primary
                  : isSelected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.2),
              width: isPreviewed ? 2.6 : (isSelected ? 2 : 1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: card.imageUrl != null && card.imageUrl!.isNotEmpty
                        ? Image.network(
                            card.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.image_not_supported_outlined,
                              color: Colors.white70,
                            ),
                          )
                        : const Icon(Icons.style_outlined, color: Colors.white),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          card.localizedName(locale),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _cardTypeLabel(t, card),
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.black.withValues(alpha: 0.18),
                    child: Text(
                      _energyTypeShortLabel(locale, card),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _cardSummary(t, card),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Text(
                _energyCostLabel(t, card, locale),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '#${selectionIndex + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: canAdd ? () => _toggleCard(card) : null,
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: Colors.white,
                      foregroundColor: color,
                    ),
                    icon: Icon(
                      isSelected
                          ? Icons.remove_circle_outline
                          : Icons.add_circle_outline_rounded,
                      size: 18,
                    ),
                    label: Text(isSelected ? t.text('Remove') : t.text('Add')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.watch<LocaleProvider>().translation;
    final locale = context.watch<LocaleProvider>().locale;
    final filteredCards = _filteredCards;

    return Scaffold(
      appBar: AppBar(title: Text(t.text('Mini Royale Deck Builder'))),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildDeckSlotSection(theme, t),
                  const SizedBox(height: 16),
                  _buildHeroSection(theme, t, locale),
                  const SizedBox(height: 16),
                  _buildPreviewPanel(theme, t, locale),
                  const SizedBox(height: 16),
                  Text(
                    '#$_activeSlot',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: t.text('Deck Name'),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSelectedDeckSection(theme, t, locale),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _save,
                          icon: const Icon(Icons.save_outlined),
                          label: Text(
                            _isSaving
                                ? t.text('Saving...')
                                : t.text('Save Deck'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          final hero = _heroes
                              .where((h) => h.id == _selectedHeroId)
                              .firstOrNull;
                          Navigator.of(context).pushNamed(
                            '/royale-lobby',
                            arguments: {
                              'heroId': _selectedHeroId,
                              'heroName':
                                  hero?.localizedName(locale) ??
                                  _selectedHeroId,
                            },
                          );
                        },
                        icon: const Icon(Icons.sports_esports_outlined),
                        label: Text(t.text('Go to Lobby')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _cardCategoryFilter == _categoryFieldEvent
                        ? t.text('Field Events')
                        : t.text('Available Cards'),
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  _buildCardFilterSection(theme, t),
                  const SizedBox(height: 12),
                  if (_cardCategoryFilter == _categoryFieldEvent)
                    _buildFieldEventGrid(theme, locale)
                  else if (filteredCards.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Center(
                        child: Text(
                          t.text('No cards found'),
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 260,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.92,
                          ),
                      itemCount: filteredCards.length,
                      itemBuilder: (context, index) => _buildAvailableCardTile(
                        filteredCards[index],
                        theme,
                        t,
                        locale,
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  // ── Field Events ────────────────────────────────────────────────

  Color _fieldEventColor(String tone, ColorScheme scheme) {
    switch (tone) {
      case 'positive':
        return const Color(0xFF2E7D32);
      case 'negative':
        return const Color(0xFFC62828);
      case 'mixed':
      default:
        return const Color(0xFF5C6BC0);
    }
  }

  Color _fieldEventCategoryColor(String category) {
    switch (category) {
      case 'traffic':
        return const Color(0xFF7B5EA7);
      case 'security':
        return const Color(0xFF8D1A1A);
      case 'politics':
        return const Color(0xFF1A5276);
      case 'family':
        return const Color(0xFF4A7A4A);
      case 'company':
        return const Color(0xFF7A5C20);
      case 'recovery':
        return const Color(0xFF1A6B5C);
      case 'food':
        return const Color(0xFF8B4513);
      case 'delivery':
        return const Color(0xFF4A6080);
      default:
        return const Color(0xFF5C6BC0);
    }
  }

  String _fieldEventCategoryLabel(String category, Map<String, String> t) {
    switch (category) {
      case 'traffic':
        return t.text('Traffic');
      case 'security':
        return t.text('Security');
      case 'politics':
        return t.text('Politics');
      case 'family':
        return t.text('Family');
      case 'company':
        return t.text('Company');
      case 'recovery':
        return t.text('Recovery');
      case 'food':
        return t.text('Food');
      case 'delivery':
        return t.text('Delivery');
      default:
        return category;
    }
  }

  Widget _buildFieldEventGrid(ThemeData theme, String locale) {
    final t = context.read<LocaleProvider>().translation;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 320,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.68,
      ),
      itemCount: kFieldEventCatalog.length,
      itemBuilder: (context, index) =>
          _buildFieldEventTile(kFieldEventCatalog[index], theme, t, locale),
    );
  }

  Widget _buildFieldEventTile(
    RoyaleFieldEventInfo event,
    ThemeData theme,
    Map<String, String> t,
    String locale,
  ) {
    final baseColor = _fieldEventColor(event.tone, theme.colorScheme);
    final catColor = _fieldEventCategoryColor(event.category);

    final toneIcon = event.tone == 'positive'
        ? Icons.trending_up_rounded
        : event.tone == 'negative'
        ? Icons.trending_down_rounded
        : Icons.sync_alt_rounded;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: baseColor.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(toneIcon, color: Colors.white, size: 22),
              ),
              Expanded(
                child: Text(
                  event.localizedTitle(locale),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Category + timing badges
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.80),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _fieldEventCategoryLabel(event.category, t),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (event.isPersistent)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.timer_outlined,
                        size: 12,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${(event.duration / 1000).toInt()}s',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              if (event.isShield)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.80),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.shield_outlined,
                        size: 12,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        t.text('Shield'),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Description
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                event.localizedDescription(locale),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.88),
                  height: 1.45,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
