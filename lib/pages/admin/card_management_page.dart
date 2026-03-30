import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../models/royale_models.dart';
import '../../services/admin_service.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/locale_provider.dart';

class CardManagementPage extends StatefulWidget {
  const CardManagementPage({super.key});

  @override
  State<CardManagementPage> createState() => _CardManagementPageState();
}

class _CardManagementPageState extends State<CardManagementPage> {
  static const List<String> _typeOptions = [
    'melee',
    'ranged',
    'tank',
    'swarm',
    'spell',
    'equipment',
  ];

  static const List<String> _targetRuleOptions = [
    'ground',
    'tower',
    'area',
    'ally_combo',
  ];

  static const List<String> _effectKindOptions = [
    'none',
    'damage_boost',
    'health_boost',
    'speed_boost',
  ];

  late final AdminService _adminService;

  final TextEditingController _idController = TextEditingController();
  final TextEditingController _nameZhHantController = TextEditingController();
  final TextEditingController _nameEnController = TextEditingController();
  final TextEditingController _nameJaController = TextEditingController();
  final TextEditingController _elixirCostController = TextEditingController();
  final TextEditingController _hpController = TextEditingController();
  final TextEditingController _damageController = TextEditingController();
  final TextEditingController _attackRangeController = TextEditingController();
  final TextEditingController _bodyRadiusController = TextEditingController();
  final TextEditingController _moveSpeedController = TextEditingController();
  final TextEditingController _attackSpeedController = TextEditingController();
  final TextEditingController _spawnCountController = TextEditingController();
  final TextEditingController _spellRadiusController = TextEditingController();
  final TextEditingController _spellDamageController = TextEditingController();
  final TextEditingController _effectValueController = TextEditingController();

  List<RoyaleCard> _cards = const [];
  Uint8List? _pendingImageBytes;
  String? _pendingImageMimeType;
  String? _pendingImageFileName;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isDeleting = false;
  bool _isUploadingImage = false;
  bool _isRemovingImage = false;
  bool _isCreatingNew = true;
  String? _selectedCardId;
  String _selectedType = _typeOptions.first;
  String _selectedTargetRule = _targetRuleOptions.first;
  String _selectedEffectKind = _effectKindOptions.first;

  @override
  void initState() {
    super.initState();
    _adminService = AdminService(ApiClient());
    _applyNewCardDefaults();
    _loadCards();
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameZhHantController.dispose();
    _nameEnController.dispose();
    _nameJaController.dispose();
    _elixirCostController.dispose();
    _hpController.dispose();
    _damageController.dispose();
    _attackRangeController.dispose();
    _bodyRadiusController.dispose();
    _moveSpeedController.dispose();
    _attackSpeedController.dispose();
    _spawnCountController.dispose();
    _spellRadiusController.dispose();
    _spellDamageController.dispose();
    _effectValueController.dispose();
    super.dispose();
  }

  bool _canManageCards(AppUser user) {
    return user.role == 'admin' || user.role == 'card_manager';
  }

  Future<void> _loadCards({String? preferCardId}) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final cards = await _adminService.fetchCards();
      if (!mounted) {
        return;
      }

      final selectedId = preferCardId ?? _selectedCardId;
      RoyaleCard? selectedCard;
      if (selectedId != null) {
        for (final card in cards) {
          if (card.id == selectedId) {
            selectedCard = card;
            break;
          }
        }
      }
      selectedCard ??= cards.isNotEmpty ? cards.first : null;

      setState(() {
        _cards = cards;
      });

