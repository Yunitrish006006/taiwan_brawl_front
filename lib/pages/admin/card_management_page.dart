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

part 'card_management_form.dart';

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
    'job',
    'equipment',
  ];

  static const List<String> _targetRuleOptions = [
    'ground',
    'tower',
    'area',
    'self',
    'ally_combo',
  ];

  static const List<String> _effectKindOptions = [
    'none',
    'damage_boost',
    'health_boost',
    'speed_boost',
    'job_part_time',
    'job_delivery',
    'job_day_labor',
  ];
  static const List<String> _energyCostTypeOptions = ['physical', 'spirit'];

  late final AdminService _adminService;

  final TextEditingController _idController = TextEditingController();
  final TextEditingController _nameZhHantController = TextEditingController();
  final TextEditingController _nameEnController = TextEditingController();
  final TextEditingController _nameJaController = TextEditingController();
  final TextEditingController _energyCostController = TextEditingController();
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
  bool _showMobileEditor = false;
  String? _selectedCardId;
  String _selectedType = _typeOptions.first;
  String _selectedEnergyCostType = _energyCostTypeOptions.first;
  String _selectedTargetRule = _targetRuleOptions.first;
  String _selectedEffectKind = _effectKindOptions.first;

  List<TextEditingController> get _allControllers => [
    _idController,
    _nameZhHantController,
    _nameEnController,
    _nameJaController,
    _energyCostController,
    _hpController,
    _damageController,
    _attackRangeController,
    _bodyRadiusController,
    _moveSpeedController,
    _attackSpeedController,
    _spawnCountController,
    _spellRadiusController,
    _spellDamageController,
    _effectValueController,
  ];

  Map<String, String> get _t => context.read<LocaleProvider>().translation;

  @override
  void initState() {
    super.initState();
    _adminService = AdminService(ApiClient());
    _applyNewCardDefaults();
    _loadCards();
  }

  @override
  void dispose() {
    for (final controller in _allControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  bool _canManageCards(AppUser user) {
    return user.role == 'admin' || user.role == 'card_manager';
  }

  void _clearPendingImageSelection() {
    _pendingImageBytes = null;
    _pendingImageMimeType = null;
    _pendingImageFileName = null;
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
      _selectedEnergyCostType = card.energyCostType;
      _selectedTargetRule = card.targetRule;
      _selectedEffectKind = card.effectKind;
      _idController.text = card.id;
      _nameZhHantController.text = card.nameZhHant;
      _nameEnController.text = card.nameEn;
      _nameJaController.text = card.nameJa;
      _energyCostController.text = card.energyCost.toString();
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
      _clearPendingImageSelection();
    });
  }

  void _applyNewCardDefaults() {
    setState(() {
      _isCreatingNew = true;
      _selectedCardId = null;
      _selectedType = _typeOptions.first;
      _selectedEnergyCostType = _energyCostTypeOptions.first;
      _selectedTargetRule = _targetRuleOptions.first;
      _selectedEffectKind = _effectKindOptions.first;
      _idController.clear();
      _nameZhHantController.clear();
      _nameEnController.clear();
      _nameJaController.clear();
      _energyCostController.text = '3';
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
      _clearPendingImageSelection();
    });
  }

  void _openMobileEditorForCard(RoyaleCard card) {
    _applyCard(card);
    if (_showMobileEditor) {
      return;
    }
    setState(() {
      _showMobileEditor = true;
    });
  }

  void _openMobileEditorForNewCard() {
    _applyNewCardDefaults();
    if (_showMobileEditor) {
      return;
    }
    setState(() {
      _showMobileEditor = true;
    });
  }

  void _closeMobileEditor() {
    if (!_showMobileEditor) {
      return;
    }
    setState(() {
      _showMobileEditor = false;
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
    return '${_t.text('Please enter a valid number for')} $label';
  }

  Map<String, dynamic> _buildPayload() {
    final nameZhHant = _nameZhHantController.text.trim();
    final nameEn = _nameEnController.text.trim();
    final nameJa = _nameJaController.text.trim();
    return {
      'id': _idController.text.trim(),
      'nameZhHant': nameZhHant,
      'nameEn': nameEn,
      'nameJa': nameJa,
      'nameI18n': {'zh-Hant': nameZhHant, 'en': nameEn, 'ja': nameJa},
      'energyCost': _parseIntField(
        _energyCostController,
        _t.text('Energy Cost'),
      ),
      'energyCostType': _selectedEnergyCostType,
      'type': _selectedType,
      'hp': _parseIntField(_hpController, _t.text('HP')),
      'damage': _parseIntField(_damageController, _t.text('Damage')),
      'attackRange': _parseIntField(
        _attackRangeController,
        _t.text('Attack Range'),
      ),
      'bodyRadius': _parseIntField(
        _bodyRadiusController,
        _t.text('Body Radius'),
      ),
      'moveSpeed': _parseIntField(_moveSpeedController, _t.text('Move Speed')),
      'attackSpeed': _parseDoubleField(
        _attackSpeedController,
        _t.text('Attack Speed'),
      ),
      'spawnCount': _parseIntField(
        _spawnCountController,
        _t.text('Spawn Count'),
      ),
      'spellRadius': _parseIntField(
        _spellRadiusController,
        _t.text('Spell Radius'),
      ),
      'spellDamage': _parseIntField(
        _spellDamageController,
        _t.text('Spell Damage'),
      ),
      'targetRule': _selectedTargetRule,
      'effectKind': _selectedEffectKind,
      'effectValue': _parseDoubleField(
        _effectValueController,
        _t.text('Effect Value'),
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
      _showSnackBar(_t.text('Card saved successfully'));
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
      _closeMobileEditor();
      _showSnackBar(_t.text('Card deleted successfully'));
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
      _showSnackBar(_t.text('Selected file has no readable bytes'));
      return;
    }

    final mimeType = _detectImageMimeType(file);
    if (mimeType == null) {
      _showSnackBar(_t.text('Selected image is unsupported'));
      return;
    }

    if (bytes.length > 1024 * 1024) {
      _showSnackBar(_t.text('Image must be 1 MB or smaller'));
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
      _showSnackBar(_t.text('Save the card first before uploading an image'));
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
      _showSnackBar(_t.text('Image uploaded successfully'));
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
      _showSnackBar(_t.text('Image removed successfully'));
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
      case 'job':
        return t.text('Job');
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
      case 'self':
        return t.text('Self');
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
      case 'job_part_time':
        return t.text('Part-time Shift');
      case 'job_delivery':
        return t.text('Delivery Gig');
      case 'job_day_labor':
        return t.text('Day Labor');
      default:
        return value;
    }
  }

  String _energyCostTypeLabel(Map<String, String> t, String value) {
    switch (value) {
      case 'spirit':
        return t.text('Spirit Energy');
      case 'physical':
      default:
        return t.text('Physical Energy');
    }
  }

  String _cardEnergyCostLabel(Map<String, String> t, RoyaleCard card) {
    return '${_energyCostTypeLabel(t, card.energyCostType)} ${card.energyCost}';
  }

  void _setSelectedType(String value) {
    setState(() {
      final wasSpell = _selectedType == 'spell';
      _selectedType = value;
      if (_isCreatingNew) {
        if (value == 'spell') {
          _selectedEnergyCostType = 'spirit';
        } else if (wasSpell && _selectedEnergyCostType == 'spirit') {
          _selectedEnergyCostType = 'physical';
        }
      }
    });
  }

  void _setSelectedEnergyCostType(String value) {
    setState(() {
      _selectedEnergyCostType = value;
    });
  }

  void _setSelectedTargetRule(String value) {
    setState(() {
      _selectedTargetRule = value;
    });
  }

  void _setSelectedEffectKind(String value) {
    setState(() {
      _selectedEffectKind = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewer = context.watch<AuthService>().user;
    final t = context.watch<LocaleProvider>().translation;
    final phoneLayout = MediaQuery.sizeOf(context).width < 700;
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

    return PopScope<void>(
      canPop: !(phoneLayout && _showMobileEditor),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && phoneLayout && _showMobileEditor) {
          _closeMobileEditor();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: phoneLayout && _showMobileEditor
              ? IconButton(
                  onPressed: _closeMobileEditor,
                  icon: const Icon(Icons.arrow_back),
                  tooltip: t.text('Back'),
                )
              : null,
          title: Text(
            phoneLayout && _showMobileEditor
                ? (_isCreatingNew
                      ? t.text('Create a new card')
                      : t.text('Edit Card'))
                : t.text('Card Management'),
          ),
          actions: [
            IconButton(
              onPressed: _isLoading ? null : () => _loadCards(),
              icon: const Icon(Icons.refresh_rounded),
              tooltip: t.text('Refresh'),
            ),
          ],
        ),
        body: _buildPageContent(t),
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
