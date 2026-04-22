import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../models/royale_field_event_info.dart';
import '../../models/royale_models.dart';
import '../../services/admin_service.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/locale_provider.dart';

part 'card_management_form.dart';

enum _CharacterImageDirection {
  front('front', 'Front'),
  back('back', 'Back'),
  left('left', 'Left'),
  right('right', 'Right');

  const _CharacterImageDirection(this.apiValue, this.labelKey);

  final String apiValue;
  final String labelKey;
}

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
  static const List<String> _energyCostTypeOptions = [
    'physical',
    'spirit',
    'money',
  ];
  static const List<String> _characterAssetAnimationOptions = [
    'idle',
    'move',
    'attack',
  ];

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
  final TextEditingController _assetIdController = TextEditingController();
  final TextEditingController _assetFrameIndexController =
      TextEditingController(text: '0');
  final TextEditingController _assetDurationMsController =
      TextEditingController(text: '120');

  List<RoyaleCard> _cards = const [];
  Uint8List? _pendingImageBytes;
  String? _pendingImageMimeType;
  String? _pendingImageFileName;
  final Map<_CharacterImageDirection, Uint8List> _pendingCharImageBytes = {};
  final Map<_CharacterImageDirection, String> _pendingCharImageMimeTypes = {};
  final Map<_CharacterImageDirection, String?> _pendingCharImageFileNames = {};
  Uint8List? _pendingBgImageBytes;
  String? _pendingBgImageMimeType;
  String? _pendingBgImageFileName;
  Uint8List? _pendingCharacterAssetBytes;
  String? _pendingCharacterAssetMimeType;
  String? _pendingCharacterAssetFileName;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isDeleting = false;
  bool _isUploadingImage = false;
  bool _isRemovingImage = false;
  final Set<_CharacterImageDirection> _uploadingCharImageDirections = {};
  final Set<_CharacterImageDirection> _removingCharImageDirections = {};
  bool _isUploadingBgImage = false;
  bool _isRemovingBgImage = false;
  bool _isUploadingCharacterAsset = false;
  String? _removingCharacterAssetId;
  bool _isCreatingNew = true;
  bool _showMobileEditor = false;
  String? _selectedCardId;
  bool _showFieldEvents = false;
  String? _selectedFieldEventId;
  String _selectedType = _typeOptions.first;
  String _selectedEnergyCostType = _energyCostTypeOptions.first;
  String _selectedTargetRule = _targetRuleOptions.first;
  String _selectedEffectKind = _effectKindOptions.first;
  String _selectedCharacterAssetAnimation = 'move';
  _CharacterImageDirection _selectedCharacterAssetDirection =
      _CharacterImageDirection.back;
  bool _characterAssetLoop = true;

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
    _assetIdController,
    _assetFrameIndexController,
    _assetDurationMsController,
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
    _pendingCharImageBytes.clear();
    _pendingCharImageMimeTypes.clear();
    _pendingCharImageFileNames.clear();
    _pendingBgImageBytes = null;
    _pendingBgImageMimeType = null;
    _pendingBgImageFileName = null;
    _pendingCharacterAssetBytes = null;
    _pendingCharacterAssetMimeType = null;
    _pendingCharacterAssetFileName = null;
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
      _assetIdController.clear();
      _assetFrameIndexController.text = '0';
      _assetDurationMsController.text = '120';
      _selectedCharacterAssetAnimation = 'move';
      _selectedCharacterAssetDirection = _CharacterImageDirection.back;
      _characterAssetLoop = true;
      _clearPendingImageSelection();
    });
  }

  void _setSelectedCharacterAssetAnimation(String? value) {
    if (value == null || value == _selectedCharacterAssetAnimation) {
      return;
    }
    setState(() => _selectedCharacterAssetAnimation = value);
  }

  void _setSelectedCharacterAssetDirection(_CharacterImageDirection? value) {
    if (value == null || value == _selectedCharacterAssetDirection) {
      return;
    }
    setState(() => _selectedCharacterAssetDirection = value);
  }

  void _setCharacterAssetLoop(bool value) {
    if (value == _characterAssetLoop) {
      return;
    }
    setState(() => _characterAssetLoop = value);
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
    final effectiveCostType = _selectedType == 'equipment'
        ? 'money'
        : _selectedType == 'spell'
        ? 'spirit'
        : _selectedEnergyCostType;
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
      'energyCostType': effectiveCostType,
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

  Future<void> _pickCharImage(_CharacterImageDirection direction) async {
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
      _pendingCharImageBytes[direction] = bytes;
      _pendingCharImageMimeTypes[direction] = mimeType;
      _pendingCharImageFileNames[direction] = file.name;
    });
  }

  Future<void> _uploadCharImage(_CharacterImageDirection direction) async {
    final card = _selectedCard();
    if (card == null || _isCreatingNew) {
      _showSnackBar(_t.text('Save the card first before uploading an image'));
      return;
    }
    final pendingBytes = _pendingCharImageBytes[direction];
    final pendingMimeType = _pendingCharImageMimeTypes[direction];
    if (pendingBytes == null || pendingMimeType == null) {
      return;
    }
    final pendingBytesByDirection = Map.of(_pendingCharImageBytes)
      ..remove(direction);
    final pendingMimeTypesByDirection = Map.of(_pendingCharImageMimeTypes)
      ..remove(direction);
    final pendingFileNamesByDirection = Map.of(_pendingCharImageFileNames)
      ..remove(direction);

    setState(() {
      _uploadingCharImageDirections.add(direction);
    });

    try {
      final updated = await _adminService.uploadCardCharacterImage(
        cardId: card.id,
        direction: direction.apiValue,
        bytesBase64: base64Encode(pendingBytes),
        contentType: pendingMimeType,
        fileName: _pendingCharImageFileNames[direction],
      );
      if (!mounted) {
        return;
      }
      await _loadCards(preferCardId: updated.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _pendingCharImageBytes
          ..clear()
          ..addAll(pendingBytesByDirection);
        _pendingCharImageMimeTypes
          ..clear()
          ..addAll(pendingMimeTypesByDirection);
        _pendingCharImageFileNames
          ..clear()
          ..addAll(pendingFileNamesByDirection);
      });
      _showSnackBar(_t.text('Character image uploaded successfully'));
    } on ApiException catch (error) {
      _showSnackBar(error.message);
    } finally {
      if (mounted) {
        setState(() {
          _uploadingCharImageDirections.remove(direction);
        });
      }
    }
  }

  Future<void> _removeCharImage(_CharacterImageDirection direction) async {
    final card = _selectedCard();
    if (card == null || _isCreatingNew) {
      return;
    }
    final pendingBytesByDirection = Map.of(_pendingCharImageBytes);
    final pendingMimeTypesByDirection = Map.of(_pendingCharImageMimeTypes);
    final pendingFileNamesByDirection = Map.of(_pendingCharImageFileNames);

    setState(() {
      _removingCharImageDirections.add(direction);
    });

    try {
      await _adminService.deleteCardCharacterImage(
        card.id,
        direction: direction.apiValue,
      );
      if (!mounted) {
        return;
      }
      await _loadCards(preferCardId: card.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _pendingCharImageBytes
          ..clear()
          ..addAll(pendingBytesByDirection);
        _pendingCharImageMimeTypes
          ..clear()
          ..addAll(pendingMimeTypesByDirection);
        _pendingCharImageFileNames
          ..clear()
          ..addAll(pendingFileNamesByDirection);
      });
      _showSnackBar(_t.text('Character image removed successfully'));
    } on ApiException catch (error) {
      _showSnackBar(error.message);
    } finally {
      if (mounted) {
        setState(() {
          _removingCharImageDirections.remove(direction);
        });
      }
    }
  }

  Future<void> _pickCharacterAssetImage() async {
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
      _pendingCharacterAssetBytes = bytes;
      _pendingCharacterAssetMimeType = mimeType;
      _pendingCharacterAssetFileName = file.name;
    });
  }

  Future<void> _uploadCharacterAsset() async {
    final card = _selectedCard();
    if (card == null || _isCreatingNew) {
      _showSnackBar(_t.text('Save the card first before uploading an image'));
      return;
    }

    final bytes = _pendingCharacterAssetBytes;
    final mimeType = _pendingCharacterAssetMimeType;
    final assetId = _assetIdController.text.trim();
    final frameIndex = int.tryParse(_assetFrameIndexController.text.trim());
    final durationMs = int.tryParse(_assetDurationMsController.text.trim());
    if (assetId.isEmpty) {
      _showSnackBar(_t.text('Asset ID is required'));
      return;
    }
    if (bytes == null || mimeType == null) {
      _showSnackBar(_t.text('Choose Image'));
      return;
    }
    if (frameIndex == null || frameIndex < 0) {
      _showSnackBar(_t.text('Frame index must be 0 or greater'));
      return;
    }
    if (durationMs == null || durationMs < 33) {
      _showSnackBar(_t.text('Frame duration must be at least 33 ms'));
      return;
    }

    setState(() {
      _isUploadingCharacterAsset = true;
    });

    try {
      final updated = await _adminService.uploadCardCharacterAsset(
        cardId: card.id,
        assetId: assetId,
        animation: _selectedCharacterAssetAnimation,
        direction: _selectedCharacterAssetDirection.apiValue,
        frameIndex: frameIndex,
        durationMs: durationMs,
        loop: _characterAssetLoop,
        bytesBase64: base64Encode(bytes),
        contentType: mimeType,
        fileName: _pendingCharacterAssetFileName,
      );
      if (!mounted) {
        return;
      }
      await _loadCards(preferCardId: updated.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _pendingCharacterAssetBytes = null;
        _pendingCharacterAssetMimeType = null;
        _pendingCharacterAssetFileName = null;
      });
      _showSnackBar(_t.text('Character asset uploaded successfully'));
    } on ApiException catch (error) {
      _showSnackBar(error.message);
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingCharacterAsset = false;
        });
      }
    }
  }

  Future<void> _removeCharacterAsset(String assetId) async {
    final card = _selectedCard();
    if (card == null || _isCreatingNew) {
      return;
    }

    setState(() {
      _removingCharacterAssetId = assetId;
    });

    try {
      await _adminService.deleteCardCharacterAsset(
        cardId: card.id,
        assetId: assetId,
      );
      if (!mounted) {
        return;
      }
      await _loadCards(preferCardId: card.id);
      if (!mounted) {
        return;
      }
      _showSnackBar(_t.text('Character asset removed successfully'));
    } on ApiException catch (error) {
      _showSnackBar(error.message);
    } finally {
      if (mounted) {
        setState(() {
          _removingCharacterAssetId = null;
        });
      }
    }
  }

  Future<void> _pickBgImage() async {
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
      _pendingBgImageBytes = bytes;
      _pendingBgImageMimeType = mimeType;
      _pendingBgImageFileName = file.name;
    });
  }

  Future<void> _uploadBgImage() async {
    final card = _selectedCard();
    if (card == null || _isCreatingNew) {
      _showSnackBar(_t.text('Save the card first before uploading an image'));
      return;
    }
    if (_pendingBgImageBytes == null || _pendingBgImageMimeType == null) {
      return;
    }

    setState(() {
      _isUploadingBgImage = true;
    });

    try {
      final updated = await _adminService.uploadCardBgImage(
        cardId: card.id,
        bytesBase64: base64Encode(_pendingBgImageBytes!),
        contentType: _pendingBgImageMimeType!,
        fileName: _pendingBgImageFileName,
      );
      if (!mounted) {
        return;
      }
      await _loadCards(preferCardId: updated.id);
      if (!mounted) {
        return;
      }
      _showSnackBar(_t.text('Background image uploaded successfully'));
    } on ApiException catch (error) {
      _showSnackBar(error.message);
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingBgImage = false;
        });
      }
    }
  }

  Future<void> _removeBgImage() async {
    final card = _selectedCard();
    if (card == null || _isCreatingNew) {
      return;
    }

    setState(() {
      _isRemovingBgImage = true;
    });

    try {
      await _adminService.deleteCardBgImage(card.id);
      if (!mounted) {
        return;
      }
      await _loadCards(preferCardId: card.id);
      if (!mounted) {
        return;
      }
      _showSnackBar(_t.text('Background image removed successfully'));
    } on ApiException catch (error) {
      _showSnackBar(error.message);
    } finally {
      if (mounted) {
        setState(() {
          _isRemovingBgImage = false;
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
      case 'money':
        return t.text('Money');
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
      final wasEquipment = _selectedType == 'equipment';
      _selectedType = value;
      if (_isCreatingNew) {
        if (value == 'spell') {
          _selectedEnergyCostType = 'spirit';
        } else if (value == 'equipment') {
          _selectedEnergyCostType = 'money';
        } else if (wasSpell && _selectedEnergyCostType == 'spirit') {
          _selectedEnergyCostType = 'physical';
        } else if (wasEquipment && _selectedEnergyCostType == 'money') {
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

  void _setShowFieldEvents(bool value) {
    setState(() {
      _showFieldEvents = value;
      _selectedFieldEventId = null;
    });
  }

  void _selectFieldEvent(String id) {
    setState(() {
      _selectedFieldEventId = id;
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

class _CharacterDirectionImageSection extends StatelessWidget {
  const _CharacterDirectionImageSection({
    required this.selectedCard,
    required this.pendingImageBytes,
    required this.onPickImage,
    required this.onUploadImage,
    required this.onRemoveImage,
    required this.isCreatingNew,
    required this.uploadingDirections,
    required this.removingDirections,
    required this.translation,
  });

  final RoyaleCard? selectedCard;
  final Map<_CharacterImageDirection, Uint8List> pendingImageBytes;
  final Future<void> Function(_CharacterImageDirection direction) onPickImage;
  final Future<void> Function(_CharacterImageDirection direction) onUploadImage;
  final Future<void> Function(_CharacterImageDirection direction) onRemoveImage;
  final bool isCreatingNew;
  final Set<_CharacterImageDirection> uploadingDirections;
  final Set<_CharacterImageDirection> removingDirections;
  final Map<String, String> translation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            translation.text('Character Direction Images'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            translation.text(
              'Upload front, back, left, and right character art separately.',
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final direction in _CharacterImageDirection.values)
                SizedBox(
                  width: 280,
                  child: _CardLayerImageEditor(
                    title:
                        '${translation.text(direction.labelKey)} ${translation.text('Character Image')}',
                    imageUrl: selectedCard?.characterImageUrlFor(
                      direction.apiValue,
                    ),
                    pendingImageBytes: pendingImageBytes[direction],
                    onPickImage: () => onPickImage(direction),
                    onUploadImage: () => onUploadImage(direction),
                    onRemoveImage: () => onRemoveImage(direction),
                    isCreatingNew: isCreatingNew,
                    isUploadingImage: uploadingDirections.contains(direction),
                    isRemovingImage: removingDirections.contains(direction),
                    hasPendingImage: pendingImageBytes.containsKey(direction),
                    translation: translation,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CharacterAnimationAssetEditor extends StatelessWidget {
  const _CharacterAnimationAssetEditor({
    required this.selectedCard,
    required this.assetIdController,
    required this.frameIndexController,
    required this.durationMsController,
    required this.animationOptions,
    required this.selectedAnimation,
    required this.onAnimationChanged,
    required this.selectedDirection,
    required this.onDirectionChanged,
    required this.loop,
    required this.onLoopChanged,
    required this.pendingImageBytes,
    required this.onPickImage,
    required this.onUploadAsset,
    required this.onRemoveAsset,
    required this.isCreatingNew,
    required this.isUploading,
    required this.removingAssetId,
    required this.translation,
  });

  final RoyaleCard? selectedCard;
  final TextEditingController assetIdController;
  final TextEditingController frameIndexController;
  final TextEditingController durationMsController;
  final List<String> animationOptions;
  final String selectedAnimation;
  final ValueChanged<String?> onAnimationChanged;
  final _CharacterImageDirection selectedDirection;
  final ValueChanged<_CharacterImageDirection?> onDirectionChanged;
  final bool loop;
  final ValueChanged<bool> onLoopChanged;
  final Uint8List? pendingImageBytes;
  final VoidCallback onPickImage;
  final VoidCallback onUploadAsset;
  final ValueChanged<String> onRemoveAsset;
  final bool isCreatingNew;
  final bool isUploading;
  final String? removingAssetId;
  final Map<String, String> translation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final assets =
        selectedCard?.characterAssets ?? const <RoyaleCharacterAsset>[];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            translation.text('Character Animation Assets'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            translation.text(
              'Each image has an asset ID and can be assigned to idle, move, or attack animations.',
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          if (assets.isEmpty)
            Text(
              translation.text('No animation assets uploaded'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final asset in assets)
                  _CharacterAssetChip(
                    asset: asset,
                    removing: removingAssetId == asset.assetId,
                    onRemove: () => onRemoveAsset(asset.assetId),
                    translation: translation,
                  ),
              ],
            ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 180,
                child: TextField(
                  controller: assetIdController,
                  decoration: InputDecoration(
                    labelText: translation.text('Asset ID'),
                    helperText: translation.text('Example: move_back_0'),
                  ),
                ),
              ),
              SizedBox(
                width: 150,
                child: DropdownButtonFormField<String>(
                  initialValue: selectedAnimation,
                  decoration: InputDecoration(
                    labelText: translation.text('Animation'),
                  ),
                  items: [
                    for (final option in animationOptions)
                      DropdownMenuItem(value: option, child: Text(option)),
                  ],
                  onChanged: onAnimationChanged,
                ),
              ),
              SizedBox(
                width: 150,
                child: DropdownButtonFormField<_CharacterImageDirection>(
                  initialValue: selectedDirection,
                  decoration: InputDecoration(
                    labelText: translation.text('Direction'),
                  ),
                  items: [
                    for (final direction in _CharacterImageDirection.values)
                      DropdownMenuItem(
                        value: direction,
                        child: Text(translation.text(direction.labelKey)),
                      ),
                  ],
                  onChanged: onDirectionChanged,
                ),
              ),
              SizedBox(
                width: 120,
                child: TextField(
                  controller: frameIndexController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: translation.text('Frame'),
                  ),
                ),
              ),
              SizedBox(
                width: 140,
                child: TextField(
                  controller: durationMsController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: translation.text('Duration ms'),
                  ),
                ),
              ),
              FilterChip(
                selected: loop,
                label: Text(translation.text('Loop')),
                onSelected: onLoopChanged,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (pendingImageBytes != null && pendingImageBytes!.isNotEmpty)
            Container(
              width: double.infinity,
              height: 140,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              clipBehavior: Clip.antiAlias,
              child: Image.memory(pendingImageBytes!, fit: BoxFit.contain),
            ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: isUploading ? null : onPickImage,
                icon: const Icon(Icons.image_search_outlined),
                label: Text(translation.text('Choose Image')),
              ),
              OutlinedButton.icon(
                onPressed: isCreatingNew || isUploading ? null : onUploadAsset,
                icon: isUploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload_outlined),
                label: Text(translation.text('Upload Asset')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CharacterAssetChip extends StatelessWidget {
  const _CharacterAssetChip({
    required this.asset,
    required this.removing,
    required this.onRemove,
    required this.translation,
  });

  final RoyaleCharacterAsset asset;
  final bool removing;
  final VoidCallback onRemove;
  final Map<String, String> translation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 260,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 54,
              height: 54,
              child: asset.imageUrl == null || asset.imageUrl!.isEmpty
                  ? const Icon(Icons.image_outlined)
                  : Image.network(
                      asset.imageUrl!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.broken_image_outlined),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  asset.assetId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${asset.animation} / ${asset.direction} / #${asset.frameIndex} / ${asset.durationMs}ms',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: translation.text('Remove'),
            onPressed: removing ? null : onRemove,
            icon: removing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }
}

class _CardLayerImageEditor extends StatelessWidget {
  const _CardLayerImageEditor({
    required this.title,
    required this.imageUrl,
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

  final String title;
  final String? imageUrl;
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
    final hasSavedImage = imageUrl != null && imageUrl!.isNotEmpty;

    Widget preview;
    if (pendingImageBytes != null && pendingImageBytes!.isNotEmpty) {
      preview = Image.memory(pendingImageBytes!, fit: BoxFit.contain);
    } else if (hasSavedImage) {
      preview = Image.network(
        imageUrl!,
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
            translation.text('No image uploaded'),
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
            title,
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
            height: 200,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
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
                label: Text(translation.text('Upload')),
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
                label: Text(translation.text('Remove')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