      if (selectedCard != null) {
        _applyCard(selectedCard);
      } else {
        _applyNewCardDefaults();
      }
    } on ApiException catch (error) {
      _showSnackBar(error.message);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _applyCard(RoyaleCard card) {
    setState(() {
      _isCreatingNew = false;
      _selectedCardId = card.id;
      _selectedType = card.type;
      _selectedTargetRule = card.targetRule;
      _selectedEffectKind = card.effectKind;
      _idController.text = card.id;
      _nameZhHantController.text = card.nameZhHant;
      _nameEnController.text = card.nameEn;
      _nameJaController.text = card.nameJa;
      _elixirCostController.text = card.elixirCost.toString();
      _hpController.text = card.hp.toString();
      _damageController.text = card.damage.toString();
      _attackRangeController.text = card.attackRange.toString();
      _bodyRadiusController.text = card.bodyRadius.toString();
      _moveSpeedController.text = card.moveSpeed.toString();
      _attackSpeedController.text = card.attackSpeed.toString();
      _spawnCountController.text = card.spawnCount.toString();
      _spellRadiusController.text = card.spellRadius.toString();
      _spellDamageController.text = card.spellDamage.toString();
      _effectValueController.text = card.effectValue.toString();
      _pendingImageBytes = null;
      _pendingImageMimeType = null;
      _pendingImageFileName = null;
    });
  }

  void _applyNewCardDefaults() {
    setState(() {
      _isCreatingNew = true;
      _selectedCardId = null;
      _selectedType = _typeOptions.first;
      _selectedTargetRule = _targetRuleOptions.first;
      _selectedEffectKind = _effectKindOptions.first;
      _idController.clear();
      _nameZhHantController.clear();
      _nameEnController.clear();
      _nameJaController.clear();
      _elixirCostController.text = '3';
      _hpController.text = '300';
      _damageController.text = '100';
      _attackRangeController.text = '100';
      _bodyRadiusController.text = '18';
      _moveSpeedController.text = '150';
      _attackSpeedController.text = '1';
      _spawnCountController.text = '1';
      _spellRadiusController.text = '0';
      _spellDamageController.text = '0';
      _effectValueController.text = '0';
      _pendingImageBytes = null;
      _pendingImageMimeType = null;
      _pendingImageFileName = null;
    });
  }

  RoyaleCard? _selectedCard() {
    final cardId = _selectedCardId;
    if (cardId == null) {
      return null;
    }
    for (final card in _cards) {
      if (card.id == cardId) {
        return card;
      }
    }
    return null;
  }

  int _parseIntField(TextEditingController controller, String label) {
    final value = int.tryParse(controller.text.trim());
    if (value == null) {
      throw FormatException(_invalidNumberMessage(label));
    }
    return value;
  }

  double _parseDoubleField(TextEditingController controller, String label) {
    final value = double.tryParse(controller.text.trim());
    if (value == null) {
      throw FormatException(_invalidNumberMessage(label));
    }
    return value;
  }

  String _invalidNumberMessage(String label) {
    final t = context.read<LocaleProvider>().translation;
    return '${t.text('Please enter a valid number for')} $label';
  }

  Map<String, dynamic> _buildPayload() {
    final t = context.read<LocaleProvider>().translation;
    final nameZhHant = _nameZhHantController.text.trim();
    final nameEn = _nameEnController.text.trim();
    final nameJa = _nameJaController.text.trim();
    return {
      'id': _idController.text.trim(),
      'nameZhHant': nameZhHant,
      'nameEn': nameEn,
      'nameJa': nameJa,
      'nameI18n': {'zh-Hant': nameZhHant, 'en': nameEn, 'ja': nameJa},
      'elixirCost': _parseIntField(
        _elixirCostController,
        t.text('Elixir Cost'),
      ),
      'type': _selectedType,
      'hp': _parseIntField(_hpController, t.text('HP')),
      'damage': _parseIntField(_damageController, t.text('Damage')),
      'attackRange': _parseIntField(
        _attackRangeController,
        t.text('Attack Range'),
      ),
      'bodyRadius': _parseIntField(
        _bodyRadiusController,
        t.text('Body Radius'),
      ),
      'moveSpeed': _parseIntField(_moveSpeedController, t.text('Move Speed')),
      'attackSpeed': _parseDoubleField(
        _attackSpeedController,
        t.text('Attack Speed'),
      ),
      'spawnCount': _parseIntField(
        _spawnCountController,
        t.text('Spawn Count'),
      ),
      'spellRadius': _parseIntField(
        _spellRadiusController,
        t.text('Spell Radius'),
      ),
      'spellDamage': _parseIntField(
        _spellDamageController,
        t.text('Spell Damage'),
      ),
      'targetRule': _selectedTargetRule,
      'effectKind': _selectedEffectKind,
      'effectValue': _parseDoubleField(
        _effectValueController,
        t.text('Effect Value'),
      ),
    };
  }

  Future<void> _saveCard() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final saved = await _adminService.upsertCard(_buildPayload());
      if (!mounted) {
        return;
      }
      await _loadCards(preferCardId: saved.id);
      if (!mounted) {
        return;
      }
      _showSnackBar(
        context.read<LocaleProvider>().translation.text(
          'Card saved successfully',
        ),
      );
    } on FormatException catch (error) {
      _showSnackBar(error.message);
    } on ApiException catch (error) {
      _showSnackBar(error.message);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _deleteCard() async {
    final cardId = _selectedCardId;
    if (cardId == null || _isCreatingNew) {
      return;
    }

    setState(() {
      _isDeleting = true;
    });

    try {
      await _adminService.deleteCard(cardId);
      if (!mounted) {
        return;
      }
      _applyNewCardDefaults();
      await _loadCards();
      if (!mounted) {
        return;
      }
      _showSnackBar(
        context.read<LocaleProvider>().translation.text(
          'Card deleted successfully',
        ),
      );
    } on ApiException catch (error) {
      _showSnackBar(error.message);
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  String? _detectImageMimeType(PlatformFile file) {
    final extension = (file.extension ?? '').toLowerCase();
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      default:
        return null;
    }
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (!mounted || result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      _showSnackBar(
        context.read<LocaleProvider>().translation.text(
          'Selected file has no readable bytes',
        ),
      );
      return;
    }

    final mimeType = _detectImageMimeType(file);
    if (mimeType == null) {
      _showSnackBar(
        context.read<LocaleProvider>().translation.text(
          'Selected image is unsupported',
        ),
      );
      return;
    }

    if (bytes.length > 1024 * 1024) {
      _showSnackBar(
        context.read<LocaleProvider>().translation.text(
          'Image must be 1 MB or smaller',
        ),
      );
      return;
    }

    setState(() {
      _pendingImageBytes = bytes;
      _pendingImageMimeType = mimeType;
      _pendingImageFileName = file.name;
    });
  }

  Future<void> _uploadImage() async {
    final card = _selectedCard();
    if (card == null || _isCreatingNew) {
      _showSnackBar(
        context.read<LocaleProvider>().translation.text(
          'Save the card first before uploading an image',
        ),
      );
      return;
    }
    if (_pendingImageBytes == null || _pendingImageMimeType == null) {
      return;
    }

    setState(() {
      _isUploadingImage = true;
    });

    try {
      final updated = await _adminService.uploadCardImage(
        cardId: card.id,
        bytesBase64: base64Encode(_pendingImageBytes!),
        contentType: _pendingImageMimeType!,
        fileName: _pendingImageFileName,
      );
      if (!mounted) {
        return;
      }
      await _loadCards(preferCardId: updated.id);
      if (!mounted) {
        return;
      }
      _showSnackBar(
        context.read<LocaleProvider>().translation.text(
          'Image uploaded successfully',
        ),
      );
    } on ApiException catch (error) {
      _showSnackBar(error.message);
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  Future<void> _removeImage() async {
    final card = _selectedCard();
    if (card == null || _isCreatingNew) {
      return;
    }

    setState(() {
      _isRemovingImage = true;
    });

    try {
      await _adminService.deleteCardImage(card.id);
      if (!mounted) {
        return;
      }
      await _loadCards(preferCardId: card.id);
      if (!mounted) {
        return;
      }
      _showSnackBar(
        context.read<LocaleProvider>().translation.text(
          'Image removed successfully',
        ),
      );
    } on ApiException catch (error) {
      _showSnackBar(error.message);
    } finally {
      if (mounted) {
        setState(() {
          _isRemovingImage = false;
        });
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _typeLabel(Map<String, String> t, String value) {
    switch (value) {
      case 'melee':
        return t.text('Melee');
      case 'ranged':
        return t.text('Ranged');
      case 'tank':
        return t.text('Tank');
      case 'swarm':
        return t.text('Swarm');
      case 'spell':
        return t.text('Spell');
      case 'equipment':
        return t.text('Equipment');
      default:
        return value;
    }
  }

  String _targetRuleLabel(Map<String, String> t, String value) {
    switch (value) {
      case 'ground':
        return t.text('Ground');
      case 'tower':
        return t.text('Tower');
      case 'area':
        return t.text('Area');
      case 'ally_combo':
        return t.text('Ally Combo');
      default:
        return value;
    }
  }

  String _effectKindLabel(Map<String, String> t, String value) {
    switch (value) {
      case 'none':
        return t.text('None');
      case 'damage_boost':
        return t.text('Damage Boost');
      case 'health_boost':
        return t.text('Health Boost');
      case 'speed_boost':
        return t.text('Speed Boost');
      default:
        return value;
    }
  }

  Widget _buildCardList(Map<String, String> t) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    t.text('Card List'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                FilledButton.icon(
                  onPressed: _applyNewCardDefaults,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(t.text('New Card')),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_cards.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text(t.text('No cards found'))),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 720),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _cards.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final card = _cards[index];
                    final selected =
                        !_isCreatingNew && _selectedCardId == card.id;
                    return ListTile(
                      selected: selected,
                      selectedTileColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withValues(alpha: 0.45),
                      leading: _CardImageThumbnail(card: card),
                      title: Text(
                        card.localizedName(
                          context.read<LocaleProvider>().locale,
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${card.id} · ${_typeLabel(t, card.type)} · ${t.text('Elixir Cost')} ${card.elixirCost}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _applyCard(card),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberField(
    Map<String, String> t,
    TextEditingController controller,
    String label, {
    String? hint,
    String? helper,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: t.text(label),
        hintText: hint,
        helperText: helper == null ? null : t.text(helper),
      ),
    );
  }

  Widget _buildForm(Map<String, String> t) {
    final selectedCard = _selectedCard();
    final formIntro = _isCreatingNew
        ? t.text('Create a new card')
        : t.text(
            'Editing existing card IDs is disabled. Create a new card if you need a different ID.',
          );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.text('Card Management'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              t.text(
                'Create or edit card stats and effects. Changes are saved to the live cards table immediately.',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              t.text(
                'Cards are stored in the D1 cards table. Starter definitions live in src/royale_cards.js and seed the table when empty.',
              ),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.tertiaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                t.text(
                  'World unit scale: the battlefield uses 1000-based integer coordinates. Example: Attack Range 280 means 28% of the map height, and Body Radius 18 means the unit body takes 1.8% of the map height.',
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.secondaryContainer.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(formIntro),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _idController,
              enabled: _isCreatingNew,
              decoration: InputDecoration(
                labelText: t.text('Card ID'),
                hintText: 'swordsman',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameZhHantController,
              decoration: InputDecoration(
                labelText: t.text('Card Name (Traditional Chinese)'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameEnController,
              decoration: InputDecoration(
                labelText: t.text('Card Name (English)'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameJaController,
              decoration: InputDecoration(
                labelText: t.text('Card Name (Japanese)'),
              ),
            ),
            const SizedBox(height: 12),
            _CardImageEditor(
              card: selectedCard,
              pendingImageBytes: _pendingImageBytes,
              onPickImage: _pickImage,
              onUploadImage: _uploadImage,
              onRemoveImage: _removeImage,
              isCreatingNew: _isCreatingNew,
              isUploadingImage: _isUploadingImage,
              isRemovingImage: _isRemovingImage,
              hasPendingImage: _pendingImageBytes != null,
              translation: t,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 220,
                  child: _buildNumberField(
                    t,
                    _elixirCostController,
                    'Elixir Cost',
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('type-$_selectedType-$_selectedCardId'),
                    initialValue: _selectedType,
                    decoration: InputDecoration(labelText: t.text('Type')),
                    items: _typeOptions
                        .map(
                          (value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(_typeLabel(t, value)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _selectedType = value;
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(
                      'target-$_selectedTargetRule-$_selectedCardId',
                    ),
                    initialValue: _selectedTargetRule,
                    decoration: InputDecoration(
                      labelText: t.text('Target Rule'),
                    ),
                    items: _targetRuleOptions
                        .map(
                          (value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(_targetRuleLabel(t, value)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _selectedTargetRule = value;
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(
                      'effect-$_selectedEffectKind-$_selectedCardId',
                    ),
                    initialValue: _selectedEffectKind,
                    decoration: InputDecoration(
                      labelText: t.text('Effect Kind'),
                    ),
                    items: _effectKindOptions
                        .map(
                          (value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(_effectKindLabel(t, value)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _selectedEffectKind = value;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 180,
                  child: _buildNumberField(
                    t,
                    _hpController,
                    'HP',
                    helper: 'Hit points. Uses normal game damage values.',
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: _buildNumberField(
                    t,
                    _damageController,
                    'Damage',
                    helper: 'Damage dealt on each successful attack.',
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: _buildNumberField(
                    t,
                    _attackRangeController,
                    'Attack Range',
                    helper:
                        'Weapon reach in world units. This does not include the unit body radius.',
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: _buildNumberField(
                    t,
                    _bodyRadiusController,
                    'Body Radius',
                    helper:
                        'Unit body size in world units. Final reach uses body radius plus attack range.',
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: _buildNumberField(
                    t,
                    _moveSpeedController,
                    'Move Speed',
                    helper:
                        'Movement speed in world units per second before global battle multipliers.',
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: _buildNumberField(
                    t,
                    _attackSpeedController,
                    'Attack Speed',
                    helper:
                        'Seconds between attacks. Smaller values attack faster.',
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: _buildNumberField(
                    t,
                    _spawnCountController,
                    'Spawn Count',
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: _buildNumberField(
                    t,
                    _spellRadiusController,
                    'Spell Radius',
                    helper: 'Spell area radius in world units.',
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: _buildNumberField(
                    t,
                    _spellDamageController,
                    'Spell Damage',
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: _buildNumberField(
                    t,
                    _effectValueController,
                    'Effect Value',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: _isSaving ? null : _saveCard,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(t.text('Save Card')),
                ),
                OutlinedButton.icon(
                  onPressed: _isDeleting || _isCreatingNew ? null : _deleteCard,
                  icon: _isDeleting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline_rounded),
                  label: Text(t.text('Delete Card')),
                ),
                TextButton.icon(
                  onPressed: _applyNewCardDefaults,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  label: Text(t.text('Create a new card')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewer = context.watch<AuthService>().user;
    final t = context.watch<LocaleProvider>().translation;
    if (viewer == null) {
      return Scaffold(body: Center(child: Text(t.text('Please log in first'))));
    }
    if (!_canManageCards(viewer)) {
      return Scaffold(
        appBar: AppBar(title: Text(t.text('Card Management'))),
        body: Center(
          child: Text(
            t.text('Only card managers and admins can view this page'),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(t.text('Card Management')),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : () => _loadCards(),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: t.text('Refresh'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final vertical = constraints.maxWidth < 1100;
                if (vertical) {
                  return ListView(
                    children: [
                      _buildCardList(t),
                      const SizedBox(height: 16),
                      _buildForm(t),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 360, child: _buildCardList(t)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SingleChildScrollView(child: _buildForm(t)),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _CardImageThumbnail extends StatelessWidget {
  const _CardImageThumbnail({required this.card});

  final RoyaleCard card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: card.imageUrl != null && card.imageUrl!.isNotEmpty
          ? Image.network(
              card.imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(Icons.image_not_supported),
            )
          : const Icon(Icons.person_outline_rounded),
    );
  }
}

class _CardImageEditor extends StatelessWidget {
  const _CardImageEditor({
    required this.card,
    required this.pendingImageBytes,
    required this.onPickImage,
    required this.onUploadImage,
    required this.onRemoveImage,
    required this.isCreatingNew,
    required this.isUploadingImage,
    required this.isRemovingImage,
    required this.hasPendingImage,
    required this.translation,
  });

  final RoyaleCard? card;
  final Uint8List? pendingImageBytes;
  final VoidCallback onPickImage;
  final VoidCallback onUploadImage;
  final VoidCallback onRemoveImage;
  final bool isCreatingNew;
  final bool isUploadingImage;
  final bool isRemovingImage;
  final bool hasPendingImage;
  final Map<String, String> translation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl = card?.imageUrl;
    final hasSavedImage = imageUrl != null && imageUrl.isNotEmpty;

    Widget preview;
    if (pendingImageBytes != null && pendingImageBytes!.isNotEmpty) {
      preview = Image.memory(pendingImageBytes!, fit: BoxFit.contain);
    } else if (hasSavedImage) {
      preview = Image.network(
        imageUrl,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
      );
    } else {
      preview = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_outlined,
            size: 40,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            translation.text('No character image uploaded'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.45,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            translation.text('Character Image'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            translation.text('PNG, JPG, WEBP, or GIF up to 1 MB'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            height: 220,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            clipBehavior: Clip.antiAlias,
            child: preview,
          ),
          if (isCreatingNew) ...[
            const SizedBox(height: 10),
            Text(
              translation.text('Save the card first before uploading an image'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: isUploadingImage || isRemovingImage
                    ? null
                    : onPickImage,
                icon: const Icon(Icons.image_search_outlined),
                label: Text(translation.text('Choose Image')),
              ),
              OutlinedButton.icon(
                onPressed:
                    isCreatingNew ||
                        !hasPendingImage ||
                        isUploadingImage ||
                        isRemovingImage
                    ? null
                    : onUploadImage,
                icon: isUploadingImage
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload_outlined),
                label: Text(translation.text('Upload Image')),
              ),
              TextButton.icon(
                onPressed:
                    isCreatingNew ||
                        !hasSavedImage ||
                        isUploadingImage ||
                        isRemovingImage
                    ? null
                    : onRemoveImage,
                icon: isRemovingImage
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_outline_rounded),
                label: Text(translation.text('Remove Image')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
