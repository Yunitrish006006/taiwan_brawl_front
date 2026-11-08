import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'street_scrap_inventory.dart';
import 'street_scrap_crafting.dart';
import 'street_scrap_expedition.dart';
import 'street_scrap_expedition_panel.dart';
import 'street_scrap_fishing.dart';
import 'street_scrap_fishing_panel.dart';
import 'street_scrap_woodworking_panel.dart';
import 'street_scrap_woodworking.dart';
import 'street_scrap_water.dart';
import 'street_scrap_operation_checkpoint_dialog.dart';
import 'street_scrap_progress.dart';
import 'street_scrap_relief_panel.dart';
import 'street_scrap_relief.dart';
import 'street_scrap_orders.dart';
import 'street_scrap_orders_panel.dart';
import 'street_scrap_trait_presentation.dart';
import 'street_scrap_maintenance.dart';
import 'street_scrap_item_sprite.dart';
import 'street_scrap_protagonist_sprite.dart';
import 'street_scrap_module.dart';
import 'street_scrap_game_settings.dart';
import 'street_scrap_localizations.dart';
import 'street_scrap_audio.dart';
import 'street_scrap_renewable_supplies.dart';
import 'street_scrap_renewable_supplies_panel.dart';

@visibleForTesting
bool streetScrapSaveTransferUsesReadStream({
  required bool isWeb,
  required TargetPlatform platform,
}) =>
    isWeb ||
    platform == TargetPlatform.android ||
    platform == TargetPlatform.iOS;

class StreetScrapInventoryPage extends StatefulWidget {
  const StreetScrapInventoryPage({
    super.key,
    required this.session,
    required this.catalog,
    required this.recipeCatalog,
    required this.expeditionRules,
    this.repairCatalog,
    this.fishingRules = const StreetScrapFishingRules(
      version: 1,
      castCost: 3,
      signalsPerCast: 3,
      successSignals: 2,
      perfectSignals: 3,
      signalHoldMilliseconds: 2000,
      basePromptWidthPercent: 30,
      preciseQualityBonus: 8,
      guaranteeAfterFailures: 2,
      freeNaturalBait: true,
      loanerRodAvailable: true,
      spots: [
        StreetScrapFishingSpot(id: 'dock_entrance', phase: 2, name: '舊碼頭入口'),
      ],
      failureRewards: ['wood.driftwood', 'cloth.thread_end'],
    ),
    required this.maxStamina,
    this.orderCatalog,
    this.renewableSupplies,
    this.chapter5Installed = false,
    this.woodBoardSpriteBytes,
    this.threadSpoolSpriteBytes,
    this.materialAtlasBytes,
    this.toolAtlasBytes,
    this.materialPackArtBytes,
    this.mineralPackArtBytes,
    this.woodChipBundleArtBytes,
    this.fishingSceneArtBytes,
    this.protagonistArt,
    this.onOpenLibrary,
    this.initiallyShowMaterialGallery = false,
  });

  final StreetScrapSession session;
  final StreetScrapInventoryCatalog catalog;
  final StreetScrapRecipeCatalog recipeCatalog;
  final StreetScrapExpeditionRules expeditionRules;
  final StreetScrapToolRepairCatalog? repairCatalog;
  final StreetScrapFishingRules fishingRules;
  final int maxStamina;
  final StreetScrapOrderCatalog? orderCatalog;
  final StreetScrapRenewableSupplyCatalog? renewableSupplies;
  final bool chapter5Installed;
  final Uint8List? woodBoardSpriteBytes;
  final Uint8List? threadSpoolSpriteBytes;
  final Uint8List? materialAtlasBytes;
  final Uint8List? toolAtlasBytes;
  final Uint8List? materialPackArtBytes;
  final Uint8List? mineralPackArtBytes;
  final Uint8List? woodChipBundleArtBytes;
  final Uint8List? fishingSceneArtBytes;
  final StreetScrapProtagonistArt? protagonistArt;
  final VoidCallback? onOpenLibrary;
  final bool initiallyShowMaterialGallery;

  @override
  State<StreetScrapInventoryPage> createState() =>
      _StreetScrapInventoryPageState();
}

class _StreetScrapInventoryPageState extends State<StreetScrapInventoryPage> {
  Map<String, StreetScrapGridSpec> get _grids =>
      streetScrapGridSpecsForState(widget.session.snapshot.state);

  String _activeGrid = 'board';
  int _activeSection = 0;
  String? _selectedInstanceId;
  int _workspaceDetachedPage = 0;
  int _materialTrayPage = 0;
  String _materialCategory = 'all';
  // Game entry can open directly to the large, paged material gallery while
  // isolated widget consumers keep the board-first default.
  bool _materialsExpanded = false;
  String? _actionError;
  bool _saving = false;
  Timer? _streetExploreTransition;
  int _protagonistPose = 0;
  int _keyboardX = 0;
  int _keyboardY = 0;
  _StreetScrapMoveUndo? _lastMoveUndo;
  final ScrollController _inventoryScrollController = ScrollController();
  final GlobalKey _inventoryScrollViewportKey = GlobalKey();
  final FocusNode _keyboardGridFocus = FocusNode(
    debugLabel: 'Street Scrap inventory grid keyboard controls',
  );
  Future<StreetScrapAudio?>? _audioReady;
  bool _reliefInitializationScheduled = false;

  static const _materialCategories = <String>[
    'all',
    'wood',
    'cloth',
    'metal',
    'water',
    'food',
    'tools',
    'other',
  ];

  static const _materialCategoryIcons = <String, IconData>{
    'all': Icons.apps_rounded,
    'wood': Icons.forest_rounded,
    'cloth': Icons.texture_rounded,
    'metal': Icons.hardware_rounded,
    'water': Icons.water_drop_rounded,
    'food': Icons.restaurant_rounded,
    'tools': Icons.handyman_rounded,
    'other': Icons.category_rounded,
  };

  static const _materialCategoryAccents = <String, Color>{
    'all': Color(0xFFE5C17C),
    'wood': Color(0xFF9BC184),
    'cloth': Color(0xFFD0A9CE),
    'metal': Color(0xFFB7C4C2),
    'water': Color(0xFF82C7D6),
    'food': Color(0xFFE6A96E),
    'tools': Color(0xFFD8B982),
    'other': Color(0xFFBBC6B5),
  };

  String _materialCategoryFor(StreetScrapObject item) {
    final id = item.itemId.toLowerCase();
    final content = item.containerState['contentItemId'];
    if (id.startsWith('wood.') || id.contains('wood')) return 'wood';
    if (id.startsWith('cloth.') ||
        id.startsWith('thread.') ||
        id.startsWith('rope.') ||
        id.startsWith('line.') ||
        id.contains('cloth')) {
      return 'cloth';
    }
    if (id.startsWith('metal.') || id.contains('metal')) return 'metal';
    if (id.startsWith('water.') ||
        (content is String && content.startsWith('water.'))) {
      return 'water';
    }
    if (id.startsWith('food.') ||
        id.startsWith('fish.') ||
        id.startsWith('herb.') ||
        id.startsWith('seasoning.') ||
        id.startsWith('meal.') ||
        id.contains('soup')) {
      return 'food';
    }
    if (id.startsWith('tool.') ||
        id.startsWith('toolpart.') ||
        id.startsWith('bait.') ||
        id.contains('tool') ||
        id.contains('rod')) {
      return 'tools';
    }
    return 'other';
  }

  String _materialVisualStackKey(StreetScrapObject item) {
    final traits = item.traits.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));
    final containerState = item.containerState.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));
    return <Object?>[
      item.itemId,
      item.source,
      item.quality,
      traits.map((entry) => '${entry.key}:${entry.value}').join(','),
      containerState.map((entry) => '${entry.key}:${entry.value}').join(','),
      '${item.footprint.width}x${item.footprint.height}',
    ].join('\u0000');
  }

  @override
  void initState() {
    super.initState();
    _materialsExpanded = widget.initiallyShowMaterialGallery;
  }

  @override
  void dispose() {
    _streetExploreTransition?.cancel();
    _keyboardGridFocus.dispose();
    _inventoryScrollController.dispose();
    final audioReady = _audioReady;
    if (audioReady != null) {
      unawaited(audioReady.then((audio) => audio?.dispose()));
    }
    super.dispose();
  }

  void _enterExpeditionFromStreetScene() {
    _streetExploreTransition?.cancel();
    if (MediaQuery.disableAnimationsOf(context)) {
      setState(() {
        _protagonistPose = 0;
        _activeSection = 1;
        _selectedInstanceId = null;
      });
      return;
    }
    setState(() => _protagonistPose = 1);
    _streetExploreTransition = Timer(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      setState(() {
        _protagonistPose = 0;
        _activeSection = 1;
        _selectedInstanceId = null;
      });
    });
  }

  Future<void> _playSound(StreetScrapAudioCue cue) async {
    final volume = _gameSettings.soundVolume;
    if (volume <= 0) return;
    try {
      final audio = await (_audioReady ??= StreetScrapAudio.create());
      await audio?.play(cue, volume);
    } on Object {
      // Device audio is optional; it must never block or fail a saved action.
    }
  }

  Set<String> _recipeOutputItemIds(StreetScrapRecipe recipe) {
    final outputIds = <String>{
      for (final output in recipe.outputs) output.itemId,
    };
    final effect = recipe.stateEffect;
    if (effect == null) return outputIds;
    for (final key in const ['toItemId', 'toContentItemId']) {
      final itemId = effect[key];
      if (itemId is String) outputIds.add(itemId);
    }
    final containers = effect['containers'];
    if (containers is List) {
      for (final container in containers.whereType<Map>()) {
        final itemId = container['successContentItemId'];
        if (itemId is String) outputIds.add(itemId);
      }
    }
    return outputIds;
  }

  String _recipeDisplayName(
    StreetScrapLocalizations strings,
    StreetScrapRecipe recipe,
  ) {
    final inputItemId =
        recipe.inputGroups.isEmpty || recipe.inputGroups.first.isEmpty
        ? null
        : recipe.inputGroups.first.first.itemId;
    if (inputItemId == null) {
      return strings.text(
        'recipes.title.actionOnly',
        arguments: {
          'action': strings.text('recipes.action.${recipe.operationId}'),
        },
      );
    }
    final outputIds = _recipeOutputItemIds(recipe);
    final displayName = strings.recipeDisplayName(
      operationId: recipe.operationId,
      inputItemId: inputItemId,
      outputItemId: outputIds.isEmpty ? null : outputIds.first,
    );
    final contentItemId = _recipeContainerContentItemId(recipe, inputItemId);
    return contentItemId == null
        ? displayName
        : strings.text(
            'recipe.containerContentContext',
            arguments: {
              'recipe': displayName,
              'content': strings.itemName(contentItemId),
            },
          );
  }

  String? _recipeContainerContentItemId(
    StreetScrapRecipe recipe,
    String containerItemId, {
    String outcome = 'requiredContentItemId',
  }) {
    final effect = recipe.stateEffect;
    if (effect == null) return null;
    if (effect['type'] == 'transformContainerContent' &&
        effect['containerItemId'] == containerItemId) {
      return switch (outcome) {
        'requiredContentItemId' => effect['fromContentItemId'] as String?,
        'successContentItemId' ||
        'failureContentItemId' => effect['toContentItemId'] as String?,
        _ => null,
      };
    }
    final transforms = effect['containers'];
    if (transforms is! List) return null;
    for (final transform in transforms.whereType<Map>()) {
      if (transform['containerItemId'] != containerItemId) continue;
      final contentItemId = transform[outcome];
      if (contentItemId is String) return contentItemId;
    }
    return null;
  }

  void _focusKeyboardGrid() => _keyboardGridFocus.requestFocus();

  void _autoScrollDuringListDrag(DragUpdateDetails details) {
    if (!_inventoryScrollController.hasClients) return;
    final renderObject = _inventoryScrollViewportKey.currentContext
        ?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;
    final viewportTop = renderObject.localToGlobal(Offset.zero).dy;
    final viewportBottom = viewportTop + renderObject.size.height;
    final pointerY = details.globalPosition.dy;
    const edgeZone = 64.0;
    const scrollStep = 24.0;
    final position = _inventoryScrollController.position;
    final offset = position.pixels;
    if (pointerY < viewportTop + edgeZone &&
        offset > position.minScrollExtent) {
      _inventoryScrollController.jumpTo(
        (offset - scrollStep).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        ),
      );
    } else if (pointerY > viewportBottom - edgeZone &&
        offset < position.maxScrollExtent) {
      _inventoryScrollController.jumpTo(
        (offset + scrollStep).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        ),
      );
    }
  }

  KeyEventResult _handleGridKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final grid = _grids[_activeGrid];
    if (grid == null) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown) {
      setState(() {
        if (key == LogicalKeyboardKey.arrowLeft) _keyboardX--;
        if (key == LogicalKeyboardKey.arrowRight) _keyboardX++;
        if (key == LogicalKeyboardKey.arrowUp) _keyboardY--;
        if (key == LogicalKeyboardKey.arrowDown) _keyboardY++;
        _keyboardX = _keyboardX.clamp(0, grid.width - 1);
        _keyboardY = _keyboardY.clamp(0, grid.height - 1);
      });
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyR) {
      final selectedId = _selectedInstanceId;
      if (selectedId != null &&
          _inventory.placements.containsKey(selectedId) &&
          !_saving &&
          !widget.session.isReadOnly) {
        unawaited(_rotateSelected());
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      final selectedId = _selectedInstanceId;
      if (selectedId != null) _select(selectedId);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space) {
      if (_saving || widget.session.isReadOnly) return KeyEventResult.handled;
      final inventory = _inventory;
      StreetScrapPlacement? occupant;
      for (final placement in inventory.placements.values) {
        if (placement.gridId != _activeGrid) continue;
        final item = inventory.objects[placement.instanceId];
        if (item == null) continue;
        final footprint = item.footprint.rotated(placement.rotation);
        if (_keyboardX >= placement.x &&
            _keyboardX < placement.x + footprint.width &&
            _keyboardY >= placement.y &&
            _keyboardY < placement.y + footprint.height) {
          occupant = placement;
          break;
        }
      }
      final selectedId = _selectedInstanceId;
      if (selectedId == null) {
        if (occupant != null) _select(occupant.instanceId);
      } else if (occupant?.instanceId == selectedId) {
        _select(selectedId);
      } else {
        unawaited(_placeAt(_keyboardX, _keyboardY));
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _initializeReliefClock() async {
    final session = widget.session;
    if (session.isReadOnly || session.snapshot.state['relief'] != null) return;
    final createdAt = session.snapshot.savedAt;
    try {
      await session.apply(
        commandId: 'relief-initialize-${createdAt.microsecondsSinceEpoch}',
        expectedRevision: session.snapshot.revision,
        reduce: (state) => state['relief'] != null
            ? StreetScrapReduction(state: state)
            : StreetScrapReduction(
                state: {
                  ...state,
                  'relief': StreetScrapReliefProgress.start(createdAt).toJson(),
                },
              ),
      );
      if (mounted) setState(() {});
    } on Object {
      // A concurrent command may win the revision; the panel remains
      // read-only until a fresh session reload rather than rebasing silently.
      if (mounted) {
        setState(
          () => _actionError = StreetScrapLocalizations.of(
            context,
          ).text('relief.clockSaveError'),
        );
      }
    }
  }

  int? get _chapter {
    final raw = widget.session.snapshot.state['chapter'];
    if (raw == null) return 0;
    return raw is int && raw >= 0 && raw <= 5 ? raw : null;
  }

  StreetScrapGameSettings get _gameSettings {
    try {
      return StreetScrapGameSettings.fromJson(
        widget.session.snapshot.state['gameSettings'],
      );
    } on FormatException {
      // Optional presentation preferences must not make a valid game save
      // unplayable; the next explicit save can replace malformed preferences.
      return const StreetScrapGameSettings();
    }
  }

  Future<void> _showGameSettings() async {
    final strings = StreetScrapLocalizations.of(context);
    final initial = _gameSettings;
    var textScale = initial.textScale;
    var reduceMotion = initial.reduceMotion;
    var assistedControls = initial.assistedControls;
    var soundVolume = initial.soundVolume;
    String? busyLabelKey;
    String? error;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.82,
          builder: (context, controller) => StatefulBuilder(
            builder: (context, setSheetState) => ListView(
              controller: controller,
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        strings.text('settings.title'),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      tooltip: strings.text('settings.close'),
                      onPressed: busyLabelKey != null
                          ? null
                          : () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Text(
                  strings.text(
                    'settings.extraTextScale',
                    arguments: {'percent': '${(textScale * 100).round()}'},
                  ),
                ),
                Slider(
                  key: const Key('street-scrap-text-scale'),
                  value: textScale,
                  min: 1,
                  max: 2,
                  divisions: 4,
                  label: '${(textScale * 100).round()}%',
                  onChanged: (value) => setSheetState(() => textScale = value),
                ),
                SwitchListTile(
                  key: const Key('street-scrap-reduce-motion'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(strings.text('settings.reduceMotion')),
                  subtitle: Text(
                    strings.text('settings.reduceMotionDescription'),
                  ),
                  value: reduceMotion,
                  onChanged: (value) =>
                      setSheetState(() => reduceMotion = value),
                ),
                SwitchListTile(
                  key: const Key('street-scrap-assisted-controls'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(strings.text('settings.assistedControls')),
                  subtitle: Text(
                    strings.text('settings.assistedControlsDescription'),
                  ),
                  value: assistedControls,
                  onChanged: (value) =>
                      setSheetState(() => assistedControls = value),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    soundVolume == 0
                        ? Icons.volume_off_outlined
                        : Icons.volume_up_outlined,
                  ),
                  title: Text(strings.text('settings.soundVolume')),
                  subtitle: Text(
                    strings.text(
                      soundVolume == 0
                          ? 'settings.soundMuted'
                          : 'settings.soundEnabled',
                      arguments: {'percent': '$soundVolume'},
                    ),
                  ),
                ),
                Slider(
                  key: const Key('street-scrap-sound-volume'),
                  value: soundVolume.toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 10,
                  label: '$soundVolume%',
                  onChanged: (value) =>
                      setSheetState(() => soundVolume = value.round()),
                ),
                const Divider(height: 28),
                Text(
                  strings.text('transfer.title'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(strings.text('transfer.description')),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      key: const Key('street-scrap-export-save'),
                      onPressed: busyLabelKey != null
                          ? null
                          : () async {
                              setSheetState(
                                () => busyLabelKey = 'transfer.exporting',
                              );
                              await _exportSaveTransfer();
                              if (sheetContext.mounted) {
                                setSheetState(() => busyLabelKey = null);
                              }
                            },
                      icon: const Icon(Icons.file_upload_outlined),
                      label: Text(
                        strings.text(
                          busyLabelKey == 'transfer.exporting'
                              ? busyLabelKey!
                              : 'transfer.export',
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const Key('street-scrap-import-save'),
                      onPressed:
                          busyLabelKey != null || widget.session.isReadOnly
                          ? null
                          : () async {
                              setSheetState(
                                () => busyLabelKey = 'transfer.choosing',
                              );
                              final imported = await _importSaveTransfer(
                                onStatus: (key) =>
                                    setSheetState(() => busyLabelKey = key),
                              );
                              if (!sheetContext.mounted) return;
                              if (imported) {
                                Navigator.of(sheetContext).pop();
                              } else {
                                setSheetState(() => busyLabelKey = null);
                              }
                            },
                      icon: const Icon(Icons.file_download_outlined),
                      label: Text(
                        strings.text(
                          busyLabelKey == 'transfer.choosing' ||
                                  busyLabelKey == 'transfer.importing'
                              ? busyLabelKey!
                              : 'transfer.import',
                        ),
                      ),
                    ),
                  ],
                ),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const Key('street-scrap-save-settings'),
                  onPressed: busyLabelKey != null || widget.session.isReadOnly
                      ? null
                      : () async {
                          setSheetState(() {
                            busyLabelKey = 'settings.saving';
                            error = null;
                          });
                          try {
                            final settings = StreetScrapGameSettings(
                              textScale: textScale,
                              reduceMotion: reduceMotion,
                              assistedControls: assistedControls,
                              soundVolume: soundVolume,
                            );
                            await widget.session.apply(
                              commandId:
                                  'game-settings-${DateTime.now().microsecondsSinceEpoch}',
                              expectedRevision:
                                  widget.session.snapshot.revision,
                              reduce: (state) => StreetScrapReduction(
                                state: {
                                  ...state,
                                  'gameSettings': settings.toJson(),
                                },
                              ),
                            );
                            if (!mounted || !sheetContext.mounted) return;
                            Navigator.of(sheetContext).pop();
                            setState(() {});
                          } on Object catch (_) {
                            if (sheetContext.mounted) {
                              setSheetState(() {
                                busyLabelKey = null;
                                error = strings.text('settings.saveFailed');
                              });
                            }
                          }
                        },
                  icon: const Icon(Icons.save_outlined),
                  label: Text(strings.text(busyLabelKey ?? 'settings.save')),
                ),
                if (widget.session.isReadOnly)
                  Text(strings.text('settings.readOnly')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _exportSaveTransfer() async {
    final strings = StreetScrapLocalizations.of(context);
    try {
      final transfer = StreetScrapSaveTransfer.fromSnapshot(
        widget.session.snapshot,
      );
      final result = await FilePicker.platform.saveFile(
        dialogTitle: strings.text('transfer.exportTitle'),
        fileName: 'street-scrap-save.json',
        type: FileType.custom,
        allowedExtensions: const ['json'],
        bytes: Uint8List.fromList(transfer.encodeBytes()),
      );
      if (!mounted || (!kIsWeb && result == null)) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.text('transfer.exported'))),
      );
    } on Object catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.text('transfer.exportFailed'))),
      );
    }
  }

  Future<bool> _importSaveTransfer({
    required ValueChanged<String> onStatus,
  }) async {
    final strings = StreetScrapLocalizations.of(context);
    try {
      final selection = await FilePicker.platform.pickFiles(
        dialogTitle: strings.text('transfer.importTitle'),
        type: FileType.custom,
        allowedExtensions: const ['json'],
        allowMultiple: false,
        withData: !streetScrapSaveTransferUsesReadStream(
          isWeb: kIsWeb,
          platform: defaultTargetPlatform,
        ),
        withReadStream: streetScrapSaveTransferUsesReadStream(
          isWeb: kIsWeb,
          platform: defaultTargetPlatform,
        ),
      );
      if (!mounted || selection == null || selection.files.isEmpty) {
        return false;
      }
      onStatus('transfer.importing');
      final file = selection.files.single;
      if (file.size > streetScrapTransferMaximumBytes) {
        throw const FormatException('Save file is unavailable or too large.');
      }
      List<int>? bytes = file.bytes;
      if (bytes == null && file.readStream != null) {
        final streamedBytes = <int>[];
        await for (final chunk in file.readStream!) {
          if (streamedBytes.length + chunk.length >
              streetScrapTransferMaximumBytes) {
            throw const FormatException('Save file is too large.');
          }
          streamedBytes.addAll(chunk);
        }
        bytes = streamedBytes;
      }
      if (bytes == null || bytes.length > streetScrapTransferMaximumBytes) {
        throw const FormatException('Save file is unavailable or too large.');
      }
      final transfer = StreetScrapSaveTransfer.decodeBytes(bytes);
      final imported = transfer.snapshot;
      final chapter = imported.state['chapter'] as int? ?? 0;
      final savedAt = MaterialLocalizations.of(
        context,
      ).formatMediumDate(imported.savedAt.toLocal());
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(strings.text('transfer.reviewTitle')),
          content: Text(
            strings.text(
              'transfer.reviewBody',
              arguments: {
                'chapter': '$chapter',
                'revision': '${imported.revision}',
                'savedAt': savedAt,
                'ruleset': '${imported.rulesetVersion}',
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(strings.text('transfer.cancel')),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.restore),
              label: Text(strings.text('transfer.confirmImport')),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return false;
      await widget.session.importTransfer(
        transfer: transfer,
        validateState: (state) {
          validateStreetScrapOrderCompletionState(state);
          final rawInventory = state['inventory'];
          if (rawInventory == null) return;
          if (rawInventory is! Map) {
            throw const FormatException('Malformed inventory in save.');
          }
          widget.catalog.inventoryFromJson(
            grids: streetScrapGridSpecsForState(state),
            json: Map<String, Object?>.from(rawInventory),
          );
        },
      );
      if (!mounted) return false;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.text('transfer.imported'))),
      );
      return true;
    } on Object catch (_) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.text('transfer.importFailed'))),
      );
      return false;
    }
  }

  Future<void> _showMaterialWorkspace() async {
    final strings = StreetScrapLocalizations.of(context);
    // Open the material view as a clean visual overview. The previous board
    // selection remains on the board itself and should not shrink the catalog.
    if (_selectedInstanceId != null) {
      setState(() => _selectedInstanceId = null);
    }
    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => Dialog.fullscreen(
        child: SafeArea(
          child: StatefulBuilder(
            builder: (context, updateWorkspace) {
              final inventory = _inventory;
              final gridSpec = _grids[_activeGrid]!;
              final placements = inventory.placements.values
                  .where((placement) => placement.gridId == gridSpec.id)
                  .toList(growable: false);
              final storedIds = inventory.storage.values
                  .expand((ids) => ids)
                  .toSet();
              final detachedIds = inventory.objects.keys
                  .where(
                    (id) =>
                        !inventory.placements.containsKey(id) &&
                        !storedIds.contains(id),
                  )
                  .toList(growable: false);
              // Keep every item outside home storage available in the visual
              // shelf. It remains useful as a material browser even when the
              // player has a mix of loose and board-placed objects.
              final shelfIds = [
                ...detachedIds,
                ...inventory.objects.keys.where(
                  (id) =>
                      !storedIds.contains(id) &&
                      inventory.placements.containsKey(id),
                ),
              ];
              final selected = _selectedInstanceId == null
                  ? null
                  : inventory.objects[_selectedInstanceId];
              final workspaceInvalidReservation = _lockedCraftIds.contains(
                '__invalid_craft_reservation__',
              );
              Future<void> refresh(Future<void> action) async {
                updateWorkspace(() {});
                await action;
                if (dialogContext.mounted) updateWorkspace(() {});
              }

              Widget selectionPanel({required bool compact}) {
                Widget metric({
                  required String key,
                  required IconData icon,
                  required String label,
                  required int value,
                }) => Expanded(
                  child: Semantics(
                    label: '$label：$value',
                    child: Tooltip(
                      message: label,
                      child: Container(
                        key: ValueKey(key),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 24),
                            const SizedBox(height: 6),
                            Text(
                              '$value',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );

                if (selected == null) {
                  return Semantics(
                    label: strings.text('board.instructionUnselected'),
                    child: compact
                        ? Icon(
                            Icons.touch_app_outlined,
                            size: 36,
                            color: Theme.of(context).colorScheme.outline,
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.secondaryContainer,
                                  shape: BoxShape.circle,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(22),
                                  child: Icon(
                                    _activeGrid == 'backpack'
                                        ? Icons.backpack_outlined
                                        : Icons.grid_view_rounded,
                                    size: 52,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSecondaryContainer,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '${inventory.objects.length}',
                                key: const Key(
                                  'street-scrap-workspace-overview-total',
                                ),
                                style: Theme.of(context).textTheme.displaySmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  metric(
                                    key:
                                        'street-scrap-workspace-overview-placed',
                                    icon: Icons.grid_on_rounded,
                                    label: strings.text(
                                      _activeGrid == 'backpack'
                                          ? 'board.backpackGridShort'
                                          : 'board.workingGridShort',
                                    ),
                                    value: placements.length,
                                  ),
                                  metric(
                                    key:
                                        'street-scrap-workspace-overview-loose',
                                    icon: Icons.move_to_inbox_outlined,
                                    label: strings.text('board.pendingItems'),
                                    value: detachedIds.length,
                                  ),
                                ],
                              ),
                            ],
                          ),
                  );
                }
                final artSize = compact ? 56.0 : 184.0;
                return Row(
                  mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
                  children: [
                    StreetScrapItemSprite(
                      itemId: selected.itemId,
                      source: selected.source,
                      contentItemId:
                          selected.containerState['contentItemId'] as String?,
                      woodBoardSpriteBytes: widget.woodBoardSpriteBytes,
                      threadSpoolSpriteBytes: widget.threadSpoolSpriteBytes,
                      materialAtlasBytes: widget.materialAtlasBytes,
                      toolAtlasBytes: widget.toolAtlasBytes,
                      materialPackArtBytes: widget.materialPackArtBytes,
                      mineralPackSpriteBytes: widget.mineralPackArtBytes,
                      woodChipBundleSpriteBytes: widget.woodChipBundleArtBytes,
                      size: artSize,
                    ),
                    const SizedBox(width: 8),
                    if (compact)
                      Expanded(
                        child: _workspaceSelectionLabel(selected, strings),
                      )
                    else
                      Flexible(
                        child: _workspaceSelectionLabel(selected, strings),
                      ),
                    IconButton.filledTonal(
                      tooltip: strings.text('board.rotate'),
                      onPressed: _saving || widget.session.isReadOnly
                          ? null
                          : () => refresh(_rotateSelected()),
                      icon: const Icon(Icons.rotate_right),
                    ),
                    IconButton(
                      tooltip: strings.text('board.clearSelection'),
                      onPressed: () {
                        _select(selected.instanceId);
                        updateWorkspace(() {});
                      },
                      icon: const Icon(Icons.close),
                    ),
                  ],
                );
              }

              Widget materialShelf({
                required double availableWidth,
                required double availableHeight,
              }) {
                if (shelfIds.isEmpty) {
                  return Center(
                    child: Icon(
                      Icons.inventory_2_outlined,
                      size: 56,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  );
                }
                const gap = 8.0;
                const pagerHeight = 42.0;
                final galleryHeight =
                    availableHeight - (selected == null ? 0 : 64);
                final columns = (availableWidth / 184).floor().clamp(2, 4);
                final rows = ((galleryHeight - pagerHeight) / 200)
                    .floor()
                    .clamp(1, 2);
                final tileSize =
                    ((availableWidth - gap * (columns - 1)) / columns)
                        .clamp(
                          120.0,
                          (galleryHeight - pagerHeight - gap * (rows - 1)) /
                              rows,
                        )
                        .clamp(120.0, 280.0)
                        .toDouble();
                final pageSize = columns * rows;
                final pageCount = (shelfIds.length / pageSize).ceil();
                final page = _workspaceDetachedPage.clamp(0, pageCount - 1);
                final visibleIds = shelfIds
                    .skip(page * pageSize)
                    .take(pageSize)
                    .toList(growable: false);
                return Column(
                  children: [
                    if (selected != null)
                      SizedBox(
                        height: 64,
                        child: selectionPanel(compact: true),
                      ),
                    Expanded(
                      child: Center(
                        child: SizedBox(
                          width: columns * tileSize + gap * (columns - 1),
                          child: GridView.builder(
                            key: const Key(
                              'street-scrap-workspace-material-grid',
                            ),
                            physics: const NeverScrollableScrollPhysics(),
                            padding: EdgeInsets.zero,
                            itemCount: visibleIds.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  crossAxisSpacing: gap,
                                  mainAxisSpacing: gap,
                                  mainAxisExtent: tileSize,
                                ),
                            itemBuilder: (context, index) {
                              final id = visibleIds[index];
                              final item = inventory.objects[id]!;
                              return Semantics(
                                button: true,
                                selected: id == _selectedInstanceId,
                                label: strings.text(
                                  'board.itemSemantics',
                                  arguments: {
                                    'name': strings.itemName(item.itemId),
                                    'source': strings.itemSource(item.source),
                                    'quality': strings.itemQuality(
                                      item.quality,
                                    ),
                                    'width': '${item.footprint.width}',
                                    'height': '${item.footprint.height}',
                                    'extra': '',
                                  },
                                ),
                                child: Tooltip(
                                  message: strings.itemName(item.itemId),
                                  child: Material(
                                    key: ValueKey(
                                      'street-scrap-workspace-item-$id',
                                    ),
                                    color: id == _selectedInstanceId
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.primaryContainer
                                        : Theme.of(
                                            context,
                                          ).colorScheme.surfaceContainerHighest,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      side: BorderSide(
                                        color: id == _selectedInstanceId
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.primary
                                            : Theme.of(
                                                context,
                                              ).colorScheme.outlineVariant,
                                        width: id == _selectedInstanceId
                                            ? 2
                                            : 1,
                                      ),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: InkWell(
                                      onTap: () {
                                        _select(id);
                                        updateWorkspace(() {});
                                      },
                                      child: Stack(
                                        children: [
                                          Center(
                                            child: StreetScrapItemSprite(
                                              itemId: item.itemId,
                                              source: item.source,
                                              contentItemId:
                                                  item.containerState['contentItemId']
                                                      as String?,
                                              woodBoardSpriteBytes:
                                                  widget.woodBoardSpriteBytes,
                                              threadSpoolSpriteBytes:
                                                  widget.threadSpoolSpriteBytes,
                                              materialAtlasBytes:
                                                  widget.materialAtlasBytes,
                                              toolAtlasBytes:
                                                  widget.toolAtlasBytes,
                                              materialPackArtBytes:
                                                  widget.materialPackArtBytes,
                                              mineralPackSpriteBytes:
                                                  widget.mineralPackArtBytes,
                                              woodChipBundleSpriteBytes:
                                                  widget.woodChipBundleArtBytes,
                                              size: tileSize - 8,
                                              visualScale: 1.25,
                                            ),
                                          ),
                                          Positioned(
                                            left: 7,
                                            top: 7,
                                            child: _workspaceItemBadge(
                                              context,
                                              message: strings.itemSource(
                                                item.source,
                                              ),
                                              icon:
                                                  _streetScrapIsProcessed(
                                                    item,
                                                    strings,
                                                  )
                                                  ? Icons.construction_rounded
                                                  : Icons.search_rounded,
                                            ),
                                          ),
                                          Positioned(
                                            right: 7,
                                            bottom: 7,
                                            child: _workspaceItemQualityBadge(
                                              context,
                                              quality: item.quality,
                                              message: strings.itemQuality(
                                                item.quality,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    if (pageCount > 1)
                      SizedBox(
                        height: pagerHeight,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              key: const Key(
                                'street-scrap-workspace-page-previous',
                              ),
                              tooltip: strings.text('board.previousPage'),
                              onPressed: page == 0
                                  ? null
                                  : () => updateWorkspace(
                                      () => _workspaceDetachedPage = page - 1,
                                    ),
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.chevron_left_rounded),
                            ),
                            Text(
                              '${page + 1} / $pageCount',
                              semanticsLabel: strings.text(
                                'board.pageCount',
                                arguments: {
                                  'current': '${page + 1}',
                                  'total': '$pageCount',
                                },
                              ),
                            ),
                            IconButton(
                              key: const Key(
                                'street-scrap-workspace-page-next',
                              ),
                              tooltip: strings.text('board.nextPage'),
                              onPressed: page >= pageCount - 1
                                  ? null
                                  : () => updateWorkspace(
                                      () => _workspaceDetachedPage = page + 1,
                                    ),
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.chevron_right_rounded),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              }

              return Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        key: const Key('street-scrap-close-material-workspace'),
                        tooltip: strings.text('common.close'),
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(Icons.close),
                      ),
                      Expanded(
                        child: Text(
                          strings.text('board.materialWorkspaceShort'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: strings.text(
                          'board.viewRecipes',
                          arguments: {
                            'count': '${widget.recipeCatalog.recipes.length}',
                          },
                        ),
                        onPressed: () => _showRecipes(
                          onCraftSettled: () {
                            if (dialogContext.mounted) {
                              updateWorkspace(() {});
                            }
                          },
                          onOpenOtherGrid: () {
                            if (!dialogContext.mounted) return;
                            updateWorkspace(() {
                              setState(() {
                                _activeGrid = _activeGrid == 'backpack'
                                    ? 'board'
                                    : 'backpack';
                                _keyboardX = 0;
                                _keyboardY = 0;
                              });
                            });
                          },
                        ),
                        icon: const Icon(Icons.auto_awesome_mosaic_outlined),
                      ),
                      if (_materialUseIndexUnlocked)
                        IconButton(
                          tooltip: strings.text('board.materialIndex'),
                          onPressed: _showMaterialUseIndex,
                          icon: const Icon(Icons.hub_outlined),
                        ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Tooltip(
                          message: strings.text('board.workingGridShort'),
                          child: IconButton.filledTonal(
                            key: const Key(
                              'street-scrap-workspace-select-board',
                            ),
                            isSelected: _activeGrid == 'board',
                            onPressed: _saving || workspaceInvalidReservation
                                ? null
                                : () => updateWorkspace(() {
                                    setState(() {
                                      _activeGrid = 'board';
                                      _keyboardX = 0;
                                      _keyboardY = 0;
                                    });
                                  }),
                            icon: const Icon(Icons.grid_view_rounded),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Tooltip(
                          message: strings.text('board.backpackGridShort'),
                          child: IconButton.filledTonal(
                            key: const Key(
                              'street-scrap-workspace-select-backpack',
                            ),
                            isSelected: _activeGrid == 'backpack',
                            onPressed: _saving || workspaceInvalidReservation
                                ? null
                                : () => updateWorkspace(() {
                                    setState(() {
                                      _activeGrid = 'backpack';
                                      _keyboardX = 0;
                                      _keyboardY = 0;
                                    });
                                  }),
                            icon: const Icon(Icons.backpack_outlined),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_actionError != null)
                    MaterialBanner(
                      content: Text(_actionError!),
                      actions: [
                        TextButton(
                          onPressed: () => setState(() => _actionError = null),
                          child: Text(strings.text('common.dismiss')),
                        ),
                      ],
                    ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // On landscape and desktop, give the board and item
                        // gallery their own side-by-side canvases. Portrait
                        // layouts keep the board above a paged gallery.
                        final screenSize = MediaQuery.sizeOf(context);
                        final wide =
                            screenSize.width >= 980 && screenSize.height >= 600;
                        final sideRailWidth = wide
                            ? (constraints.maxWidth * 0.4)
                                  .clamp(360.0, 560.0)
                                  .toDouble()
                            : 0.0;
                        final dimension =
                            <double>[
                                  constraints.maxWidth -
                                      sideRailWidth -
                                      (wide ? 24 : 16),
                                  constraints.maxHeight - 12,
                                  960,
                                ]
                                .reduce((a, b) => a < b ? a : b)
                                .clamp(96, 960)
                                .toDouble();
                        final gridWidget = SizedBox(
                          width: dimension,
                          height: dimension,
                          child: Focus(
                            focusNode: _keyboardGridFocus,
                            onKeyEvent: _handleGridKey,
                            child: Semantics(
                              label: strings.text('board.keyboardSemantics'),
                              child: _StreetScrapGrid(
                                grid: gridSpec,
                                objects: inventory.objects,
                                placements: placements,
                                selectedInstanceId: _selectedInstanceId,
                                cursorX: _keyboardX,
                                cursorY: _keyboardY,
                                enabled:
                                    !_saving &&
                                    !widget.session.isReadOnly &&
                                    !workspaceInvalidReservation,
                                onEmptyCellTap: (x, y) =>
                                    refresh(_placeAt(x, y)),
                                onOccupiedCellTap: (id, x, y) {
                                  _select(id);
                                  updateWorkspace(() {});
                                },
                                onDrop: (id, x, y) => refresh(
                                  _moveInstanceTo(id, _activeGrid, x, y),
                                ),
                                woodBoardSpriteBytes:
                                    widget.woodBoardSpriteBytes,
                                threadSpoolSpriteBytes:
                                    widget.threadSpoolSpriteBytes,
                                materialAtlasBytes: widget.materialAtlasBytes,
                                toolAtlasBytes: widget.toolAtlasBytes,
                                materialPackArtBytes:
                                    widget.materialPackArtBytes,
                                mineralPackArtBytes: widget.mineralPackArtBytes,
                                woodChipBundleArtBytes:
                                    widget.woodChipBundleArtBytes,
                              ),
                            ),
                          ),
                        );
                        if (!wide) return Center(child: gridWidget);
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            gridWidget,
                            const SizedBox(width: 16),
                            SizedBox(
                              width: sideRailWidth,
                              child: Card(
                                margin: EdgeInsets.zero,
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: materialShelf(
                                    availableWidth: sideRailWidth - 20,
                                    availableHeight: constraints.maxHeight - 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  if (shelfIds.isNotEmpty &&
                      MediaQuery.sizeOf(context).width < 980)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        // Give the material art a large, screen-adaptive
                        // canvas. Overflow is handled with horizontal pages;
                        // the workspace never gains a vertical scroll view.
                        const shelfGap = 8.0;
                        // On phones, give one material the full card so its
                        // pixel art reads at a glance. Paging stays horizontal
                        // and the workspace remains vertically fixed.
                        final phoneCarousel = constraints.maxWidth < 400;
                        final screenSize = MediaQuery.sizeOf(context);
                        final tileHeightRatio = screenSize.width < 980
                            ? 0.33
                            : 0.36;
                        final tileSize = phoneCarousel
                            ? (screenSize.height * 0.43)
                                  .clamp(150.0, 280.0)
                                  .clamp(0.0, constraints.maxWidth - 16)
                                  .toDouble()
                            : (screenSize.height * tileHeightRatio)
                                  .clamp(180.0, 320.0)
                                  .toDouble();
                        final pageSize = phoneCarousel
                            ? 1
                            : ((constraints.maxWidth + shelfGap) /
                                      (tileSize + shelfGap))
                                  .floor()
                                  .clamp(1, 8)
                                  .toInt();
                        final pageCount = (shelfIds.length / pageSize).ceil();
                        final page = _workspaceDetachedPage.clamp(
                          0,
                          pageCount - 1,
                        );
                        final visibleIds = shelfIds
                            .skip(page * pageSize)
                            .take(pageSize);
                        final showPager = pageCount > 1;
                        final shelfHeight =
                            tileSize + (showPager ? 44.0 : 12.0);
                        return SizedBox(
                          height: shelfHeight,
                          child: Column(
                            children: [
                              Expanded(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    for (final id in visibleIds) ...[
                                      SizedBox.square(
                                        dimension: tileSize,
                                        child: Semantics(
                                          button: true,
                                          selected: id == _selectedInstanceId,
                                          label: strings.itemName(
                                            inventory.objects[id]!.itemId,
                                          ),
                                          child: Material(
                                            key: ValueKey(
                                              'street-scrap-workspace-item-$id',
                                            ),
                                            color: id == _selectedInstanceId
                                                ? Theme.of(
                                                    context,
                                                  ).colorScheme.primaryContainer
                                                : Theme.of(context)
                                                      .colorScheme
                                                      .surfaceContainerHighest,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              side: BorderSide(
                                                color: id == _selectedInstanceId
                                                    ? Theme.of(
                                                        context,
                                                      ).colorScheme.primary
                                                    : Theme.of(context)
                                                          .colorScheme
                                                          .outlineVariant,
                                              ),
                                            ),
                                            clipBehavior: Clip.antiAlias,
                                            child: InkWell(
                                              onTap: () {
                                                _select(id);
                                                updateWorkspace(() {});
                                              },
                                              child: Stack(
                                                children: [
                                                  Center(
                                                    child: StreetScrapItemSprite(
                                                      itemId: inventory
                                                          .objects[id]!
                                                          .itemId,
                                                      source: inventory
                                                          .objects[id]!
                                                          .source,
                                                      contentItemId:
                                                          inventory
                                                                  .objects[id]!
                                                                  .containerState['contentItemId']
                                                              as String?,
                                                      woodBoardSpriteBytes: widget
                                                          .woodBoardSpriteBytes,
                                                      threadSpoolSpriteBytes: widget
                                                          .threadSpoolSpriteBytes,
                                                      materialAtlasBytes: widget
                                                          .materialAtlasBytes,
                                                      toolAtlasBytes:
                                                          widget.toolAtlasBytes,
                                                      materialPackArtBytes: widget
                                                          .materialPackArtBytes,
                                                      mineralPackSpriteBytes:
                                                          widget
                                                              .mineralPackArtBytes,
                                                      woodChipBundleSpriteBytes:
                                                          widget
                                                              .woodChipBundleArtBytes,
                                                      size: tileSize - 4,
                                                      visualScale: 1.28,
                                                    ),
                                                  ),
                                                  Positioned(
                                                    left: 6,
                                                    top: 6,
                                                    child: Tooltip(
                                                      message: strings
                                                          .itemSource(
                                                            inventory
                                                                .objects[id]!
                                                                .source,
                                                          ),
                                                      child: DecoratedBox(
                                                        decoration: BoxDecoration(
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .surface
                                                                  .withValues(
                                                                    alpha: 0.9,
                                                                  ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                9,
                                                              ),
                                                        ),
                                                        child: Padding(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                5,
                                                              ),
                                                          child: Icon(
                                                            _streetScrapIsProcessed(
                                                                  inventory
                                                                      .objects[id]!,
                                                                  strings,
                                                                )
                                                                ? Icons
                                                                      .construction_rounded
                                                                : Icons
                                                                      .search_rounded,
                                                            size: 17,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  Positioned(
                                                    right: 6,
                                                    bottom: 6,
                                                    child: Tooltip(
                                                      message: strings
                                                          .itemQuality(
                                                            inventory
                                                                .objects[id]!
                                                                .quality,
                                                          ),
                                                      child: DecoratedBox(
                                                        decoration: BoxDecoration(
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .surface
                                                                  .withValues(
                                                                    alpha: 0.9,
                                                                  ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                9,
                                                              ),
                                                        ),
                                                        child: Padding(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 6,
                                                                vertical: 3,
                                                              ),
                                                          child: Text(
                                                            '${inventory.objects[id]!.quality}',
                                                            style:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .textTheme
                                                                    .labelMedium,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (id != visibleIds.last)
                                        const SizedBox(width: shelfGap),
                                    ],
                                  ],
                                ),
                              ),
                              if (showPager)
                                SizedBox(
                                  height: 40,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        key: const Key(
                                          'street-scrap-workspace-page-previous',
                                        ),
                                        tooltip: strings.text(
                                          'board.previousPage',
                                        ),
                                        onPressed: page == 0
                                            ? null
                                            : () => updateWorkspace(() {
                                                _workspaceDetachedPage =
                                                    page - 1;
                                              }),
                                        visualDensity: VisualDensity.compact,
                                        icon: const Icon(
                                          Icons.chevron_left_rounded,
                                        ),
                                      ),
                                      Semantics(
                                        label: strings.text(
                                          'board.pageCount',
                                          arguments: {
                                            'current': '${page + 1}',
                                            'total': '$pageCount',
                                          },
                                        ),
                                        child: Row(
                                          children: [
                                            for (
                                              var index = 0;
                                              index < pageCount;
                                              index++
                                            )
                                              Container(
                                                key: ValueKey(
                                                  'street-scrap-workspace-page-dot-$index',
                                                ),
                                                width: index == page ? 16 : 7,
                                                height: 7,
                                                margin:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 3,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: index == page
                                                      ? Theme.of(
                                                          context,
                                                        ).colorScheme.primary
                                                      : Theme.of(context)
                                                            .colorScheme
                                                            .outlineVariant,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        key: const Key(
                                          'street-scrap-workspace-page-next',
                                        ),
                                        tooltip: strings.text('board.nextPage'),
                                        onPressed: page >= pageCount - 1
                                            ? null
                                            : () => updateWorkspace(() {
                                                _workspaceDetachedPage =
                                                    page + 1;
                                              }),
                                        visualDensity: VisualDensity.compact,
                                        icon: const Icon(
                                          Icons.chevron_right_rounded,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  if (!((MediaQuery.sizeOf(context).width) >= 980))
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: selectionPanel(compact: true),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _workspaceSelectionLabel(
    StreetScrapObject item,
    StreetScrapLocalizations strings,
  ) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        strings.itemName(item.itemId),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 4),
      Semantics(
        label:
            '${strings.itemSource(item.source)} · ${strings.itemQuality(item.quality)}',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
              message: strings.itemSource(item.source),
              child: Icon(
                _streetScrapIsProcessed(item, strings)
                    ? Icons.construction_rounded
                    : Icons.search_rounded,
                size: 18,
                color: _streetScrapIsProcessed(item, strings)
                    ? Theme.of(context).colorScheme.tertiary
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: strings.itemQuality(item.quality),
              child: Text(
                '${item.quality}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _workspaceItemBadge(
    BuildContext context, {
    required String message,
    required IconData icon,
  }) => Tooltip(
    message: message,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: .92),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 18),
      ),
    ),
  );

  Widget _workspaceItemQualityBadge(
    BuildContext context, {
    required int quality,
    required String message,
  }) => Tooltip(
    message: message,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: .92),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text('$quality', style: Theme.of(context).textTheme.labelLarge),
      ),
    ),
  );

  bool _stationUnlocked(StreetScrapRecipe recipe) {
    if (recipe.phase < 1 || recipe.station != 'recycler') return true;
    final stations = widget.session.snapshot.state['unlockedStations'];
    return stations is List && stations.contains('recycler');
  }

  String? _questLockReasonKey(StreetScrapRecipe recipe) {
    final chapter = _chapter;
    final rawTasks = widget.session.snapshot.state['tutorialTasks'];
    if (rawTasks != null && rawTasks is! Map) {
      throw const FormatException('教學任務存檔格式錯誤。');
    }
    if (chapter == null ||
        chapter < 1 ||
        rawTasks is! Map ||
        rawTasks['q1.01'] != true) {
      return null;
    }
    if (recipe.id == 'ss.recipe.fillet_fish' && rawTasks['q2.02'] != true) {
      return 'recipe.questPrerequisite.filletFish';
    }
    if (recipe.id == 'ss.recipe.press_rod' &&
        rawTasks['q3.01.kitClaimed'] != true) {
      return 'recipe.questPrerequisite.pressRod';
    }
    if (recipe.id == 'ss.recipe.nail_board' &&
        rawTasks['q3.02.kitClaimed'] != true) {
      return 'recipe.questPrerequisite.nailBoard';
    }
    if (recipe.id == 'ss.recipe.wooden_crate' &&
        rawTasks['q3.04.kitClaimed'] != true) {
      return 'recipe.questPrerequisite.woodenCrate';
    }
    if (recipe.id == 'ss.recipe.upgrade_bag' && rawTasks['q3.04'] != true) {
      return 'recipe.questPrerequisite.upgradeBag';
    }
    if (recipe.id == 'ss.recipe.join_thread' &&
        rawTasks['q1.02.unpicked'] != true) {
      return 'recipe.questPrerequisite.joinThread';
    }
    if (recipe.id == 'ss.recipe.sew_strip' &&
        (rawTasks['q1.02.unpicked'] != true ||
            rawTasks['q1.02.threadReady'] != true)) {
      return 'recipe.questPrerequisite.sewStrip';
    }
    return null;
  }

  bool get _materialUseIndexUnlocked {
    final raw = widget.session.snapshot.state['unlockedIndexes'];
    if (raw == null) return false;
    if (raw is! List || raw.any((entry) => entry is! String)) {
      throw const FormatException('材料用途索引存檔格式錯誤。');
    }
    return raw.contains('material_use_index');
  }

  Future<void> _showMaterialUseIndex() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.82,
        builder: (context, controller) {
          final strings = StreetScrapLocalizations.of(context);
          final itemIds = widget.catalog.footprints.keys.toList()..sort();
          return ListView(
            controller: controller,
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                strings.text('materialUses.title'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(strings.text('materialUses.description')),
              for (final itemId in itemIds)
                Builder(
                  builder: (context) {
                    final producedBy =
                        widget.recipeCatalog.recipes.values
                            .where(
                              (recipe) =>
                                  _recipeOutputItemIds(recipe).contains(itemId),
                            )
                            .map(
                              (recipe) => _recipeDisplayName(strings, recipe),
                            )
                            .toList()
                          ..sort();
                    final usedBy =
                        widget.recipeCatalog.recipes.values
                            .where(
                              (recipe) => recipe.inputGroups.any(
                                (group) => group.any(
                                  (input) => input.itemId == itemId,
                                ),
                              ),
                            )
                            .map(
                              (recipe) => _recipeDisplayName(strings, recipe),
                            )
                            .toList()
                          ..sort();
                    if (producedBy.isEmpty && usedBy.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return ListTile(
                      dense: true,
                      title: Text(strings.itemName(itemId)),
                      subtitle: Text(
                        [
                          if (producedBy.isNotEmpty)
                            strings.text(
                              'materialUses.producedBy',
                              arguments: {'recipes': producedBy.join('、')},
                            ),
                          if (usedBy.isNotEmpty)
                            strings.text(
                              'materialUses.usedBy',
                              arguments: {'recipes': usedBy.join('、')},
                            ),
                        ].join('\n'),
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    ),
  );

  Future<void> _showCollectionBook(
    List<String> itemIds,
    Set<String> collected,
  ) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.82,
        builder: (context, controller) {
          final strings = StreetScrapLocalizations.of(context);
          return ListView(
            controller: controller,
            padding: const EdgeInsets.all(16),
            children: [
              _collectionSheetHeader(
                context,
                strings.text('collection.title'),
                const Key('street-scrap-close-collection'),
              ),
              Text(
                strings.text(
                  'collection.progress',
                  arguments: {
                    'owned':
                        '${collected.intersection(itemIds.toSet()).length}',
                    'total': '${itemIds.length}',
                  },
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _showMaterialUseIndex,
                icon: const Icon(Icons.menu_book_outlined),
                label: Text(strings.text('collection.viewMaterialUses')),
              ),
              for (final itemId in itemIds)
                ListTile(
                  dense: true,
                  leading: Icon(
                    collected.contains(itemId)
                        ? Icons.check_circle_outline
                        : Icons.radio_button_unchecked,
                  ),
                  title: Text(strings.itemName(itemId)),
                  subtitle: Text(
                    strings.text(
                      collected.contains(itemId)
                          ? 'collection.collected'
                          : 'collection.notCollected',
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );

  Future<void> _showKnownRecipes(
    List<StreetScrapRecipe> recipes,
    bool Function(StreetScrapRecipe) isKnown,
    int knownCount,
  ) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.82,
        builder: (context, controller) {
          final strings = StreetScrapLocalizations.of(context);
          return ListView(
            controller: controller,
            padding: const EdgeInsets.all(16),
            children: [
              _collectionSheetHeader(
                context,
                strings.text('recipes.known'),
                const Key('street-scrap-close-recipes'),
              ),
              Text(
                strings.text(
                  'recipes.progress',
                  arguments: {
                    'known': '$knownCount',
                    'total': '${recipes.length}',
                  },
                ),
              ),
              for (final recipe in recipes)
                ListTile(
                  key: Key('street-scrap-known-recipe-${recipe.id}'),
                  dense: true,
                  title: Text(_recipeDisplayName(strings, recipe)),
                  subtitle: Text(
                    isKnown(recipe)
                        ? strings.text(
                            'recipes.unlockedPhase',
                            arguments: {'phase': '${recipe.phase}'},
                          )
                        : recipe.phase > (_chapter ?? 0)
                        ? strings.text(
                            'recipes.lockedPhase',
                            arguments: {'phase': '${recipe.phase}'},
                          )
                        : _questLockReasonKey(recipe) != null
                        ? strings.text(
                            'recipes.questLocked',
                            arguments: {
                              'quest': strings.text(
                                _questLockReasonKey(recipe)!,
                              ),
                            },
                          )
                        : strings.text('recipes.stationLocked'),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );

  Widget _collectionSheetHeader(
    BuildContext context,
    String title,
    Key closeKey,
  ) => Row(
    // Re-resolve from the sheet context so the header follows live host locale changes.
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
      ),
      IconButton(
        key: closeKey,
        tooltip: StreetScrapLocalizations.of(context).text('common.close'),
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.close),
      ),
    ],
  );

  StreetScrapInventory get _inventory {
    final saved = widget.session.snapshot.state['inventory'];
    if (saved == null) return widget.catalog.emptyInventory(grids: _grids);
    if (saved is! Map) throw const FormatException('遊戲物品存檔格式錯誤。');
    return widget.catalog.inventoryFromJson(
      grids: _grids,
      json: Map<String, Object?>.from(saved),
    );
  }

  double _heatTargetWidthMultiplier(Map operation, StreetScrapRecipe recipe) {
    final rawIds = operation['inputInstanceIds'];
    if (rawIds is! List || rawIds.any((id) => id is! String)) return 1;
    final inventory = _inventory;
    final inputs = rawIds
        .cast<String>()
        .where(inventory.objects.containsKey)
        .map((id) => inventory.objects[id]!);
    return streetScrapHeatTargetWidthMultiplier(recipe, inputs);
  }

  Future<bool> _commit(
    StreetScrapInventory Function(StreetScrapInventory) reduce,
  ) async {
    if (_saving || widget.session.isReadOnly) return false;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() {
      _saving = true;
      _actionError = null;
      _lastMoveUndo = null;
    });
    try {
      await widget.session.applyInventoryCommand(
        commandId: 'inventory-${DateTime.now().microsecondsSinceEpoch}',
        expectedRevision: widget.session.snapshot.revision,
        catalog: widget.catalog,
        grids: _grids,
        reduceInventory: reduce,
      );
      unawaited(_playSound(StreetScrapAudioCue.tap));
      if (!mounted) return true;
      setState(() => _selectedInstanceId = null);
      return true;
    } on Object catch (error) {
      if (mounted) setState(() => _actionError = _friendlyError(error));
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _select(String instanceId) {
    setState(() {
      _selectedInstanceId = _selectedInstanceId == instanceId
          ? null
          : instanceId;
      _actionError = null;
    });
  }

  Future<void> _craftRecipe(
    StreetScrapRecipe recipe, {
    VoidCallback? onSettled,
    VoidCallback? onOpenOtherGrid,
  }) async {
    if (_saving) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            StreetScrapLocalizations.of(context).text('craft.errorSaving'),
          ),
        ),
      );
      return;
    }
    if (widget.session.isReadOnly) return;
    if (widget.session.snapshot.state['craftOperation'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            StreetScrapLocalizations.of(
              context,
            ).text('craft.errorPendingOperation'),
          ),
        ),
      );
      return;
    }
    final chapter = _chapter;
    final strings = StreetScrapLocalizations.of(context);
    final questLockReasonKey = _questLockReasonKey(recipe);
    if (chapter == null ||
        recipe.phase > chapter ||
        !_stationUnlocked(recipe) ||
        questLockReasonKey != null) {
      setState(
        () => _actionError = chapter == null
            ? strings.text('craft.error.chapterProgressInvalid')
            : questLockReasonKey != null
            ? strings.text(
                'craft.error.questLocked',
                arguments: {'quest': strings.text(questLockReasonKey)},
              )
            : 'recycler' == recipe.station &&
                  recipe.phase >= 1 &&
                  !_stationUnlocked(recipe)
            ? strings.text('craft.error.stationLocked')
            : strings.text('craft.error.phaseLocked'),
      );
      return;
    }
    final inventory = _inventory;
    final available = inventory.objects.values
        .where(
          (item) =>
              inventory.placements[item.instanceId]?.gridId == _activeGrid &&
              item.containerContents.isEmpty,
        )
        .toList(growable: false);
    var groupIndex = 0;
    final selectedInputs = <String>{};
    final selectedTools = <String>{};
    final mastery = widget.session.snapshot.state['mastery'];
    final confirmationOnly = StreetScrapCrafting.isConfirmationOnlyRecipe(
      recipe,
    );
    final canQuickCraft =
        confirmationOnly ||
        (mastery is Map &&
            mastery[recipe.id] == recipe.quality.masteryRevision);

    bool selectionIsComplete(List<StreetScrapRecipeInput> group) {
      final expected = <String, int>{};
      for (final input in group) {
        expected.update(
          input.itemId,
          (count) => count + input.quantity,
          ifAbsent: () => input.quantity,
        );
      }
      final actual = <String, int>{};
      for (final id in selectedInputs) {
        final item = inventory.objects[id];
        if (item != null) {
          final itemId = StreetScrapCrafting.inputItemIdForObject(recipe, item);
          actual.update(itemId, (count) => count + 1, ifAbsent: () => 1);
        }
      }
      if (actual.length != expected.length ||
          expected.entries.any((entry) => actual[entry.key] != entry.value)) {
        return false;
      }
      final requiredTools = <String, int>{};
      for (final id in recipe.reusableTools) {
        requiredTools.update(id, (count) => count + 1, ifAbsent: () => 1);
      }
      final selectedToolCounts = <String, int>{};
      for (final id in selectedTools) {
        final item = inventory.objects[id];
        if (item != null) {
          selectedToolCounts.update(
            item.itemId,
            (count) => count + 1,
            ifAbsent: () => 1,
          );
        }
      }
      return requiredTools.length == selectedToolCounts.length &&
          requiredTools.entries.every(
            (entry) => selectedToolCounts[entry.key] == entry.value,
          ) &&
          !selectedInputs.any(selectedTools.contains);
    }

    int selectedInputCount(String itemId) => selectedInputs.where((id) {
      final item = inventory.objects[id];
      return item != null &&
          StreetScrapCrafting.inputItemIdForObject(recipe, item) == itemId;
    }).length;

    final choice = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final strings = StreetScrapLocalizations.of(dialogContext);
          final group = recipe.inputGroups[groupIndex];
          final allowedItems = group.map((item) => item.itemId).toSet();
          final requiredTools = recipe.reusableTools.toSet();
          final requiredItemIds = {...allowedItems, ...requiredTools};
          final boardInputCounts = <String, int>{};
          for (final item in available) {
            final itemId = StreetScrapCrafting.inputItemIdForObject(
              recipe,
              item,
            );
            boardInputCounts.update(
              itemId,
              (count) => count + 1,
              ifAbsent: () => 1,
            );
          }
          final missingFromActiveGrid =
              group.any(
                (need) => (boardInputCounts[need.itemId] ?? 0) < need.quantity,
              ) ||
              requiredTools.any(
                (toolId) => !available.any((item) => item.itemId == toolId),
              );
          final storedIds = inventory.storage.values
              .expand((ids) => ids)
              .toSet();
          final matchingItemsElsewhere = inventory.objects.values.any(
            (item) =>
                !storedIds.contains(item.instanceId) &&
                item.containerContents.isEmpty &&
                requiredItemIds.contains(
                  requiredTools.contains(item.itemId)
                      ? item.itemId
                      : StreetScrapCrafting.inputItemIdForObject(recipe, item),
                ) &&
                inventory.placements[item.instanceId]?.gridId != _activeGrid,
          );
          final valid = selectionIsComplete(group);
          final selectedObjects = selectedInputs
              .map((id) => inventory.objects[id])
              .whereType<StreetScrapObject>()
              .toList(growable: false);
          final qualityEffects = valid
              ? StreetScrapCrafting.applicableQualityTraitEffects(
                  recipe,
                  selectedObjects,
                )
              : const <Map<String, Object?>>[];
          final qualityTraitPresentations = qualityEffects
              .map((effect) {
                final traitId = effect['traitId']! as String;
                return MapEntry(
                  traitId,
                  StreetScrapTraitPresentation.forId(
                    traitId,
                    localizations: strings,
                  ),
                );
              })
              .toList(growable: false);
          final canManual =
              recipe.manualCheckpoints.length == 3 &&
              recipe.failureResolution != null &&
              (recipe.retainedInputIds.isEmpty ||
                  recipe.supportsIdentityTransform) &&
              (recipe.outputs.isNotEmpty || recipe.stateEffect != null) &&
              (recipe.quality.mode != 'preserve-primary' ||
                  recipe.supportsIdentityTransform);
          return AlertDialog(
            title: Text(
              strings.text(
                'craft.dialog.title',
                arguments: {'recipe': _recipeDisplayName(strings, recipe)},
              ),
            ),
            content: SizedBox(
              width: 480,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.65,
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        key: const Key('street-scrap-craft-help'),
                        tooltip: strings.text(
                          'craft.dialog.instruction',
                          arguments: {
                            'instructions': strings.operationInstructions(
                              recipe.instructions,
                            ),
                          },
                        ),
                        visualDensity: VisualDensity.compact,
                        onPressed: () {},
                        icon: const Icon(Icons.info_outline_rounded),
                      ),
                    ),
                    if (recipe.inputGroups.length > 1)
                      DropdownButton<int>(
                        value: groupIndex,
                        isExpanded: true,
                        items: [
                          for (var i = 0; i < recipe.inputGroups.length; i++)
                            DropdownMenuItem(
                              value: i,
                              child: Text(
                                strings.text(
                                  'craft.dialog.materialPlan',
                                  arguments: {'number': '${i + 1}'},
                                ),
                              ),
                            ),
                        ],
                        onChanged: (value) => setDialogState(() {
                          groupIndex = value ?? 0;
                          selectedInputs.clear();
                        }),
                      ),
                    if (missingFromActiveGrid &&
                        (matchingItemsElsewhere || onOpenOtherGrid != null))
                      Card(
                        key: const Key(
                          'street-scrap-craft-materials-on-other-grid',
                        ),
                        child: ListTile(
                          leading: Icon(
                            _activeGrid == 'backpack'
                                ? Icons.grid_view_rounded
                                : Icons.backpack_outlined,
                          ),
                          title: Text(
                            strings.text(
                              matchingItemsElsewhere
                                  ? 'craft.dialog.materialsOnOtherGrid'
                                  : 'craft.dialog.materialsNotOnBoard',
                            ),
                          ),
                          trailing: onOpenOtherGrid == null
                              ? null
                              : IconButton.filledTonal(
                                  key: const Key(
                                    'street-scrap-craft-open-other-grid',
                                  ),
                                  tooltip: strings.text(
                                    'craft.dialog.organizeOtherGrid',
                                  ),
                                  onPressed: () {
                                    Navigator.of(dialogContext).pop();
                                    onOpenOtherGrid();
                                  },
                                  icon: Icon(
                                    _activeGrid == 'backpack'
                                        ? Icons.grid_view_rounded
                                        : Icons.backpack_outlined,
                                  ),
                                ),
                        ),
                      ),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final materialEntries = available
                            .where(
                              (item) =>
                                  allowedItems.contains(
                                    StreetScrapCrafting.inputItemIdForObject(
                                      recipe,
                                      item,
                                    ),
                                  ) &&
                                  StreetScrapCrafting.isQuestSupplyAllowedForRecipe(
                                    recipe,
                                    item,
                                  ),
                            )
                            .toList(growable: false)
                            .asMap()
                            .entries;
                        final cardWidth = constraints.maxWidth >= 440
                            ? (constraints.maxWidth - 8) / 2
                            : constraints.maxWidth;
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final entry in materialEntries)
                              Builder(
                                builder: (context) {
                                  final item = entry.value;
                                  final itemId =
                                      StreetScrapCrafting.inputItemIdForObject(
                                        recipe,
                                        item,
                                      );
                                  final source =
                                      item.containerState['contentSource']
                                          is String
                                      ? item.containerState['contentSource']!
                                            as String
                                      : item.source;
                                  final quality =
                                      item.containerState['contentQuality']
                                          is int
                                      ? item.containerState['contentQuality']!
                                            as int
                                      : item.quality;
                                  final checked = selectedInputs.contains(
                                    item.instanceId,
                                  );
                                  final label = strings.text(
                                    'craft.dialog.materialQuality',
                                    arguments: {
                                      'name': strings.itemName(itemId),
                                      'source': strings.itemSource(source),
                                      'quality': '$quality',
                                    },
                                  );
                                  return SizedBox(
                                    width: cardWidth,
                                    child: Semantics(
                                      button: true,
                                      checked: checked,
                                      label: label,
                                      child: Card(
                                        key: Key(
                                          'street-scrap-craft-material-${item.instanceId}',
                                        ),
                                        margin: EdgeInsets.zero,
                                        clipBehavior: Clip.antiAlias,
                                        color: checked
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.secondaryContainer
                                            : null,
                                        child: InkWell(
                                          onTap: () => setDialogState(() {
                                            if (checked) {
                                              selectedInputs.remove(
                                                item.instanceId,
                                              );
                                            } else {
                                              selectedInputs.add(
                                                item.instanceId,
                                              );
                                            }
                                          }),
                                          child: Padding(
                                            padding: const EdgeInsets.all(6),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Stack(
                                                  alignment: Alignment.topRight,
                                                  children: [
                                                    StreetScrapItemSprite(
                                                      itemId: itemId,
                                                      source: item.source,
                                                      contentItemId:
                                                          item.containerState['contentItemId']
                                                              as String?,
                                                      woodBoardSpriteBytes: widget
                                                          .woodBoardSpriteBytes,
                                                      threadSpoolSpriteBytes: widget
                                                          .threadSpoolSpriteBytes,
                                                      materialAtlasBytes: widget
                                                          .materialAtlasBytes,
                                                      toolAtlasBytes:
                                                          widget.toolAtlasBytes,
                                                      materialPackArtBytes: widget
                                                          .materialPackArtBytes,
                                                      mineralPackSpriteBytes:
                                                          widget
                                                              .mineralPackArtBytes,
                                                      woodChipBundleSpriteBytes:
                                                          widget
                                                              .woodChipBundleArtBytes,
                                                      size: 88,
                                                      visualScale: 1.5,
                                                    ),
                                                    if (checked)
                                                      DecoratedBox(
                                                        decoration: BoxDecoration(
                                                          color: Theme.of(
                                                            context,
                                                          ).colorScheme.primary,
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                        child: Icon(
                                                          Icons.check_rounded,
                                                          size: 22,
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .onPrimary,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                const SizedBox(height: 3),
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        strings.itemName(
                                                          itemId,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 5),
                                                    Tooltip(
                                                      message: strings
                                                          .itemSource(source),
                                                      child: const Icon(
                                                        Icons
                                                            .history_toggle_off,
                                                        size: 15,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 3),
                                                    Text('$quality'),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        );
                      },
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final need in group)
                          Builder(
                            builder: (context) {
                              final selected = selectedInputCount(need.itemId);
                              final label = strings.text(
                                'craft.dialog.selectedCount',
                                arguments: {
                                  'name': strings.itemName(need.itemId),
                                  'selected': '$selected',
                                  'required': '${need.quantity}',
                                },
                              );
                              return Semantics(
                                key: Key(
                                  'street-scrap-craft-input-count-${need.itemId}',
                                ),
                                label: label,
                                child: Tooltip(
                                  message: label,
                                  child: SizedBox(
                                    width: 64,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        StreetScrapItemSprite(
                                          itemId: need.itemId,
                                          source: 'street-find',
                                          woodBoardSpriteBytes:
                                              widget.woodBoardSpriteBytes,
                                          threadSpoolSpriteBytes:
                                              widget.threadSpoolSpriteBytes,
                                          materialAtlasBytes:
                                              widget.materialAtlasBytes,
                                          toolAtlasBytes: widget.toolAtlasBytes,
                                          materialPackArtBytes:
                                              widget.materialPackArtBytes,
                                          mineralPackSpriteBytes:
                                              widget.mineralPackArtBytes,
                                          woodChipBundleSpriteBytes:
                                              widget.woodChipBundleArtBytes,
                                          size: 36,
                                          visualScale: 1.45,
                                        ),
                                        DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: selected >= need.quantity
                                                ? Theme.of(
                                                    context,
                                                  ).colorScheme.primaryContainer
                                                : Theme.of(context)
                                                      .colorScheme
                                                      .surfaceContainerHighest,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 2,
                                            ),
                                            child: Text(
                                              '$selected/${need.quantity}',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.labelSmall,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                    if (requiredTools.isNotEmpty) ...[
                      ListTile(
                        title: Text(strings.text('craft.dialog.retainedTools')),
                      ),
                      for (final item in available.where(
                        (item) => requiredTools.contains(item.itemId),
                      ))
                        CheckboxListTile(
                          dense: true,
                          value: selectedTools.contains(item.instanceId),
                          title: Text(
                            '${strings.itemName(item.itemId)}・'
                            '${item.toolDurability == null ? strings.text('craft.dialog.toolDurabilityUnknown') : strings.text('craft.dialog.toolDurability', arguments: {'durability': '${item.toolDurability}'})}',
                          ),
                          onChanged: (value) => setDialogState(() {
                            if (value == true) {
                              selectedTools.add(item.instanceId);
                            } else {
                              selectedTools.remove(item.instanceId);
                            }
                          }),
                        ),
                    ],
                    if (valid) ...[
                      const Divider(),
                      Text(strings.text('craft.qualityTraits.title')),
                      if (qualityEffects.isEmpty)
                        Text(strings.text('craft.qualityTraits.empty'))
                      else ...[
                        for (final trait in qualityTraitPresentations)
                          Text(
                            strings.text(
                              'craft.dialog.traitEffect',
                              arguments: {
                                'name': trait.value.name,
                                'effect': trait.value.effect,
                              },
                            ),
                            key: Key('street-scrap-quality-trait-${trait.key}'),
                          ),
                        Text(strings.text('craft.qualityTraits.polarityNote')),
                      ],
                    ],
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(strings.text('craft.dialog.cancel')),
              ),
              if (canQuickCraft)
                OutlinedButton(
                  onPressed: valid
                      ? () => Navigator.pop(dialogContext, {
                          'group': groupIndex,
                          'inputs': selectedInputs.toList(),
                          'tools': selectedTools.toList(),
                          'manual': false,
                          'points': 0,
                        })
                      : null,
                  child: Text(
                    strings.text(
                      confirmationOnly
                          ? 'craft.dialog.confirmComplete'
                          : 'craft.dialog.quickCraft',
                    ),
                  ),
                ),
              FilledButton(
                onPressed: valid && canManual
                    ? () => Navigator.pop(dialogContext, {
                        'group': groupIndex,
                        'inputs': selectedInputs.toList(),
                        'tools': selectedTools.toList(),
                        'manual': true,
                      })
                    : null,
                child: Text(
                  strings.text(
                    canManual
                        ? 'craft.dialog.startManual'
                        : 'craft.dialog.manualUnavailable',
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
    if (choice == null || !mounted) return;
    final commandId = 'craft-${DateTime.now().microsecondsSinceEpoch}';
    setState(() {
      _saving = true;
      _actionError = null;
    });
    try {
      if (choice['manual']! as bool) {
        final operationId = 'operation-$commandId';
        await StreetScrapCrafting.beginManual(
          session: widget.session,
          inventoryCatalog: widget.catalog,
          recipe: recipe,
          grids: _grids,
          gridId: _activeGrid,
          inputGroupIndex: choice['group']! as int,
          inputInstanceIds: (choice['inputs']! as List).cast<String>(),
          toolInstanceIds: (choice['tools']! as List).cast<String>(),
          operationId: operationId,
          commandId: commandId,
          expectedRevision: widget.session.snapshot.revision,
          contentVersion: streetScrapCraftContentVersion(
            widget.session.contentVersions,
          ),
        );
        if (mounted) setState(() {});
        await _continueCraftOperation();
        return;
      }
      final result = await StreetScrapCrafting.craft(
        session: widget.session,
        inventoryCatalog: widget.catalog,
        recipe: recipe,
        grids: _grids,
        gridId: _activeGrid,
        inputGroupIndex: choice['group']! as int,
        inputInstanceIds: (choice['inputs']! as List).cast<String>(),
        toolInstanceIds: (choice['tools']! as List).cast<String>(),
        commandId: commandId,
        expectedRevision: widget.session.snapshot.revision,
        manual: choice['manual']! as bool,
        manualPoints: 0,
        outputInstanceId: (index) => '$commandId-output-$index',
      );
      if (!mounted) return;
      setState(() {
        _selectedInstanceId = null;
      });
      final details = result.result as Map;
      unawaited(
        _playSound(
          details['succeeded'] == true
              ? StreetScrapAudioCue.success
              : StreetScrapAudioCue.miss,
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            StreetScrapLocalizations.of(context).text(
              details['succeeded'] == true
                  ? 'craft.result.success'
                  : 'craft.result.missed',
              arguments: {'quality': '${details['quality']}'},
            ),
          ),
        ),
      );
    } on Object catch (error) {
      if (mounted) setState(() => _actionError = _friendlyCraftError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
      onSettled?.call();
    }
  }

  Future<void> _startTraitMaintenance(
    StreetScrapObject target,
    StreetScrapTraitMaintenanceProfile profile,
  ) async {
    final strings = StreetScrapLocalizations.of(context);
    final title = strings.maintenanceTitle(profile.title);
    final materialName = strings.itemName(profile.auxiliaryItemId);
    final waterName = profile.waterItemId == null
        ? ''
        : strings.itemName(profile.waterItemId!);
    final traitName = StreetScrapTraitPresentation.forId(
      profile.traitId,
      localizations: strings,
    ).name;
    if (_saving ||
        widget.session.isReadOnly ||
        (widget.session.snapshot.state['chapter'] as int? ?? 0) < 3) {
      setState(() => _actionError = strings.text('maintenance.errorChapter'));
      return;
    }
    final inventory = _inventory;
    final auxiliaryOptions = inventory.objects.values
        .where(
          (item) =>
              item.itemId == profile.auxiliaryItemId &&
              inventory.placements[item.instanceId]?.gridId == _activeGrid &&
              item.containerContents.isEmpty &&
              !_lockedCraftIds.contains(item.instanceId),
        )
        .toList(growable: false);
    final waterOptions = profile.waterItemId == null
        ? const <StreetScrapObject>[]
        : inventory.objects.values
              .where(
                (item) =>
                    const {
                      'container.clean',
                      'container.clean_jar',
                      'container.used_intact',
                    }.contains(item.itemId) &&
                    item.containerState['contentItemId'] ==
                        profile.waterItemId &&
                    const {
                      'clean',
                      'utility',
                    }.contains(item.containerState['cleanliness']) &&
                    inventory.placements[item.instanceId]?.gridId ==
                        _activeGrid &&
                    item.containerContents.isEmpty &&
                    !_lockedCraftIds.contains(item.instanceId),
              )
              .toList(growable: false);
    if (auxiliaryOptions.isEmpty ||
        (profile.waterItemId != null && waterOptions.isEmpty)) {
      setState(
        () => _actionError = profile.waterItemId == null
            ? strings.text(
                'maintenance.errorAux',
                arguments: {'title': title, 'material': materialName},
              )
            : strings.text(
                'maintenance.errorAuxWater',
                arguments: {
                  'title': title,
                  'material': materialName,
                  'water': waterName,
                },
              ),
      );
      return;
    }
    var auxiliaryId = auxiliaryOptions.first.instanceId;
    var vesselId = waterOptions.isEmpty ? null : waterOptions.first.instanceId;
    final selections = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            strings.text('maintenance.prepare', arguments: {'title': title}),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                strings.text(
                  'maintenance.cost',
                  arguments: {
                    'material': materialName,
                    'waterCost': profile.waterItemId == null
                        ? ''
                        : strings.text(
                            'maintenance.waterCost',
                            arguments: {'water': waterName},
                          ),
                    'vesselNote': profile.waterItemId == null
                        ? ''
                        : strings.text('maintenance.vesselNote'),
                    'trait': traitName,
                  },
                ),
              ),
              DropdownButtonFormField<String>(
                initialValue: auxiliaryId,
                decoration: InputDecoration(labelText: materialName),
                items: [
                  for (final item in auxiliaryOptions)
                    DropdownMenuItem(
                      value: item.instanceId,
                      child: Text(
                        strings.text(
                          'maintenance.quality',
                          arguments: {
                            'name': strings.itemName(item.itemId),
                            'quality': '${item.quality}',
                          },
                        ),
                      ),
                    ),
                ],
                onChanged: (value) => setDialogState(() {
                  if (value != null) auxiliaryId = value;
                }),
              ),
              if (profile.waterItemId != null)
                DropdownButtonFormField<String>(
                  initialValue: vesselId,
                  decoration: InputDecoration(
                    labelText: strings.text(
                      'maintenance.vesselLabel',
                      arguments: {'water': waterName},
                    ),
                  ),
                  items: [
                    for (final item in waterOptions)
                      DropdownMenuItem(
                        value: item.instanceId,
                        child: Text(
                          strings.text(
                            'maintenance.vesselQuality',
                            arguments: {
                              'name': strings.itemName(item.itemId),
                              'quality':
                                  '${item.containerState['contentQuality'] ?? item.quality}',
                            },
                          ),
                        ),
                      ),
                  ],
                  onChanged: (value) => setDialogState(() {
                    if (value != null) vesselId = value;
                  }),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(strings.text('maintenance.later')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, {
                'auxiliary': auxiliaryId,
                ...?(vesselId == null ? null : {'vessel': vesselId}),
              }),
              child: Text(
                strings.text('maintenance.start', arguments: {'title': title}),
              ),
            ),
          ],
        ),
      ),
    );
    if (selections == null || !mounted) return;
    setState(() {
      _saving = true;
      _actionError = null;
    });
    final operationId =
        '${profile.traitId}-${DateTime.now().microsecondsSinceEpoch}';
    try {
      await StreetScrapMaintenance.beginTraitMaintenance(
        session: widget.session,
        catalog: widget.catalog,
        grids: _grids,
        gridId: _activeGrid,
        profile: profile,
        targetInstanceId: target.instanceId,
        auxiliaryInstanceId: selections['auxiliary']!,
        waterVesselInstanceId: selections['vessel'],
        operationId: operationId,
        commandId: 'begin-craft-$operationId',
        expectedRevision: widget.session.snapshot.revision,
      );
      if (mounted) setState(() {});
      await _continueCraftOperation();
    } on Object catch (error) {
      if (mounted) setState(() => _actionError = _friendlyCraftError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _continueCraftOperation() async {
    while (mounted) {
      final raw = widget.session.snapshot.state['craftOperation'];
      if (raw is! Map ||
          raw['recipeId'] is! String ||
          raw['operationId'] is! String) {
        return;
      }
      final recipe = widget.recipeCatalog[raw['recipeId'] as String];
      final maintenanceProfile = StreetScrapMaintenance.profileForRecipeId(
        raw['recipeId'] as String,
      );
      if (maintenanceProfile != null) {
        await _continueTraitMaintenance(raw, maintenanceProfile);
        return;
      }
      if (recipe == null) {
        setState(
          () => _actionError = StreetScrapLocalizations.of(
            context,
          ).text('craft.error.recipeVersionUnavailable'),
        );
        return;
      }
      if (recipe.manualCheckpoints.length != 3) {
        setState(
          () => _actionError = StreetScrapLocalizations.of(
            context,
          ).text('craft.error.operationIncompatible'),
        );
        return;
      }
      final answers = raw['answers'];
      if (answers is! List || answers.any((answer) => answer is! int)) {
        setState(
          () => _actionError = StreetScrapLocalizations.of(
            context,
          ).text('craft.error.operationMalformed'),
        );
        return;
      }
      if (answers.length == recipe.manualCheckpoints.length) {
        try {
          final result = await StreetScrapCrafting.resumeManual(
            session: widget.session,
            inventoryCatalog: widget.catalog,
            recipe: recipe,
            grids: _grids,
          );
          if (result != null && mounted) {
            final details = result.result as Map;
            setState(() {});
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_craftResultMessage(details))),
            );
          }
        } on Object catch (error) {
          if (mounted) {
            setState(() => _actionError = _friendlyCraftError(error));
          }
        }
        return;
      }
      if (answers.length > recipe.manualCheckpoints.length) {
        setState(
          () => _actionError = StreetScrapLocalizations.of(
            context,
          ).text('craft.error.operationHasExtraSteps'),
        );
        return;
      }
      final operationId = raw['operationId'] as String;
      final checkpointIndex = answers.length;
      final checkpoint = recipe.manualCheckpoints[checkpointIndex];
      final option = await showDialog<int>(
        context: context,
        builder: (dialogContext) => StreetScrapOperationCheckpointDialog(
          operationId: recipe.operationId,
          step: checkpointIndex,
          prompt: StreetScrapLocalizations.of(
            dialogContext,
          ).checkpointPrompt(checkpoint.prompt),
          options: checkpoint.options,
          correctOption: checkpoint.correctOption,
          targetWidthMultiplier: _heatTargetWidthMultiplier(raw, recipe),
          assistedControls: _gameSettings.assistedControls,
        ),
      );
      if (option == null || !mounted) return;
      try {
        final result = await StreetScrapCrafting.answerManualCheckpoint(
          session: widget.session,
          inventoryCatalog: widget.catalog,
          recipe: recipe,
          grids: _grids,
          operationId: operationId,
          optionIndex: option,
          expectedRevision: widget.session.snapshot.revision,
        );
        if (!mounted) return;
        if (result != null) {
          final details = result.result as Map;
          unawaited(
            _playSound(
              details['succeeded'] == true
                  ? StreetScrapAudioCue.success
                  : StreetScrapAudioCue.miss,
            ),
          );
          setState(() {});
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(_craftResultMessage(details))));
          return;
        }
      } on Object catch (error) {
        if (mounted) setState(() => _actionError = _friendlyCraftError(error));
        return;
      }
    }
  }

  String _craftResultMessage(Map details) {
    final strings = StreetScrapLocalizations.of(context);
    return strings.text(
      details['succeeded'] == true
          ? 'craft.result.success'
          : 'craft.result.missed',
      arguments: {'quality': '${details['quality']}'},
    );
  }

  Future<void> _continueTraitMaintenance(
    Map raw,
    StreetScrapTraitMaintenanceProfile profile,
  ) async {
    final strings = StreetScrapLocalizations.of(context);
    final title = strings.maintenanceTitle(profile.title);
    final trait = StreetScrapTraitPresentation.forId(
      profile.traitId,
      localizations: strings,
    ).name;
    final operationId = raw['operationId'];
    final answers = raw['answers'];
    if (operationId is! String ||
        answers is! List ||
        answers.any((answer) => answer is! int) ||
        answers.length > 3) {
      setState(() => _actionError = strings.text('maintenance.errorMalformed'));
      return;
    }
    if (raw['status'] == 'readyToClear' || answers.length == 3) {
      try {
        final result = await StreetScrapMaintenance.resumeMaintenance(
          session: widget.session,
          catalog: widget.catalog,
          grids: _grids,
        );
        final saved = raw['result'];
        final outcome = result?.result ?? saved;
        if (mounted && outcome is Map) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                outcome['succeeded'] == true
                    ? strings.text(
                        'maintenance.complete',
                        arguments: {'title': title},
                      )
                    : strings.text(
                        'maintenance.missed',
                        arguments: {'title': title, 'trait': trait},
                      ),
              ),
            ),
          );
        }
      } on Object catch (error) {
        if (mounted) setState(() => _actionError = _friendlyCraftError(error));
      }
      return;
    }
    final step = answers.length;
    final option = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StreetScrapOperationCheckpointDialog(
        operationId: profile.operationId,
        step: step,
        prompt: strings.checkpointPrompt(profile.prompts[step]),
        options: [
          strings.text('checkpoint.leftZone'),
          strings.text('checkpoint.promptZone'),
          strings.text('checkpoint.rightZone'),
        ],
        // The dialog maps the step-specific swipe target to option 1, which is
        // also the saved success marker used by the maintenance score.
        correctOption: 1,
        assistedControls: _gameSettings.assistedControls,
      ),
    );
    if (option == null || !mounted) return;
    try {
      final result = await StreetScrapMaintenance.answerMaintenanceCheckpoint(
        session: widget.session,
        catalog: widget.catalog,
        grids: _grids,
        operationId: operationId,
        optionIndex: option,
        expectedRevision: widget.session.snapshot.revision,
      );
      if (result != null && mounted) {
        setState(() {});
        final details = result.result as Map;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              details['succeeded'] == true
                  ? strings.text(
                      'maintenance.complete',
                      arguments: {'title': title},
                    )
                  : strings.text(
                      'maintenance.missed',
                      arguments: {'title': title, 'trait': trait},
                    ),
            ),
          ),
        );
        return;
      }
      await _continueCraftOperation();
    } on Object catch (error) {
      if (mounted) setState(() => _actionError = _friendlyCraftError(error));
    }
  }

  Future<void> _cancelCraftOperation(String operationId) async {
    if (_saving || widget.session.isReadOnly) return;
    setState(() {
      _saving = true;
      _actionError = null;
    });
    try {
      final recipeId =
          (widget.session.snapshot.state['craftOperation']
              as Map?)?['recipeId'];
      if (recipeId is String &&
          StreetScrapMaintenance.profileForRecipeId(recipeId) != null) {
        await StreetScrapMaintenance.cancelMaintenance(
          session: widget.session,
          operationId: operationId,
          expectedRevision: widget.session.snapshot.revision,
        );
      } else {
        await StreetScrapCrafting.cancelManual(
          session: widget.session,
          operationId: operationId,
          expectedRevision: widget.session.snapshot.revision,
        );
      }
      if (mounted) setState(() {});
    } on Object catch (error) {
      if (mounted) setState(() => _actionError = _friendlyCraftError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _friendlyCraftError(Object error) {
    final strings = StreetScrapLocalizations.of(context);
    if (error is StateError) {
      final message = error.message;
      if (message.startsWith('No fitting space for ') ||
          message == 'Not enough space to unpack every object.') {
        return strings.text('craft.error.outputSpace');
      }
      final key = switch (error.message) {
        'craftFailureNotStructured' => 'craft.error.unstructuredFailure',
        'craftInputMismatch' ||
        'craftInputUnavailable' => 'craft.error.inputMismatch',
        'craftToolsMismatch' ||
        'craftToolUnavailable' => 'craft.error.toolsMismatch',
        'recipeNotMastered' => 'craft.error.notMastered',
        'recipePhaseLocked' => 'craft.error.phaseLocked',
        'recipeStationLocked' => 'craft.error.stationLocked',
        'q4.01WaterRequired' => 'craft.error.waterLessonRequired',
        'q4.01SupplyReserved' => 'craft.error.waterLessonRecipe',
        'recyclingSampleMustBeSorted' => 'craft.error.sampleUnsorted',
        'q1.02UnpickFirst' => 'craft.error.unpickFirst',
        'q1.02PrepareThreadFirst' => 'craft.error.prepareThreadFirst',
        'q1.02SupplyReserved' => 'craft.error.supplyReserved',
        'craftAlreadyIrreversible' => 'craft.error.alreadyIrreversible',
        'craftOperationIncompatible' => 'craft.error.incompatible',
        'rustMaintenanceLocked' ||
        'maintenanceLocked' => 'craft.error.maintenanceLocked',
        'maintenanceProfileUnknown' => 'craft.error.profileUnknown',
        'maintenanceTargetInvalid' => 'craft.error.targetInvalid',
        'maintenanceAuxiliaryRequired' => 'craft.error.auxiliaryRequired',
        'maintenanceWaterRequired' => 'craft.error.waterRequired',
        'maintenanceInputUnavailable' ||
        'rustMaintenanceInputUnavailable' => 'craft.error.inputUnavailable',
        'maintenanceInputsChanged' ||
        'rustMaintenanceInputsChanged' => 'craft.error.inputsChanged',
        'maintenanceOperationChanged' ||
        'maintenanceOperationIncomplete' => 'craft.error.operationChanged',
        'rustMaintenanceTargetInvalid' => 'craft.error.rustTargetInvalid',
        'rustMaintenanceClothRequired' => 'craft.error.rustClothRequired',
        'rustMaintenanceFilteredWaterRequired' =>
          'craft.error.rustWaterRequired',
        _ => null,
      };
      return strings.text(key ?? 'craft.error.generic');
    }
    if (error is StreetScrapConcurrentWrite ||
        error is StreetScrapStaleRevision) {
      return strings.text('craft.error.concurrentWrite');
    }
    return strings.text('craft.error.notSubmitted');
  }

  Future<void> _showRecipes({
    VoidCallback? onCraftSettled,
    VoidCallback? onOpenOtherGrid,
  }) async {
    final openOtherGrid =
        onOpenOtherGrid ??
        () {
          if (!mounted) return;
          setState(() {
            _activeGrid = _activeGrid == 'backpack' ? 'board' : 'backpack';
            _keyboardX = 0;
            _keyboardY = 0;
          });
        };
    final chapter = _chapter;
    final allRecipes = widget.recipeCatalog.recipes.values.toList();
    final phases = allRecipes.map((recipe) => recipe.phase).toSet().toList()
      ..sort();
    final pageController = PageController();
    int? selectedPhase;
    var craftWasRequested = false;
    Future<dynamic>? recipeIndexDismissal;
    var currentPage = 0;
    try {
      final requestedRecipe = await showModalBottomSheet<StreetScrapRecipe>(
        context: context,
        isScrollControlled: true,
        enableDrag: false,
        builder: (sheetContext) {
          recipeIndexDismissal = ModalRoute.of(sheetContext)?.completed;
          return SafeArea(
            child: FractionallySizedBox(
              heightFactor: 0.96,
              child: StatefulBuilder(
                builder: (context, setSheetState) {
                  final strings = StreetScrapLocalizations.of(context);
                  final phaseRecipes = selectedPhase == null
                      ? allRecipes
                      : allRecipes
                            .where((recipe) => recipe.phase == selectedPhase)
                            .toList();
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.auto_awesome_mosaic_rounded),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                strings.text('recipeIndex.title'),
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            IconButton(
                              key: const Key('street-scrap-close-recipes'),
                              tooltip: MaterialLocalizations.of(
                                context,
                              ).closeButtonTooltip,
                              onPressed: () => Navigator.of(sheetContext).pop(),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            chapter == null
                                ? strings.text('recipeIndex.invalidProgress')
                                : strings.text(
                                    'recipeIndex.phaseProgress',
                                    arguments: {'phase': '$chapter'},
                                  ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Tooltip(
                              message: strings.text('recipeIndex.allPhases'),
                              child: ChoiceChip(
                                key: const Key('street-scrap-recipe-phase-all'),
                                label: Text(
                                  strings.text('recipeIndex.allShort'),
                                ),
                                selected: selectedPhase == null,
                                onSelected: (_) {
                                  setSheetState(() {
                                    selectedPhase = null;
                                    currentPage = 0;
                                  });
                                  pageController.jumpToPage(0);
                                },
                              ),
                            ),
                            for (final phase in phases)
                              Tooltip(
                                message: strings.text(
                                  'recipeIndex.phaseFilter',
                                  arguments: {'phase': '$phase'},
                                ),
                                child: ChoiceChip(
                                  key: Key('street-scrap-recipe-phase-$phase'),
                                  label: Text('$phase'),
                                  selected: selectedPhase == phase,
                                  onSelected: (_) {
                                    setSheetState(() {
                                      selectedPhase = phase;
                                      currentPage = 0;
                                    });
                                    pageController.jumpToPage(0);
                                  },
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final cardsPerPage = constraints.maxWidth >= 560
                                  ? 2
                                  : 1;
                              final pageCount = phaseRecipes.isEmpty
                                  ? 0
                                  : (phaseRecipes.length + cardsPerPage - 1) ~/
                                        cardsPerPage;
                              if (pageCount == 0) {
                                return Center(
                                  child: Icon(
                                    Icons.menu_book_rounded,
                                    size: 72,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outlineVariant,
                                  ),
                                );
                              }
                              return PageView.builder(
                                key: const Key('street-scrap-recipe-pages'),
                                controller: pageController,
                                itemCount: pageCount,
                                onPageChanged: (page) =>
                                    setSheetState(() => currentPage = page),
                                itemBuilder: (context, page) {
                                  final start = page * cardsPerPage;
                                  final end = (start + cardsPerPage).clamp(
                                    0,
                                    phaseRecipes.length,
                                  );
                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      for (
                                        var index = start;
                                        index < end;
                                        index++
                                      )
                                        Expanded(
                                          child: Padding(
                                            padding: EdgeInsets.only(
                                              right: index < end - 1 ? 8 : 0,
                                            ),
                                            child: _recipeIndexCard(
                                              phaseRecipes[index],
                                              chapter: chapter,
                                              onCraftSettled: onCraftSettled,
                                              onOpenOtherGrid: openOtherGrid,
                                              onCraftRequested: (recipe) {
                                                craftWasRequested = true;
                                                Navigator.of(
                                                  sheetContext,
                                                ).pop(recipe);
                                              },
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final cardsPerPage = constraints.maxWidth >= 560
                                ? 2
                                : 1;
                            final pageCount = phaseRecipes.isEmpty
                                ? 0
                                : (phaseRecipes.length + cardsPerPage - 1) ~/
                                      cardsPerPage;
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  key: const Key(
                                    'street-scrap-recipe-page-previous',
                                  ),
                                  tooltip: strings.text(
                                    'recipeIndex.previousPage',
                                  ),
                                  onPressed: currentPage > 0
                                      ? () => pageController.previousPage(
                                          duration: const Duration(
                                            milliseconds: 180,
                                          ),
                                          curve: Curves.easeOut,
                                        )
                                      : null,
                                  constraints: const BoxConstraints.tightFor(
                                    width: 36,
                                    height: 40,
                                  ),
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.chevron_left_rounded),
                                ),
                                Semantics(
                                  label: strings.text(
                                    'recipeIndex.page',
                                    arguments: {
                                      'current':
                                          '${pageCount == 0 ? 0 : currentPage + 1}',
                                      'total': '$pageCount',
                                    },
                                  ),
                                  child: ExcludeSemantics(
                                    child: Text(
                                      '${pageCount == 0 ? 0 : currentPage + 1} / $pageCount',
                                    ),
                                  ),
                                ),
                                IconButton(
                                  key: const Key(
                                    'street-scrap-recipe-page-next',
                                  ),
                                  tooltip: strings.text('recipeIndex.nextPage'),
                                  onPressed: currentPage + 1 < pageCount
                                      ? () => pageController.nextPage(
                                          duration: const Duration(
                                            milliseconds: 180,
                                          ),
                                          curve: Curves.easeOut,
                                        )
                                      : null,
                                  constraints: const BoxConstraints.tightFor(
                                    width: 40,
                                    height: 40,
                                  ),
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.chevron_right_rounded),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      );
      await recipeIndexDismissal;
      if (craftWasRequested && requestedRecipe == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              StreetScrapLocalizations.of(
                context,
              ).text('craft.errorLaunchFailed'),
            ),
          ),
        );
      }
      if (requestedRecipe != null && mounted) {
        await _craftRecipe(
          requestedRecipe,
          onSettled: onCraftSettled,
          onOpenOtherGrid: openOtherGrid,
        );
      }
    } finally {
      pageController.dispose();
    }
  }

  Widget _recipeItemSprite(
    StreetScrapRecipeInput item, {
    required String source,
    String? contentItemId,
    double size = 60,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          StreetScrapItemSprite(
            itemId: item.itemId,
            source: source,
            contentItemId: contentItemId,
            woodBoardSpriteBytes: widget.woodBoardSpriteBytes,
            threadSpoolSpriteBytes: widget.threadSpoolSpriteBytes,
            materialAtlasBytes: widget.materialAtlasBytes,
            toolAtlasBytes: widget.toolAtlasBytes,
            materialPackArtBytes: widget.materialPackArtBytes,
            mineralPackSpriteBytes: widget.mineralPackArtBytes,
            woodChipBundleSpriteBytes: widget.woodChipBundleArtBytes,
            size: 56,
            visualScale: 1.1,
          ),
          if (item.quantity > 1)
            Positioned(
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFE8D8B7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  child: Text(
                    '×${item.quantity}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF30281E),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _recipeFlowPreview(
    StreetScrapRecipe recipe,
    StreetScrapLocalizations strings, {
    double spriteSize = 60,
  }) {
    final semanticInputs = strings.text(
      'recipe.requirements',
      arguments: {
        'items': recipe.inputGroups
            .map(
              (group) => group
                  .map((item) {
                    final contentItemId = _recipeContainerContentItemId(
                      recipe,
                      item.itemId,
                    );
                    final itemName = contentItemId == null
                        ? strings.itemName(item.itemId)
                        : strings.text(
                            'recipe.inputContainerContents',
                            arguments: {
                              'container': strings.itemName(item.itemId),
                              'content': strings.itemName(contentItemId),
                            },
                          );
                    return strings.text(
                      'recipe.itemQuantity',
                      arguments: {
                        'item': itemName,
                        'count': '${item.quantity}',
                      },
                    );
                  })
                  .join(strings.text('recipe.inputSeparator')),
            )
            .join(strings.text('recipe.alternativeSeparator')),
      },
    );
    var outputs = recipe.outputs;
    if (outputs.isEmpty) {
      final containerTransforms = recipe.stateEffect?['containers'];
      if (containerTransforms is List) {
        outputs = [
          for (final transform in containerTransforms.whereType<Map>())
            if (transform['containerItemId'] is String)
              StreetScrapRecipeInput(
                itemId: transform['containerItemId']! as String,
                quantity: 1,
              ),
        ];
      }
    }
    if (outputs.isEmpty) {
      final transformed = recipe.stateEffect?['toItemId'];
      final retained = recipe.retainedInputIds.firstOrNull;
      final outputId = transformed is String ? transformed : retained;
      if (outputId != null) {
        outputs = [StreetScrapRecipeInput(itemId: outputId, quantity: 1)];
      }
    }
    final firstGroup = recipe.inputGroups.firstOrNull ?? const [];
    return Semantics(
      label: semanticInputs,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < firstGroup.length; index++) ...[
              _recipeItemSprite(
                firstGroup[index],
                source: 'street-find',
                contentItemId: _recipeContainerContentItemId(
                  recipe,
                  firstGroup[index].itemId,
                ),
                size: spriteSize,
              ),
              if (index < firstGroup.length - 1)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 2),
                  child: Icon(Icons.add_rounded, size: 16),
                ),
            ],
            if (recipe.inputGroups.length > 1)
              Tooltip(
                message: semanticInputs,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.more_horiz_rounded, size: 18),
                ),
              ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.arrow_forward_rounded, size: 20),
            ),
            for (var index = 0; index < outputs.length; index++) ...[
              _recipeItemSprite(
                outputs[index],
                source: 'crafted',
                contentItemId: _recipeContainerContentItemId(
                  recipe,
                  outputs[index].itemId,
                  outcome: 'successContentItemId',
                ),
                size: spriteSize,
              ),
              if (index < outputs.length - 1)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 2),
                  child: Icon(Icons.add_rounded, size: 16),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _recipeIndexCard(
    StreetScrapRecipe recipe, {
    required int? chapter,
    VoidCallback? onCraftSettled,
    VoidCallback? onOpenOtherGrid,
    ValueChanged<StreetScrapRecipe>? onCraftRequested,
  }) {
    final strings = StreetScrapLocalizations.of(context);
    final questLockReasonKey = _questLockReasonKey(recipe);
    final locked =
        chapter == null ||
        recipe.phase > chapter ||
        !_stationUnlocked(recipe) ||
        questLockReasonKey != null;
    if (locked) {
      return Card(
        child: ListTile(
          key: Key('street-scrap-recipe-${recipe.id}'),
          leading: SizedBox(
            width: 54,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (recipe.outputs.isNotEmpty)
                  StreetScrapItemSprite(
                    itemId: recipe.outputs.first.itemId,
                    source: 'crafted',
                    materialAtlasBytes: widget.materialAtlasBytes,
                    toolAtlasBytes: widget.toolAtlasBytes,
                    materialPackArtBytes: widget.materialPackArtBytes,
                    size: 48,
                  ),
                const Positioned(
                  right: 0,
                  bottom: 0,
                  child: Icon(Icons.lock_rounded, size: 18),
                ),
              ],
            ),
          ),
          title: Text(_recipeDisplayName(strings, recipe)),
          subtitle: Text(
            chapter == null
                ? strings.text('recipeIndex.invalidLock')
                : questLockReasonKey != null
                ? strings.text(
                    'recipeIndex.questLock',
                    arguments: {'quest': strings.text(questLockReasonKey)},
                  )
                : !_stationUnlocked(recipe)
                ? strings.text('recipeIndex.stationLock')
                : strings.text(
                    'recipeIndex.phaseLock',
                    arguments: {
                      'required': '${recipe.phase}',
                      'current': '$chapter',
                    },
                  ),
          ),
        ),
      );
    }
    return Card(
      child: InkWell(
        key: Key('street-scrap-recipe-${recipe.id}'),
        onTap: () async {
          final requestCraft = await _showRecipeDetails(
            recipe,
            onCraftSettled: onCraftSettled,
            onOpenOtherGrid: onOpenOtherGrid,
          );
          if (requestCraft == true) onCraftRequested?.call(recipe);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _recipeDisplayName(strings, recipe),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const Icon(Icons.open_in_new_rounded, size: 18),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                strings.text(
                  'recipe.phaseDuration',
                  arguments: {
                    'phase': '${recipe.phase}',
                    'station': strings.stationName(recipe.station),
                    'seconds': '${recipe.durationSeconds}',
                  },
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              _recipeFlowPreview(recipe, strings),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _showRecipeDetails(
    StreetScrapRecipe recipe, {
    VoidCallback? onCraftSettled,
    VoidCallback? onOpenOtherGrid,
  }) async {
    final strings = StreetScrapLocalizations.of(context);
    Future<dynamic>? detailsDismissal;
    final requestCraft = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        detailsDismissal = ModalRoute.of(sheetContext)?.completed;
        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.82,
            builder: (context, controller) => ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _recipeDisplayName(strings, recipe),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Chip(
                    avatar: const Icon(Icons.schedule_rounded, size: 18),
                    label: Text(
                      strings.text(
                        'recipe.phaseDuration',
                        arguments: {
                          'phase': '${recipe.phase}',
                          'station': strings.stationName(recipe.station),
                          'seconds': '${recipe.durationSeconds}',
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: _recipeFlowPreview(recipe, strings, spriteSize: 88),
                ),
                ExpansionTile(
                  key: const Key('street-scrap-recipe-detail-info'),
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  leading: const Icon(Icons.info_outline_rounded),
                  title: Text(strings.text('recipe.detailInfo')),
                  children: [
                    Text(
                      strings.text(
                        'recipe.instructions',
                        arguments: {
                          'instructions': strings.operationInstructions(
                            recipe.instructions,
                          ),
                        },
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      strings.text(
                        'recipe.requirements',
                        arguments: {
                          'items': recipe.inputGroups
                              .map(
                                (group) => group
                                    .map(
                                      (item) => strings.text(
                                        'recipe.itemQuantity',
                                        arguments: {
                                          'item': strings.itemName(item.itemId),
                                          'count': '${item.quantity}',
                                        },
                                      ),
                                    )
                                    .join(
                                      strings.text('recipe.inputSeparator'),
                                    ),
                              )
                              .join(
                                strings.text('recipe.alternativeSeparator'),
                              ),
                        },
                      ),
                    ),
                    if (recipe.reusableTools.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        strings.text(
                          'recipe.retainedTools',
                          arguments: {
                            'tools': recipe.reusableTools
                                .map(strings.itemName)
                                .join(strings.text('recipe.itemSeparator')),
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(_recipeSuccessSummary(recipe, strings)),
                    const SizedBox(height: 6),
                    Text(
                      strings.text(
                        'recipe.qualityRule',
                        arguments: {
                          'mode': strings.recipeQualityMode(
                            recipe.quality.mode,
                          ),
                          'loss': '${recipe.quality.loss}',
                        },
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      strings.text(
                        'recipe.failure',
                        arguments: {
                          'outcome': strings.recipeFailureOutcome(
                            recipe.failureOutcome,
                          ),
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: widget.session.isReadOnly
                        ? null
                        : () => Navigator.of(sheetContext).pop(true),
                    icon: const Icon(Icons.construction_outlined),
                    label: Text(strings.text('recipe.selectAndCraft')),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    await detailsDismissal;
    return requestCraft;
  }

  Future<void> _placeAt(int x, int y) async {
    final selected = _selectedInstanceId;
    if (selected == null) return;
    await _moveInstanceTo(selected, _activeGrid, x, y);
  }

  Future<void> _moveInstanceTo(
    String selected,
    String targetGrid,
    int x,
    int y,
  ) async {
    final before = _inventory;
    final previousPlacement = before.placements[selected];
    final previousStorageId = before.storage.entries
        .where((entry) => entry.value.contains(selected))
        .map((entry) => entry.key)
        .firstOrNull;
    if (previousPlacement?.gridId == targetGrid &&
        previousPlacement?.x == x &&
        previousPlacement?.y == y) {
      return;
    }
    final moved = await _commit(
      (inventory) => inventory.move(selected, targetGrid, x, y),
    );
    if (!moved || !mounted) return;
    setState(() {
      _lastMoveUndo = _StreetScrapMoveUndo(
        instanceId: selected,
        previousPlacement: previousPlacement,
        previousStorageId: previousStorageId,
        expectedRevision: widget.session.snapshot.revision,
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(StreetScrapLocalizations.of(context).text('board.moved')),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: StreetScrapLocalizations.of(context).text('board.undoMove'),
          onPressed: () => unawaited(_undoLastMove()),
        ),
      ),
    );
  }

  Future<void> _undoLastMove() async {
    final undo = _lastMoveUndo;
    if (undo == null ||
        undo.expectedRevision != widget.session.snapshot.revision ||
        _saving ||
        widget.session.isReadOnly) {
      return;
    }
    await _commit((inventory) {
      var restored = undo.previousPlacement == null
          ? inventory.unplace(undo.instanceId)
          : inventory.move(
              undo.instanceId,
              undo.previousPlacement!.gridId,
              undo.previousPlacement!.x,
              undo.previousPlacement!.y,
            );
      if (undo.previousStorageId != null) {
        restored = restored.store(undo.instanceId, undo.previousStorageId!);
      }
      return restored;
    });
  }

  Future<void> _rotateSelected() async {
    final selected = _selectedInstanceId;
    if (selected == null) return;
    await _commit((inventory) => inventory.rotate(selected));
  }

  Future<void> _packSelectedSharedMeal() async {
    final mealId = _selectedInstanceId;
    if (mealId == null || _saving || widget.session.isReadOnly) return;
    final strings = StreetScrapLocalizations.of(context);
    final inventory = _inventory;
    final meal = inventory.objects[mealId];
    if (meal == null ||
        meal.itemId != 'meal.shared' ||
        inventory.placements[mealId]?.gridId != 'backpack') {
      return;
    }
    final boxes = inventory.objects.values
        .where(
          (item) =>
              streetScrapMealContainerItemIds.contains(item.itemId) &&
              item.containerState['contentItemId'] == null &&
              item.containerState['cleanliness'] == 'clean' &&
              inventory.placements[item.instanceId]?.gridId == 'backpack' &&
              !_lockedCraftIds.contains(item.instanceId),
        )
        .toList(growable: false);
    if (boxes.isEmpty) return;
    final selectedBoxId = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(strings.text('mealPack.chooseContainer')),
        children: [
          for (var index = 0; index < boxes.length; index++)
            SimpleDialogOption(
              key: Key('street-scrap-meal-box-${boxes[index].instanceId}'),
              onPressed: () => Navigator.pop(context, boxes[index].instanceId),
              child: Text(
                strings.text(
                  'mealPack.containerOption',
                  arguments: {
                    'name': strings.itemName(boxes[index].itemId),
                    'number': '${index + 1}',
                    'quality': strings.itemQuality(boxes[index].quality),
                  },
                ),
              ),
            ),
        ],
      ),
    );
    if (selectedBoxId == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.text('mealPack.confirmTitle')),
        content: Text(
          strings.text(
            'mealPack.confirmBody',
            arguments: {
              'meal': strings.itemName(meal.itemId),
              'container': strings.itemName(
                inventory.objects[selectedBoxId]!.itemId,
              ),
              'quality': strings.itemQuality(meal.quality),
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.text('packing.cancel')),
          ),
          FilledButton(
            key: const Key('street-scrap-confirm-meal-pack'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.text('mealPack.confirmAction')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await packStreetScrapSharedMealIntoContainer(
        session: widget.session,
        commandId: 'meal-pack-${DateTime.now().microsecondsSinceEpoch}',
        expectedRevision: widget.session.snapshot.revision,
        catalog: widget.catalog,
        grids: _grids,
        mealInstanceId: mealId,
        containerInstanceId: selectedBoxId,
      );
      unawaited(_playSound(StreetScrapAudioCue.tap));
      if (mounted) setState(() => _selectedInstanceId = null);
    } on Object catch (error) {
      if (mounted) setState(() => _actionError = _friendlyError(error));
    }
  }

  Future<void> _packSelected(StreetScrapPackingRule rule) async {
    final selectedId = _selectedInstanceId;
    if (selectedId == null) return;
    final inventory = _inventory;
    final candidates = inventory.objects.values
        .where(
          (item) =>
              item.itemId == rule.inputItemId &&
              item.containerContents.isEmpty &&
              !_lockedCraftIds.contains(item.instanceId),
        )
        .toList(growable: false);
    if (!candidates.any((item) => item.instanceId == selectedId) ||
        candidates.length < rule.count) {
      return;
    }
    final selected = <StreetScrapObject>[
      candidates.firstWhere((item) => item.instanceId == selectedId),
      ...candidates
          .where((item) => item.instanceId != selectedId)
          .take(rule.count - 1),
    ];
    final strings = StreetScrapLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.text('packing.title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.text(
                'packing.contents',
                arguments: {
                  'count': '${selected.length}',
                  'input': strings.itemName(rule.inputItemId),
                  'output': strings.itemName(rule.outputItemId),
                },
              ),
            ),
            const SizedBox(height: 8),
            for (final item in selected)
              Text(
                strings.text(
                  'packing.itemDetails',
                  arguments: {
                    'location': _ownerDescription(strings, inventory, item),
                    'source': strings.itemSource(item.source),
                    'quality': strings.itemQuality(item.quality),
                  },
                ),
              ),
            const SizedBox(height: 8),
            Text(strings.text('packing.identity')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.text('packing.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.text('packing.confirm')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final instanceId = 'bundle-${DateTime.now().microsecondsSinceEpoch}';
    await _commit(
      (current) => current.pack(
        ruleId: rule.id,
        inputInstanceIds: selected.map((item) => item.instanceId).toList(),
        source: 'manual-pack',
        containerInstanceId: instanceId,
      ),
    );
  }

  Future<void> _unpackSelected() async {
    final selectedId = _selectedInstanceId;
    if (selectedId == null) return;
    await _commit(
      (inventory) => inventory.unpack(
        containerInstanceId: selectedId,
        gridId: _activeGrid,
      ),
    );
  }

  String _recipeSuccessSummary(
    StreetScrapRecipe recipe,
    StreetScrapLocalizations strings,
  ) {
    final effect = recipe.stateEffect;
    final key = streetScrapRecipeSuccessMessageKey(
      station: recipe.station,
      stateEffectType: effect?['type'] as String?,
      hasOutputs: recipe.outputs.isNotEmpty,
    );
    if (key == 'recipe.successWater') {
      return strings.text(
        key,
        arguments: {
          'from': strings.itemName('${effect!['fromContentItemId']}'),
          'to': strings.itemName('${effect['toContentItemId']}'),
        },
      );
    }
    if (key == 'recipe.successWithContainers' ||
        key == 'recipe.successOutputs') {
      final outputs = recipe.outputs
          .map(
            (item) => strings.text(
              'recipe.itemQuantity',
              arguments: {
                'item': strings.itemName(item.itemId),
                'count': '${item.quantity}',
              },
            ),
          )
          .join(strings.text('recipe.itemSeparator'));
      return strings.text(key, arguments: {'outputs': outputs});
    }
    if (key == 'recipe.successPack') {
      return strings.text(
        key,
        arguments: {
          'inputs': (effect!['retainedInputIds'] as List)
              .map((id) => strings.itemName('$id'))
              .join(strings.text('recipe.itemSeparator')),
          'output': strings.itemName('${effect['toItemId']}'),
        },
      );
    }
    return strings.text(key);
  }

  @override
  Widget build(BuildContext context) {
    try {
      final page = _buildPage(context);
      if (!_reliefInitializationScheduled) {
        _reliefInitializationScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_initializeReliefClock());
        });
      }
      return page;
    } on FormatException {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            StreetScrapLocalizations.of(
              context,
            ).text('game.error.malformedSave'),
          ),
        ),
      );
    }
  }

  Widget _buildPage(BuildContext context) {
    final strings = StreetScrapLocalizations.of(context);
    final inventory = _inventory;
    final grid = _grids[_activeGrid]!;
    final onGrid = inventory.placements.values
        .where((placement) => placement.gridId == grid.id)
        .toList(growable: false);
    final storedIds = inventory.storage.values.expand((ids) => ids).toSet();
    final unplaced = inventory.objects.values
        .where(
          (item) =>
              !inventory.placements.containsKey(item.instanceId) &&
              !storedIds.contains(item.instanceId),
        )
        .toList(growable: false);
    final selected = _selectedInstanceId == null
        ? null
        : inventory.objects[_selectedInstanceId];
    final selectedMaintenances = selected == null
        ? const <StreetScrapTraitMaintenanceProfile>[]
        : StreetScrapMaintenance.profilesForTarget(selected);
    final activeOperation = widget.session.snapshot.state['craftOperation'];
    final rawCollection = widget.session.snapshot.state['collectionItemIds'];
    if (rawCollection != null &&
        (rawCollection is! List || rawCollection.any((id) => id is! String))) {
      throw const FormatException('收藏簿存檔格式錯誤。');
    }
    final collection = rawCollection is List
        ? rawCollection.cast<String>().toSet()
        : <String>{};
    final collectionItemIds = widget.catalog.footprints.keys.toList()..sort();
    final recipes = widget.recipeCatalog.recipes.values.toList()
      ..sort((left, right) => left.id.compareTo(right.id));
    final chapter = _chapter ?? 0;
    final rawTutorialTasks = widget.session.snapshot.state['tutorialTasks'];
    final woodworkingUnlocked =
        chapter >= 3 &&
        rawTutorialTasks is Map &&
        rawTutorialTasks['q2.03'] == true;
    Widget buildWoodworkingPanel() => StreetScrapWoodworkingPanel(
      session: widget.session,
      catalog: widget.catalog,
      repairCatalog: widget.repairCatalog,
      maxStamina: widget.maxStamina,
      orderCatalog: widget.orderCatalog,
      onOpenRecipes: _showRecipes,
      onChanged: () {
        if (mounted) setState(() {});
      },
      onSound: (cue) => unawaited(_playSound(cue)),
      protagonistArt: widget.protagonistArt,
    );
    Widget buildPendingOperationCard() {
      if (activeOperation == null) return const SizedBox.shrink();
      final pendingMap = activeOperation is Map ? activeOperation : null;
      final answers = pendingMap?['answers'];
      final completedSteps = answers is List ? answers.length : 0;
      return Card(
        key: const Key('street-scrap-workbench-pending-operation'),
        child: ListTile(
          leading: const Icon(Icons.pending_actions_rounded),
          title: Text(
            pendingMap?['recipeId'] == StreetScrapMaintenance.operationRecipeId
                ? strings.text('board.pendingMaintenance')
                : strings.text('board.pendingCraft'),
          ),
          subtitle: Text(
            strings.text(
              'board.pendingSteps',
              arguments: {'done': '$completedSteps'},
            ),
          ),
          trailing: IconButton.filledTonal(
            tooltip: strings.text('board.resumeCraft'),
            onPressed: _saving || widget.session.isReadOnly
                ? null
                : _continueCraftOperation,
            icon: const Icon(Icons.play_arrow_rounded),
          ),
        ),
      );
    }

    bool recipeIsKnown(StreetScrapRecipe recipe) =>
        recipe.phase <= chapter &&
        _stationUnlocked(recipe) &&
        _questLockReasonKey(recipe) == null;
    final knownRecipeCount = recipes.where(recipeIsKnown).length;
    final gameSettings = _gameSettings;
    final currentMedia = MediaQuery.of(context);
    final effectiveTextScale =
        (currentMedia.textScaler.scale(1) * gameSettings.textScale)
            .clamp(1.0, 4.0)
            .toDouble();
    final baseTheme = Theme.of(context);
    final warmDarkColorScheme = baseTheme.colorScheme.copyWith(
      primary: const Color(0xff86c7a6),
      onPrimary: const Color(0xff14251c),
      primaryContainer: const Color(0xff334d3d),
      onPrimaryContainer: const Color(0xffe2f0e2),
      secondary: const Color(0xffd4aa72),
      onSecondary: const Color(0xff302312),
      secondaryContainer: const Color(0xff59452d),
      onSecondaryContainer: const Color(0xfff2e0c1),
      tertiary: const Color(0xff8bb3ad),
      onTertiary: const Color(0xff102522),
      tertiaryContainer: const Color(0xff344e49),
      onTertiaryContainer: const Color(0xffdcebe5),
      surface: const Color(0xff171c19),
      onSurface: const Color(0xffe8e4d9),
      onSurfaceVariant: const Color(0xffc3c5b8),
      surfaceContainerLowest: const Color(0xff111512),
      surfaceContainerLow: const Color(0xff1b211d),
      surfaceContainer: const Color(0xff222a24),
      surfaceContainerHigh: const Color(0xff2a342c),
      surfaceContainerHighest: const Color(0xff354037),
      outline: const Color(0xff879184),
      outlineVariant: const Color(0xff515c51),
    );
    final gameColorScheme = baseTheme.colorScheme.brightness == Brightness.dark
        ? warmDarkColorScheme
        : baseTheme.colorScheme;
    final lockedIds = _lockedCraftIds;
    final invalidReservation = lockedIds.contains(
      '__invalid_craft_reservation__',
    );

    return Theme(
      data: baseTheme.copyWith(
        colorScheme: gameColorScheme,
        scaffoldBackgroundColor: gameColorScheme.surface,
      ),
      child: MediaQuery(
        data: currentMedia.copyWith(
          textScaler: TextScaler.linear(effectiveTextScale),
          disableAnimations:
              currentMedia.disableAnimations || gameSettings.reduceMotion,
        ),
        child: KeyedSubtree(
          key: const Key('street-scrap-inventory-root'),
          child: ColoredBox(
            color: gameColorScheme.surface,
            child: Stack(
              children: [
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Tooltip(
                                  message: strings.text(
                                    'return.chapter',
                                    arguments: {'phase': '${_chapter ?? 0}'},
                                  ),
                                  child: Semantics(
                                    label: strings.text(
                                      'return.chapter',
                                      arguments: {'phase': '${_chapter ?? 0}'},
                                    ),
                                    child: _StreetScrapHudChip(
                                      icon: Icons.flag_outlined,
                                      value: effectiveTextScale >= 2.5
                                          ? ''
                                          : '${_chapter ?? 0}',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Builder(
                                  builder: (context) {
                                    final stamina =
                                        (widget
                                                .session
                                                .snapshot
                                                .state['stamina']
                                            as int?) ??
                                        widget.maxStamina;
                                    final label = strings.text(
                                      'return.stamina',
                                      arguments: {
                                        'current': '$stamina',
                                        'maximum': '${widget.maxStamina}',
                                      },
                                    );
                                    return Tooltip(
                                      message: label,
                                      child: Semantics(
                                        label: label,
                                        child: _StreetScrapHudChip(
                                          icon: Icons.bolt_rounded,
                                          value: effectiveTextScale >= 2.5
                                              ? ''
                                              : '$stamina',
                                          progress: widget.maxStamina <= 0
                                              ? 0
                                              : (stamina / widget.maxStamina)
                                                    .clamp(0.0, 1.0),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            key: const Key('street-scrap-open-collection'),
                            tooltip: strings.text('collection.title'),
                            onPressed: () => _showCollectionBook(
                              collectionItemIds,
                              collection,
                            ),
                            icon: const Icon(
                              Icons.collections_bookmark_outlined,
                            ),
                          ),
                          IconButton(
                            key: const Key('street-scrap-open-settings'),
                            tooltip: strings.text('settings.title'),
                            onPressed: _showGameSettings,
                            icon: const Icon(Icons.tune_rounded),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _activeSection == 0
                          ? _buildVisualMaterialBoard(context)
                          : _activeSection == 3 && !woodworkingUnlocked
                          ? ListView(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                              children: [
                                buildPendingOperationCard(),
                                buildWoodworkingPanel(),
                                if (widget.renewableSupplies
                                    case final renewableSupplies?) ...[
                                  const SizedBox(height: 12),
                                  StreetScrapRenewableSuppliesPanel(
                                    session: widget.session,
                                    catalog: renewableSupplies,
                                    inventoryCatalog: widget.catalog,
                                    grids: _grids,
                                    maxStamina: widget.maxStamina,
                                    onOrganize: () =>
                                        unawaited(_showMaterialWorkspace()),
                                    onChanged: () {
                                      if (mounted) setState(() {});
                                    },
                                  ),
                                ],
                              ],
                            )
                          : KeyedSubtree(
                              key: const Key('street-scrap-inventory-scroll'),
                              child: ListView(
                                key: _inventoryScrollViewportKey,
                                controller: _inventoryScrollController,
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  4,
                                  12,
                                  12,
                                ),
                                children: [
                                  if (_activeSection == 3)
                                    buildPendingOperationCard(),
                                  if (_activeSection == 3)
                                    buildWoodworkingPanel(),
                                  if (_activeSection == 3 &&
                                      woodworkingUnlocked) ...[
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: FilledButton.tonalIcon(
                                        key: const Key(
                                          'street-scrap-open-material-workspace',
                                        ),
                                        onPressed: _showMaterialWorkspace,
                                        icon: const Icon(
                                          Icons.inventory_2_outlined,
                                        ),
                                        label: Text(
                                          strings.text(
                                            'board.materialWorkspaceShort',
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (widget.renewableSupplies
                                        case final renewableSupplies?)
                                      StreetScrapRenewableSuppliesPanel(
                                        session: widget.session,
                                        catalog: renewableSupplies,
                                        inventoryCatalog: widget.catalog,
                                        grids: _grids,
                                        maxStamina: widget.maxStamina,
                                        onOrganize: () =>
                                            unawaited(_showMaterialWorkspace()),
                                        onChanged: () {
                                          if (mounted) setState(() {});
                                        },
                                      ),
                                    Card(
                                      child: Column(
                                        children: [
                                          ListTile(
                                            key: const Key(
                                              'street-scrap-collection-book',
                                            ),
                                            leading: const Icon(
                                              Icons
                                                  .collections_bookmark_outlined,
                                            ),
                                            title: Text(
                                              strings.text('collection.title'),
                                            ),
                                            subtitle: Text(
                                              strings.text(
                                                'collection.count',
                                                arguments: {
                                                  'owned':
                                                      '${collection.intersection(collectionItemIds.toSet()).length}',
                                                  'total':
                                                      '${collectionItemIds.length}',
                                                },
                                              ),
                                            ),
                                            trailing: const Icon(
                                              Icons.chevron_right,
                                            ),
                                            onTap: () => _showCollectionBook(
                                              collectionItemIds,
                                              collection,
                                            ),
                                          ),
                                          ListTile(
                                            key: const Key(
                                              'street-scrap-known-recipes',
                                            ),
                                            leading: const Icon(
                                              Icons.menu_book_outlined,
                                            ),
                                            title: Text(
                                              strings.text('recipes.known'),
                                            ),
                                            subtitle: Text(
                                              strings.text(
                                                'recipes.unlockedCount',
                                                arguments: {
                                                  'known': '$knownRecipeCount',
                                                  'total': '${recipes.length}',
                                                },
                                              ),
                                            ),
                                            trailing: const Icon(
                                              Icons.chevron_right,
                                            ),
                                            onTap: () => _showKnownRecipes(
                                              recipes,
                                              recipeIsKnown,
                                              knownRecipeCount,
                                            ),
                                          ),
                                          ListTile(
                                            key: const Key(
                                              'street-scrap-game-settings',
                                            ),
                                            leading: const Icon(
                                              Icons.accessibility_new_outlined,
                                            ),
                                            title: Text(
                                              strings.text('settings.title'),
                                            ),
                                            subtitle: Text(
                                              '${strings.text('settings.scaleSummary', arguments: {'percent': '${(gameSettings.textScale * 100).round()}'})}・'
                                              '${strings.text(gameSettings.reduceMotion ? 'settings.motionReduced' : 'settings.motionNormal')}・'
                                              '${strings.text(gameSettings.assistedControls ? 'settings.controlsAssisted' : 'settings.controlsStandard')}',
                                            ),
                                            trailing: const Icon(
                                              Icons.chevron_right,
                                            ),
                                            onTap: _showGameSettings,
                                          ),
                                        ],
                                      ),
                                    ),
                                    StreetScrapReliefPanel(
                                      session: widget.session,
                                      maxStamina: widget.maxStamina,
                                      onChanged: () {
                                        if (mounted) setState(() {});
                                      },
                                    ),
                                  ],
                                  if (_activeSection == 1)
                                    StreetScrapExpeditionPanel(
                                      session: widget.session,
                                      catalog: widget.catalog,
                                      rules: widget.expeditionRules,
                                      maxStamina: widget.maxStamina,
                                      woodBoardSpriteBytes:
                                          widget.woodBoardSpriteBytes,
                                      threadSpoolSpriteBytes:
                                          widget.threadSpoolSpriteBytes,
                                      materialAtlasBytes:
                                          widget.materialAtlasBytes,
                                      toolAtlasBytes: widget.toolAtlasBytes,
                                      materialPackArtBytes:
                                          widget.materialPackArtBytes,
                                      mineralPackSpriteBytes:
                                          widget.mineralPackArtBytes,
                                      woodChipBundleSpriteBytes:
                                          widget.woodChipBundleArtBytes,
                                      protagonistArt: widget.protagonistArt,
                                      onInventoryChanged: () {
                                        if (mounted) setState(() {});
                                      },
                                      onOrganizeBackpack: () {
                                        setState(
                                          () => _activeGrid = 'backpack',
                                        );
                                        return _showMaterialWorkspace();
                                      },
                                      onSound: (cue) =>
                                          unawaited(_playSound(cue)),
                                    ),
                                  if (_activeSection == 2)
                                    StreetScrapFishingPanel(
                                      session: widget.session,
                                      rules: widget.fishingRules,
                                      defaultStamina: widget.maxStamina,
                                      catalog: widget.catalog,
                                      grids: _grids,
                                      materialAtlasBytes:
                                          widget.materialAtlasBytes,
                                      fishingSceneArtBytes:
                                          widget.fishingSceneArtBytes,
                                      assistedControls:
                                          _gameSettings.assistedControls,
                                      onChanged: () {
                                        if (mounted) setState(() {});
                                      },
                                      onSound: (cue) =>
                                          unawaited(_playSound(cue)),
                                    ),
                                  if (_activeSection == 4)
                                    if (widget.orderCatalog
                                        case final orderCatalog?)
                                      StreetScrapOrdersPanel(
                                        session: widget.session,
                                        inventoryCatalog: widget.catalog,
                                        orderCatalog: orderCatalog,
                                        woodBoardSpriteBytes:
                                            widget.woodBoardSpriteBytes,
                                        threadSpoolSpriteBytes:
                                            widget.threadSpoolSpriteBytes,
                                        materialAtlasBytes:
                                            widget.materialAtlasBytes,
                                        toolAtlasBytes: widget.toolAtlasBytes,
                                        materialPackArtBytes:
                                            widget.materialPackArtBytes,
                                        mineralPackArtBytes:
                                            widget.mineralPackArtBytes,
                                        woodChipBundleArtBytes:
                                            widget.woodChipBundleArtBytes,
                                        chapter5Installed:
                                            widget.chapter5Installed,
                                        onOpenLibrary: widget.onOpenLibrary,
                                        onChanged: () {
                                          if (mounted) setState(() {});
                                        },
                                        onSound: (cue) =>
                                            unawaited(_playSound(cue)),
                                      ),
                                  if (_activeSection == 0) ...[
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: IconButton.filledTonal(
                                        key: const Key(
                                          'street-scrap-open-material-workspace',
                                        ),
                                        tooltip: strings.text(
                                          'board.materialWorkspaceShort',
                                        ),
                                        onPressed: _showMaterialWorkspace,
                                        icon: const Icon(
                                          Icons.open_in_full_rounded,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      strings.text('board.title'),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.headlineSmall,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      strings.text(
                                        'board.saveRevision',
                                        arguments: {
                                          'revision':
                                              '${widget.session.snapshot.revision}',
                                        },
                                      ),
                                    ),
                                    if (activeOperation is Map) ...[
                                      Card(
                                        child: ListTile(
                                          leading: const Icon(
                                            Icons.pending_actions,
                                          ),
                                          title: Text(
                                            activeOperation['recipeId'] ==
                                                    StreetScrapMaintenance
                                                        .operationRecipeId
                                                ? strings.text(
                                                    'board.pendingMaintenance',
                                                  )
                                                : strings.text(
                                                    'board.pendingCraft',
                                                  ),
                                          ),
                                          subtitle: Text(
                                            strings.text(
                                              'board.pendingSteps',
                                              arguments: {
                                                'done':
                                                    '${activeOperation['answers'] is List ? (activeOperation['answers'] as List).length : 0}',
                                              },
                                            ),
                                          ),
                                          trailing: Wrap(
                                            children: [
                                              if (activeOperation['answers']
                                                      is List &&
                                                  (activeOperation['answers']
                                                          as List)
                                                      .isEmpty &&
                                                  activeOperation['operationId']
                                                      is String)
                                                IconButton(
                                                  tooltip: strings.text(
                                                    'board.cancelPending',
                                                  ),
                                                  onPressed:
                                                      _saving ||
                                                          widget
                                                              .session
                                                              .isReadOnly
                                                      ? null
                                                      : () => _cancelCraftOperation(
                                                          activeOperation['operationId']
                                                              as String,
                                                        ),
                                                  icon: const Icon(Icons.close),
                                                ),
                                              IconButton.filledTonal(
                                                tooltip: strings.text(
                                                  'board.resumeCraft',
                                                ),
                                                onPressed:
                                                    _saving ||
                                                        widget
                                                            .session
                                                            .isReadOnly
                                                    ? null
                                                    : _continueCraftOperation,
                                                icon: const Icon(
                                                  Icons.play_arrow,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: OutlinedButton.icon(
                                        onPressed: _showRecipes,
                                        icon: const Icon(
                                          Icons.menu_book_outlined,
                                        ),
                                        label: Text(
                                          strings.text(
                                            'board.viewRecipes',
                                            arguments: {
                                              'count':
                                                  '${widget.recipeCatalog.recipes.length}',
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (_materialUseIndexUnlocked) ...[
                                      const SizedBox(height: 8),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: OutlinedButton.icon(
                                          onPressed: _showMaterialUseIndex,
                                          icon: const Icon(
                                            Icons.account_tree_outlined,
                                          ),
                                          label: Text(
                                            strings.text('board.materialIndex'),
                                          ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    SegmentedButton<String>(
                                      segments: [
                                        ButtonSegment(
                                          value: 'board',
                                          label: Text(
                                            strings.text('board.workingGrid'),
                                          ),
                                        ),
                                        ButtonSegment(
                                          value: 'backpack',
                                          label: Text(
                                            strings.text('board.backpackGrid'),
                                          ),
                                        ),
                                      ],
                                      selected: {_activeGrid},
                                      onSelectionChanged:
                                          _saving || invalidReservation
                                          ? null
                                          : (value) => setState(() {
                                              _activeGrid = value.first;
                                              _keyboardX = 0;
                                              _keyboardY = 0;
                                            }),
                                    ),
                                    const SizedBox(height: 12),
                                    if (widget.session.isReadOnly)
                                      Card(
                                        child: ListTile(
                                          leading: Icon(Icons.lock_outline),
                                          title: Text(
                                            strings.text('board.readOnlyTitle'),
                                          ),
                                          subtitle: Text(
                                            strings.text('board.readOnlyBody'),
                                          ),
                                        ),
                                      ),
                                    if (_saving)
                                      const LinearProgressIndicator(),
                                    if (_actionError != null) ...[
                                      const SizedBox(height: 8),
                                      MaterialBanner(
                                        content: Text(_actionError!),
                                        actions: [
                                          TextButton(
                                            onPressed: () => setState(
                                              () => _actionError = null,
                                            ),
                                            child: Text(
                                              strings.text('common.dismiss'),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: OutlinedButton.icon(
                                        key: const Key(
                                          'street-scrap-keyboard-grid-focus',
                                        ),
                                        onPressed: _focusKeyboardGrid,
                                        icon: const Icon(
                                          Icons.keyboard_alt_outlined,
                                        ),
                                        label: Text(
                                          strings.text('board.keyboardHelp'),
                                        ),
                                      ),
                                    ),
                                    Semantics(
                                      label: strings.text(
                                        'board.keyboardSemantics',
                                      ),
                                      child: Focus(
                                        focusNode: _keyboardGridFocus,
                                        onKeyEvent: _handleGridKey,
                                        child: _StreetScrapGrid(
                                          grid: grid,
                                          objects: inventory.objects,
                                          placements: onGrid,
                                          selectedInstanceId:
                                              _selectedInstanceId,
                                          cursorX: _keyboardX,
                                          cursorY: _keyboardY,
                                          enabled:
                                              !_saving &&
                                              !widget.session.isReadOnly &&
                                              !invalidReservation,
                                          onEmptyCellTap: (x, y) {
                                            setState(() {
                                              _keyboardX = x;
                                              _keyboardY = y;
                                            });
                                            _focusKeyboardGrid();
                                            _placeAt(x, y);
                                          },
                                          onOccupiedCellTap: (id, x, y) {
                                            setState(() {
                                              _keyboardX = x;
                                              _keyboardY = y;
                                            });
                                            _focusKeyboardGrid();
                                            final selectedId =
                                                _selectedInstanceId;
                                            if (selectedId == null ||
                                                selectedId == id) {
                                              _select(id);
                                            } else {
                                              _placeAt(x, y);
                                            }
                                          },
                                          onDrop: (id, x, y) {
                                            setState(() {
                                              _keyboardX = x;
                                              _keyboardY = y;
                                            });
                                            _focusKeyboardGrid();
                                            _moveInstanceTo(id, grid.id, x, y);
                                          },
                                          woodBoardSpriteBytes:
                                              widget.woodBoardSpriteBytes,
                                          threadSpoolSpriteBytes:
                                              widget.threadSpoolSpriteBytes,
                                          materialAtlasBytes:
                                              widget.materialAtlasBytes,
                                          toolAtlasBytes: widget.toolAtlasBytes,
                                          materialPackArtBytes:
                                              widget.materialPackArtBytes,
                                          mineralPackArtBytes:
                                              widget.mineralPackArtBytes,
                                          woodChipBundleArtBytes:
                                              widget.woodChipBundleArtBytes,
                                        ),
                                      ),
                                    ),
                                    if (selected != null) ...[
                                      const SizedBox(height: 8),
                                      Card(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      '${strings.itemName(selected.itemId)}\n'
                                                      '${strings.text('board.itemMetadata', arguments: {'source': strings.itemSource(selected.source), 'quality': strings.itemQuality(selected.quality)})}',
                                                    ),
                                                    for (final entry
                                                        in StreetScrapTraitPresentation.forTraits(
                                                          selected.traits,
                                                          localizations:
                                                              strings,
                                                        ))
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              top: 6,
                                                            ),
                                                        child: Semantics(
                                                          label:
                                                              '${entry.value.name}：${entry.value.effect}',
                                                          child: Chip(
                                                            key: Key(
                                                              'street-scrap-trait-${entry.key}',
                                                            ),
                                                            avatar: const Icon(
                                                              Icons
                                                                  .auto_awesome,
                                                              size: 16,
                                                            ),
                                                            label: Text(
                                                              '${entry.value.name}・${entry.value.effect}',
                                                            ),
                                                            visualDensity:
                                                                VisualDensity
                                                                    .compact,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              IconButton.filledTonal(
                                                tooltip: strings.text(
                                                  'board.rotate',
                                                ),
                                                onPressed:
                                                    inventory.placements
                                                            .containsKey(
                                                              selected
                                                                  .instanceId,
                                                            ) &&
                                                        !_saving &&
                                                        !invalidReservation &&
                                                        !lockedIds.contains(
                                                          selected.instanceId,
                                                        ) &&
                                                        !widget
                                                            .session
                                                            .isReadOnly
                                                    ? _rotateSelected
                                                    : null,
                                                icon: const Icon(
                                                  Icons.rotate_right,
                                                ),
                                              ),
                                              IconButton(
                                                tooltip: strings.text(
                                                  'board.clearSelection',
                                                ),
                                                onPressed: () => _select(
                                                  selected.instanceId,
                                                ),
                                                icon: const Icon(Icons.close),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          if (inventory
                                                  .placements[selected
                                                      .instanceId]
                                                  ?.gridId ==
                                              _activeGrid)
                                            for (final maintenance
                                                in selectedMaintenances)
                                              OutlinedButton.icon(
                                                key: Key(
                                                  'street-scrap-maintenance-${maintenance.traitId}',
                                                ),
                                                onPressed:
                                                    !_saving &&
                                                        !invalidReservation &&
                                                        !lockedIds.contains(
                                                          selected.instanceId,
                                                        ) &&
                                                        !widget
                                                            .session
                                                            .isReadOnly &&
                                                        _chapter != null &&
                                                        _chapter! >= 3
                                                    ? () =>
                                                          _startTraitMaintenance(
                                                            selected,
                                                            maintenance,
                                                          )
                                                    : null,
                                                icon: const Icon(
                                                  Icons
                                                      .cleaning_services_outlined,
                                                ),
                                                label: Text(
                                                  StreetScrapLocalizations.of(
                                                    context,
                                                  ).maintenanceTitle(
                                                    maintenance.title,
                                                  ),
                                                ),
                                              ),
                                          for (final rule
                                              in widget
                                                  .catalog
                                                  .packingRules
                                                  .values
                                                  .where(
                                                    (rule) =>
                                                        rule.inputItemId ==
                                                        selected.itemId,
                                                  ))
                                            if (inventory.objects.values
                                                    .where(
                                                      (item) =>
                                                          item.itemId ==
                                                              rule.inputItemId &&
                                                          item
                                                              .containerContents
                                                              .isEmpty &&
                                                          !lockedIds.contains(
                                                            item.instanceId,
                                                          ),
                                                    )
                                                    .length >=
                                                rule.count)
                                              OutlinedButton.icon(
                                                onPressed:
                                                    !_saving &&
                                                        !invalidReservation &&
                                                        !lockedIds.contains(
                                                          selected.instanceId,
                                                        ) &&
                                                        !widget
                                                            .session
                                                            .isReadOnly
                                                    ? () => _packSelected(rule)
                                                    : null,
                                                icon: const Icon(
                                                  Icons.inventory_2_outlined,
                                                ),
                                                label: Text(
                                                  strings.text(
                                                    'board.packCount',
                                                    arguments: {
                                                      'count': '${rule.count}',
                                                    },
                                                  ),
                                                ),
                                              ),
                                          if (selected.itemId ==
                                                  'meal.shared' &&
                                              inventory
                                                      .placements[selected
                                                          .instanceId]
                                                      ?.gridId ==
                                                  'backpack' &&
                                              inventory.objects.values.any(
                                                (item) =>
                                                    streetScrapMealContainerItemIds
                                                        .contains(
                                                          item.itemId,
                                                        ) &&
                                                    item.containerState['contentItemId'] ==
                                                        null &&
                                                    item.containerState['cleanliness'] ==
                                                        'clean' &&
                                                    inventory
                                                            .placements[item
                                                                .instanceId]
                                                            ?.gridId ==
                                                        'backpack' &&
                                                    !_lockedCraftIds.contains(
                                                      item.instanceId,
                                                    ),
                                              ))
                                            OutlinedButton.icon(
                                              key: const Key(
                                                'street-scrap-pack-shared-meal',
                                              ),
                                              onPressed:
                                                  !_saving &&
                                                      !invalidReservation &&
                                                      !lockedIds.contains(
                                                        selected.instanceId,
                                                      ) &&
                                                      !widget.session.isReadOnly
                                                  ? _packSelectedSharedMeal
                                                  : null,
                                              icon: const Icon(
                                                Icons.lunch_dining_outlined,
                                              ),
                                              label: Text(
                                                strings.text('mealPack.action'),
                                              ),
                                            ),
                                          if (widget.catalog.packingRules.values
                                              .any(
                                                (rule) =>
                                                    rule.outputItemId ==
                                                        selected.itemId &&
                                                    rule.manualUnpack,
                                              ))
                                            OutlinedButton.icon(
                                              onPressed:
                                                  !_saving &&
                                                      !invalidReservation &&
                                                      !lockedIds.contains(
                                                        selected.instanceId,
                                                      ) &&
                                                      !widget.session.isReadOnly
                                                  ? _unpackSelected
                                                  : null,
                                              icon: const Icon(
                                                Icons.unarchive_outlined,
                                              ),
                                              label: Text(
                                                strings.text(
                                                  'board.unpackBundle',
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                    const SizedBox(height: 14),
                                    Text(
                                      strings.text('board.pendingItems'),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 6),
                                    if (unplaced.isEmpty)
                                      Card(
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Text(
                                            strings.text(
                                              'board.pendingItemsEmpty',
                                            ),
                                          ),
                                        ),
                                      )
                                    else
                                      ...unplaced.map(
                                        (item) => _ObjectListTile(
                                          key: ValueKey(
                                            'street-scrap-object-${item.instanceId}',
                                          ),
                                          item: item,
                                          selected:
                                              item.instanceId ==
                                              _selectedInstanceId,
                                          enabled:
                                              !_saving &&
                                              !invalidReservation &&
                                              !widget.session.isReadOnly,
                                          onTap: () => _select(item.instanceId),
                                          onDragUpdate:
                                              _autoScrollDuringListDrag,
                                          woodBoardSpriteBytes:
                                              widget.woodBoardSpriteBytes,
                                          threadSpoolSpriteBytes:
                                              widget.threadSpoolSpriteBytes,
                                          materialAtlasBytes:
                                              widget.materialAtlasBytes,
                                          toolAtlasBytes: widget.toolAtlasBytes,
                                          materialPackArtBytes:
                                              widget.materialPackArtBytes,
                                          mineralPackArtBytes:
                                              widget.mineralPackArtBytes,
                                          woodChipBundleArtBytes:
                                              widget.woodChipBundleArtBytes,
                                        ),
                                      ),
                                    if (storedIds.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      Text(
                                        strings.text('board.homeStorage'),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      ...storedIds.map((id) {
                                        final item = inventory.objects[id]!;
                                        return _ObjectListTile(
                                          key: ValueKey(
                                            'street-scrap-object-${item.instanceId}',
                                          ),
                                          item: item,
                                          selected:
                                              item.instanceId ==
                                              _selectedInstanceId,
                                          enabled:
                                              !_saving &&
                                              !invalidReservation &&
                                              !widget.session.isReadOnly,
                                          subtitle: strings.text(
                                            'board.storageItem',
                                          ),
                                          onTap: () => _select(item.instanceId),
                                          onDragUpdate:
                                              _autoScrollDuringListDrag,
                                          woodBoardSpriteBytes:
                                              widget.woodBoardSpriteBytes,
                                          threadSpoolSpriteBytes:
                                              widget.threadSpoolSpriteBytes,
                                          materialAtlasBytes:
                                              widget.materialAtlasBytes,
                                          toolAtlasBytes: widget.toolAtlasBytes,
                                          materialPackArtBytes:
                                              widget.materialPackArtBytes,
                                          mineralPackArtBytes:
                                              widget.mineralPackArtBytes,
                                          woodChipBundleArtBytes:
                                              widget.woodChipBundleArtBytes,
                                        );
                                      }),
                                    ],
                                    const SizedBox(height: 8),
                                    Text(
                                      strings.text(
                                        _selectedInstanceId == null
                                            ? 'board.instructionUnselected'
                                            : 'board.instructionSelected',
                                      ),
                                      textAlign: TextAlign.center,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                    ),
                    NavigationBar(
                      key: const Key('street-scrap-section-navigation'),
                      selectedIndex: _activeSection,
                      // Inactive destinations stay visual-only; the active
                      // destination gets one short label for orientation.
                      labelBehavior:
                          NavigationDestinationLabelBehavior.onlyShowSelected,
                      onDestinationSelected: (index) {
                        _streetExploreTransition?.cancel();
                        setState(() {
                          _protagonistPose = 0;
                          _activeSection = index;
                          _selectedInstanceId = null;
                          if (_inventoryScrollController.hasClients) {
                            _inventoryScrollController.jumpTo(0);
                          }
                        });
                      },
                      destinations: [
                        NavigationDestination(
                          key: const Key('street-scrap-nav-board'),
                          icon: const Icon(Icons.grid_view_rounded),
                          tooltip: strings.text('board.materialWorkspaceShort'),
                          label: strings.text('board.materialWorkspaceShort'),
                        ),
                        NavigationDestination(
                          key: const Key('street-scrap-nav-expedition'),
                          icon: const Icon(Icons.travel_explore_rounded),
                          tooltip: strings.text('expedition.title'),
                          label: strings.text('expedition.title'),
                        ),
                        NavigationDestination(
                          key: const Key('street-scrap-nav-fishing'),
                          icon: const Icon(Icons.phishing_rounded),
                          tooltip: strings.text('fishing.title'),
                          label: strings.text('fishing.title'),
                        ),
                        NavigationDestination(
                          key: const Key('street-scrap-nav-workshop'),
                          icon: const Icon(Icons.handyman_outlined),
                          tooltip: strings.text('woodwork.workbenchTitle'),
                          label: strings.text('woodwork.workbenchTitle'),
                        ),
                        NavigationDestination(
                          key: const Key('street-scrap-nav-orders'),
                          icon: const Icon(Icons.assignment_outlined),
                          tooltip: strings.text('orders.title'),
                          label: strings.text('orders.title'),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVisualMaterialBoard(BuildContext context) {
    final strings = StreetScrapLocalizations.of(context);
    final mediaSize = MediaQuery.sizeOf(context);
    // Split board and material shelf on tablet-sized windows. The shelf pages
    // in place rather than growing vertically, so common layouts need no
    // scrolling.
    final wideMaterialLayout =
        mediaSize.width >= 820 && mediaSize.height >= 620;
    final inventory = _inventory;
    final grid = _grids[_activeGrid]!;
    final placements = inventory.placements.values
        .where((placement) => placement.gridId == grid.id)
        .toList(growable: false);
    final storedIds = inventory.storage.values.expand((ids) => ids).toSet();
    final trayItems = inventory.objects.values
        .where(
          (item) =>
              !inventory.placements.containsKey(item.instanceId) &&
              !storedIds.contains(item.instanceId),
        )
        .toList(growable: false);
    // Keep every placed material visible from either grid. This lets the
    // player see backpack contents while arranging the workbench, without
    // switching to a text list or scrolling the workspace.
    // Paging keeps it fully visible without adding vertical scrolling.
    final placedShelfItems = inventory.objects.values.where(
      (item) => inventory.placements.containsKey(item.instanceId),
    );
    final materialShelfItems = [...trayItems, ...placedShelfItems];
    final selected = _selectedInstanceId == null
        ? null
        : inventory.objects[_selectedInstanceId];
    final selectedMaintenance = selected == null
        ? const <StreetScrapTraitMaintenanceProfile>[]
        : StreetScrapMaintenance.profilesForTarget(selected);
    final selectedTraits = selected == null
        ? const <MapEntry<String, StreetScrapTraitPresentation>>[]
        : StreetScrapTraitPresentation.forTraits(
            selected.traits,
            localizations: strings,
          );
    final lockedIds = _lockedCraftIds;
    final enabled =
        !_saving &&
        !widget.session.isReadOnly &&
        !lockedIds.contains('__invalid_craft_reservation__');
    final selectedCanMove =
        selected != null && enabled && !lockedIds.contains(selected.instanceId);
    final actions = <PopupMenuEntry<String>>[];
    if (selected != null) {
      if (inventory.placements.containsKey(selected.instanceId)) {
        actions.add(
          PopupMenuItem(
            value: 'rotate',
            child: Text(strings.text('board.rotate')),
          ),
        );
        if ((_chapter ?? 0) >= 3) {
          for (final maintenance in selectedMaintenance) {
            actions.add(
              PopupMenuItem(
                value: 'maintenance:${maintenance.traitId}',
                child: Text(
                  StreetScrapLocalizations.of(
                    context,
                  ).maintenanceTitle(maintenance.title),
                ),
              ),
            );
          }
        }
      }
      for (final rule in widget.catalog.packingRules.values.where(
        (rule) => rule.inputItemId == selected.itemId,
      )) {
        final count = inventory.objects.values
            .where(
              (item) =>
                  item.itemId == rule.inputItemId &&
                  item.containerContents.isEmpty &&
                  !lockedIds.contains(item.instanceId),
            )
            .length;
        if (count >= rule.count) {
          actions.add(
            PopupMenuItem(
              value: 'pack:${rule.inputItemId}',
              child: Text(
                strings.text(
                  'board.packCount',
                  arguments: {'count': '${rule.count}'},
                ),
              ),
            ),
          );
        }
      }
      if (widget.catalog.packingRules.values.any(
        (rule) => rule.outputItemId == selected.itemId && rule.manualUnpack,
      )) {
        actions.add(
          PopupMenuItem(
            value: 'unpack',
            child: Text(strings.text('board.unpackBundle')),
          ),
        );
      }
      if (selected.itemId == 'meal.shared' &&
          inventory.placements[selected.instanceId]?.gridId == 'backpack' &&
          inventory.objects.values.any(
            (item) =>
                streetScrapMealContainerItemIds.contains(item.itemId) &&
                item.containerState['contentItemId'] == null &&
                item.containerState['cleanliness'] == 'clean' &&
                inventory.placements[item.instanceId]?.gridId == 'backpack' &&
                !lockedIds.contains(item.instanceId),
          )) {
        actions.add(
          PopupMenuItem(
            key: const Key('street-scrap-pack-shared-meal'),
            value: 'mealPack',
            child: Text(strings.text('mealPack.action')),
          ),
        );
      }
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Tooltip(
                      message: strings.text('board.workingGridShort'),
                      child: IconButton.filledTonal(
                        key: const Key('street-scrap-select-board'),
                        isSelected: _activeGrid == 'board',
                        onPressed: enabled
                            ? () => setState(() {
                                _activeGrid = 'board';
                                _keyboardX = 0;
                                _keyboardY = 0;
                              })
                            : null,
                        icon: const Icon(Icons.grid_view_rounded),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Tooltip(
                      message: strings.text('board.backpackGridShort'),
                      child: IconButton.filledTonal(
                        key: const Key('street-scrap-select-backpack'),
                        isSelected: _activeGrid == 'backpack',
                        onPressed: enabled
                            ? () => setState(() {
                                _activeGrid = 'backpack';
                                _keyboardX = 0;
                                _keyboardY = 0;
                              })
                            : null,
                        icon: const Icon(Icons.backpack_outlined),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              if (!_materialsExpanded)
                IconButton(
                  key: const Key('street-scrap-keyboard-grid-focus'),
                  tooltip: strings.text('board.keyboardHelp'),
                  onPressed: _focusKeyboardGrid,
                  icon: const Icon(Icons.keyboard_alt_outlined),
                ),
              IconButton(
                key: const Key('street-scrap-open-recipes'),
                tooltip: strings.text(
                  'board.viewRecipes',
                  arguments: {
                    'count': '${widget.recipeCatalog.recipes.length}',
                  },
                ),
                onPressed: _showRecipes,
                icon: const Icon(Icons.menu_book_outlined),
              ),
              IconButton.filledTonal(
                key: const Key('street-scrap-toggle-material-focus'),
                tooltip: strings.text(
                  _materialsExpanded
                      ? 'board.materialGalleryBack'
                      : 'board.materialFocusMode',
                ),
                isSelected: _materialsExpanded,
                onPressed: () => setState(() {
                  _materialsExpanded = !_materialsExpanded;
                  if (_materialsExpanded) _workspaceDetachedPage = 0;
                }),
                icon: Icon(
                  _materialsExpanded
                      ? Icons.close_fullscreen_rounded
                      : Icons.photo_library_outlined,
                ),
              ),
              if (!_materialsExpanded) ...[
                const SizedBox(width: 2),
                IconButton.filledTonal(
                  key: const Key('street-scrap-open-material-workspace'),
                  tooltip: strings.text('board.materialWorkspace'),
                  onPressed: _showMaterialWorkspace,
                  icon: const Icon(Icons.open_in_full_rounded),
                ),
              ],
            ],
          ),
        ),
        if (_saving) const LinearProgressIndicator(),
        if (_actionError != null)
          MaterialBanner(
            content: Text(_actionError!),
            actions: [
              TextButton(
                onPressed: () => setState(() => _actionError = null),
                child: Text(strings.text('common.dismiss')),
              ),
            ],
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final sideRailWidth = wideMaterialLayout
                  // Keep the board usable beside a roomy material shelf.
                  // The shelf pages in place rather than growing vertically.
                  ? (constraints.maxWidth * 0.46).clamp(380.0, 580.0)
                  : 0.0;
              final dimension = <double>[
                constraints.maxWidth -
                    sideRailWidth -
                    (wideMaterialLayout ? 24 : 16),
                constraints.maxHeight - 8,
                960,
              ].reduce((a, b) => a < b ? a : b).clamp(96, 960).toDouble();
              final showEmptyStreetScene =
                  wideMaterialLayout &&
                  !_materialsExpanded &&
                  grid.id == 'board' &&
                  inventory.objects.isEmpty;
              if (showEmptyStreetScene) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: SizedBox.expand(
                    child: Material(
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(24),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        key: const Key('street-scrap-empty-material-explore'),
                        onTap: _enterExpeditionFromStreetScene,
                        child: Semantics(
                          button: true,
                          label: strings.text('expedition.title'),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              const CustomPaint(
                                painter: _StreetScrapCornerPainter(),
                              ),
                              _StreetScrapIdleProtagonist(
                                pose: _protagonistPose,
                                art: widget.protagonistArt,
                              ),
                              Align(
                                alignment: Alignment.bottomCenter,
                                child: Padding(
                                  padding: const EdgeInsets.all(18),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primaryContainer,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: .3,
                                          ),
                                          blurRadius: 18,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(22),
                                      child: Icon(
                                        Icons.travel_explore_rounded,
                                        size: 56,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }
              final board = SizedBox.square(
                dimension: dimension,
                child: Focus(
                  focusNode: _keyboardGridFocus,
                  onKeyEvent: _handleGridKey,
                  child: Semantics(
                    label: strings.text('board.keyboardSemantics'),
                    child: _StreetScrapGrid(
                      grid: grid,
                      objects: inventory.objects,
                      placements: placements,
                      selectedInstanceId: _selectedInstanceId,
                      cursorX: _keyboardX,
                      cursorY: _keyboardY,
                      enabled: enabled,
                      onEmptyCellTap: (x, y) {
                        setState(() {
                          _keyboardX = x;
                          _keyboardY = y;
                        });
                        _placeAt(x, y);
                      },
                      onOccupiedCellTap: (id, x, y) {
                        setState(() {
                          _keyboardX = x;
                          _keyboardY = y;
                        });
                        if (_selectedInstanceId == null ||
                            _selectedInstanceId == id) {
                          _select(id);
                        } else {
                          _placeAt(x, y);
                        }
                      },
                      onDrop: (id, x, y) => _moveInstanceTo(id, grid.id, x, y),
                      woodBoardSpriteBytes: widget.woodBoardSpriteBytes,
                      threadSpoolSpriteBytes: widget.threadSpoolSpriteBytes,
                      materialAtlasBytes: widget.materialAtlasBytes,
                      toolAtlasBytes: widget.toolAtlasBytes,
                      materialPackArtBytes: widget.materialPackArtBytes,
                      mineralPackArtBytes: widget.mineralPackArtBytes,
                      woodChipBundleArtBytes: widget.woodChipBundleArtBytes,
                    ),
                  ),
                ),
              );
              if (_materialsExpanded) {
                return _buildWideMaterialRail(
                  context,
                  strings: strings,
                  trayItems: trayItems,
                  overviewItems: inventory.placements.keys
                      .map((id) => inventory.objects[id])
                      .whereType<StreetScrapObject>()
                      .toList(growable: false),
                  selected: selected,
                  selectedTraits: selectedTraits,
                  actions: actions,
                  enabled: enabled,
                  selectedCanMove: selectedCanMove,
                  selectedMaintenance: selectedMaintenance,
                );
              }
              if (!wideMaterialLayout) return Center(child: board);
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  board,
                  const SizedBox(width: 16),
                  SizedBox(
                    width: sideRailWidth,
                    height: constraints.maxHeight,
                    child: _buildWideMaterialRail(
                      context,
                      strings: strings,
                      trayItems: trayItems,
                      overviewItems: inventory.placements.keys
                          .map((id) => inventory.objects[id])
                          .whereType<StreetScrapObject>()
                          .toList(growable: false),
                      selected: selected,
                      selectedTraits: selectedTraits,
                      actions: actions,
                      enabled: enabled,
                      selectedCanMove: selectedCanMove,
                      selectedMaintenance: selectedMaintenance,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        if (!wideMaterialLayout && selected != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                StreetScrapItemSprite(
                  itemId: selected.itemId,
                  source: selected.source,
                  contentItemId:
                      selected.containerState['contentItemId'] as String?,
                  woodBoardSpriteBytes: widget.woodBoardSpriteBytes,
                  threadSpoolSpriteBytes: widget.threadSpoolSpriteBytes,
                  materialAtlasBytes: widget.materialAtlasBytes,
                  toolAtlasBytes: widget.toolAtlasBytes,
                  materialPackArtBytes: widget.materialPackArtBytes,
                  mineralPackSpriteBytes: widget.mineralPackArtBytes,
                  woodChipBundleSpriteBytes: widget.woodChipBundleArtBytes,
                  size: 88,
                  visualScale: 1.08,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.itemName(selected.itemId),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Row(
                        children: [
                          Tooltip(
                            message: strings.itemSource(selected.source),
                            child: Icon(
                              _streetScrapIsProcessed(selected, strings)
                                  ? Icons.construction_rounded
                                  : Icons.search_rounded,
                              size: 16,
                              color: _streetScrapIsProcessed(selected, strings)
                                  ? Theme.of(context).colorScheme.tertiary
                                  : Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Tooltip(
                            message: strings.itemQuality(selected.quality),
                            child: Text(
                              '${selected.quality}',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                        ],
                      ),
                      if (selectedTraits.isNotEmpty)
                        Wrap(
                          spacing: 4,
                          children: [
                            for (final trait in selectedTraits)
                              Tooltip(
                                message:
                                    '${trait.value.name}・${trait.value.effect}',
                                child: const Icon(Icons.auto_awesome, size: 16),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
                if (selectedCanMove && actions.isNotEmpty)
                  PopupMenuButton<String>(
                    key: const Key('street-scrap-material-actions'),
                    tooltip: strings.text('board.moreMaterials'),
                    onSelected: (action) {
                      if (action == 'rotate') unawaited(_rotateSelected());
                      if (action == 'unpack') unawaited(_unpackSelected());
                      if (action == 'mealPack') {
                        unawaited(_packSelectedSharedMeal());
                      }
                      if (action.startsWith('pack:')) {
                        final rule = widget.catalog.packingRules.values
                            .where(
                              (value) =>
                                  value.inputItemId == action.substring(5),
                            )
                            .firstOrNull;
                        if (rule != null) unawaited(_packSelected(rule));
                      }
                      if (action.startsWith('maintenance:')) {
                        final maintenance = selectedMaintenance
                            .where(
                              (value) => value.traitId == action.substring(12),
                            )
                            .firstOrNull;
                        if (maintenance != null) {
                          unawaited(
                            _startTraitMaintenance(selected, maintenance),
                          );
                        }
                      }
                    },
                    itemBuilder: (context) => actions,
                  ),
                IconButton(
                  tooltip: strings.text('board.clearSelection'),
                  onPressed: () => _select(selected.instanceId),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        if (!wideMaterialLayout)
          SizedBox(
            height: materialShelfItems.isEmpty
                ? 76
                : (MediaQuery.sizeOf(context).width < 420 ? 264 : 226),
            child: materialShelfItems.isEmpty
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
                    child: Material(
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(22),
                      child: InkWell(
                        key: Key(
                          inventory.objects.isEmpty
                              ? 'street-scrap-empty-material-explore'
                              : 'street-scrap-open-empty-material-shelf',
                        ),
                        borderRadius: BorderRadius.circular(22),
                        onTap: inventory.objects.isEmpty
                            ? () => setState(() {
                                _activeSection = 1;
                                _selectedInstanceId = null;
                              })
                            : _showMaterialWorkspace,
                        child: Semantics(
                          button: true,
                          label: strings.text(
                            inventory.objects.isEmpty
                                ? 'expedition.title'
                                : 'board.materialWorkspaceShort',
                          ),
                          child: Tooltip(
                            message: strings.text(
                              inventory.objects.isEmpty
                                  ? 'expedition.title'
                                  : 'board.materialWorkspaceShort',
                            ),
                            child: Center(
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primaryContainer,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Icon(
                                        inventory.objects.isEmpty
                                            ? Icons.travel_explore_rounded
                                            : Icons.inventory_2_rounded,
                                        size: 42,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                                  ),
                                  if (inventory.objects.isNotEmpty)
                                    Positioned(
                                      right: -8,
                                      top: -5,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.tertiaryContainer,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          child: Text(
                                            '${inventory.objects.length}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onTertiaryContainer,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      const spacing = 6.0;
                      final phoneCarousel = constraints.maxWidth < 420;
                      final materialTileSize = phoneCarousel
                          ? constraints.maxWidth.clamp(96.0, 220.0).toDouble()
                          : 176.0;
                      final materialArtSize = materialTileSize - 12;
                      final fullSlotCount = phoneCarousel
                          ? 1
                          : ((constraints.maxWidth + spacing) /
                                    (materialTileSize + spacing))
                                .floor()
                                .clamp(1, 8)
                                .toInt();
                      final showPager =
                          materialShelfItems.length > fullSlotCount;
                      final slotCount = fullSlotCount;
                      final pageCount = (materialShelfItems.length / slotCount)
                          .ceil();
                      final page = _materialTrayPage.clamp(0, pageCount - 1);
                      final visibleItems = materialShelfItems
                          .skip(page * slotCount)
                          .take(slotCount);
                      return Material(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(22),
                        child: Column(
                          children: [
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  for (final item in visibleItems) ...[
                                    SizedBox.square(
                                      dimension: materialTileSize,
                                      child: Semantics(
                                        container: true,
                                        button: true,
                                        enabled: enabled,
                                        selected:
                                            item.instanceId ==
                                            _selectedInstanceId,
                                        label: strings.text(
                                          'board.itemSemantics',
                                          arguments: {
                                            'name': strings.itemName(
                                              item.itemId,
                                            ),
                                            'source': strings.itemSource(
                                              item.source,
                                            ),
                                            'quality': strings.itemQuality(
                                              item.quality,
                                            ),
                                            'width': '${item.footprint.width}',
                                            'height':
                                                '${item.footprint.height}',
                                            'extra': '',
                                          },
                                        ),
                                        onTap: enabled
                                            ? () => _select(item.instanceId)
                                            : null,
                                        child: ExcludeSemantics(
                                          child: Tooltip(
                                            message: strings.itemName(
                                              item.itemId,
                                            ),
                                            child: Draggable<String>(
                                              data: item.instanceId,
                                              maxSimultaneousDrags: enabled
                                                  ? 1
                                                  : 0,
                                              feedback: Material(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.surface,
                                                elevation: 6,
                                                child: SizedBox.square(
                                                  dimension: materialTileSize,
                                                  child: StreetScrapItemSprite(
                                                    itemId: item.itemId,
                                                    source: item.source,
                                                    contentItemId:
                                                        item.containerState['contentItemId']
                                                            as String?,
                                                    woodBoardSpriteBytes: widget
                                                        .woodBoardSpriteBytes,
                                                    threadSpoolSpriteBytes: widget
                                                        .threadSpoolSpriteBytes,
                                                    materialAtlasBytes: widget
                                                        .materialAtlasBytes,
                                                    toolAtlasBytes:
                                                        widget.toolAtlasBytes,
                                                    materialPackArtBytes: widget
                                                        .materialPackArtBytes,
                                                    mineralPackSpriteBytes:
                                                        widget
                                                            .mineralPackArtBytes,
                                                    woodChipBundleSpriteBytes:
                                                        widget
                                                            .woodChipBundleArtBytes,
                                                    size: materialArtSize,
                                                    visualScale: 1.4,
                                                  ),
                                                ),
                                              ),
                                              child: Material(
                                                color:
                                                    item.instanceId ==
                                                        _selectedInstanceId
                                                    ? Theme.of(context)
                                                          .colorScheme
                                                          .primaryContainer
                                                    : Theme.of(context)
                                                          .colorScheme
                                                          .surfaceContainerHighest,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(18),
                                                  side: BorderSide(
                                                    color:
                                                        item.instanceId ==
                                                            _selectedInstanceId
                                                        ? Theme.of(
                                                            context,
                                                          ).colorScheme.primary
                                                        : Theme.of(context)
                                                              .colorScheme
                                                              .outlineVariant,
                                                    width:
                                                        item.instanceId ==
                                                            _selectedInstanceId
                                                        ? 2.5
                                                        : 1,
                                                  ),
                                                ),
                                                elevation:
                                                    item.instanceId ==
                                                        _selectedInstanceId
                                                    ? 4
                                                    : 1,
                                                clipBehavior: Clip.antiAlias,
                                                child: InkWell(
                                                  key: ValueKey(
                                                    'street-scrap-tray-${item.instanceId}',
                                                  ),
                                                  onTap: enabled
                                                      ? () => _select(
                                                          item.instanceId,
                                                        )
                                                      : null,
                                                  child: Stack(
                                                    children: [
                                                      Center(
                                                        child: StreetScrapItemSprite(
                                                          itemId: item.itemId,
                                                          source: item.source,
                                                          contentItemId:
                                                              item.containerState['contentItemId']
                                                                  as String?,
                                                          woodBoardSpriteBytes:
                                                              widget
                                                                  .woodBoardSpriteBytes,
                                                          threadSpoolSpriteBytes:
                                                              widget
                                                                  .threadSpoolSpriteBytes,
                                                          materialAtlasBytes: widget
                                                              .materialAtlasBytes,
                                                          toolAtlasBytes: widget
                                                              .toolAtlasBytes,
                                                          materialPackArtBytes:
                                                              widget
                                                                  .materialPackArtBytes,
                                                          mineralPackSpriteBytes:
                                                              widget
                                                                  .mineralPackArtBytes,
                                                          woodChipBundleSpriteBytes:
                                                              widget
                                                                  .woodChipBundleArtBytes,
                                                          size: materialArtSize,
                                                          visualScale: 1.4,
                                                        ),
                                                      ),
                                                      Positioned(
                                                        left: 6,
                                                        top: 6,
                                                        child: Tooltip(
                                                          message: strings
                                                              .itemSource(
                                                                item.source,
                                                              ),
                                                          child: CircleAvatar(
                                                            radius: 14,
                                                            backgroundColor:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .surface
                                                                    .withValues(
                                                                      alpha:
                                                                          0.92,
                                                                    ),
                                                            child: Icon(
                                                              _streetScrapIsProcessed(
                                                                    item,
                                                                    strings,
                                                                  )
                                                                  ? Icons
                                                                        .construction_rounded
                                                                  : Icons
                                                                        .search_rounded,
                                                              size: 16,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      if (item
                                                              .traits
                                                              .isNotEmpty &&
                                                          item.instanceId !=
                                                              _selectedInstanceId)
                                                        Positioned(
                                                          right: 7,
                                                          top: 7,
                                                          child: Tooltip(
                                                            message:
                                                                StreetScrapTraitPresentation.forTraits(
                                                                      item.traits,
                                                                      localizations:
                                                                          strings,
                                                                    )
                                                                    .map(
                                                                      (trait) =>
                                                                          '${trait.value.name}・${trait.value.effect}',
                                                                    )
                                                                    .join('\n'),
                                                            child: DecoratedBox(
                                                              decoration: BoxDecoration(
                                                                color: Theme.of(context)
                                                                    .colorScheme
                                                                    .tertiaryContainer,
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      9,
                                                                    ),
                                                              ),
                                                              child: Padding(
                                                                padding:
                                                                    const EdgeInsets.all(
                                                                      4,
                                                                    ),
                                                                child: Icon(
                                                                  Icons
                                                                      .auto_awesome_rounded,
                                                                  size: 16,
                                                                  color: Theme.of(
                                                                    context,
                                                                  ).colorScheme.onTertiaryContainer,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      Positioned(
                                                        right: 6,
                                                        bottom: 6,
                                                        child: Tooltip(
                                                          message: strings
                                                              .itemQuality(
                                                                item.quality,
                                                              ),
                                                          child: DecoratedBox(
                                                            decoration: BoxDecoration(
                                                              color:
                                                                  Theme.of(
                                                                        context,
                                                                      )
                                                                      .colorScheme
                                                                      .surface
                                                                      .withValues(
                                                                        alpha:
                                                                            0.92,
                                                                      ),
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    10,
                                                                  ),
                                                            ),
                                                            child: Padding(
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        7,
                                                                    vertical: 3,
                                                                  ),
                                                              child: Text(
                                                                '${item.quality}',
                                                                style: Theme.of(
                                                                  context,
                                                                ).textTheme.labelMedium,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (item.instanceId !=
                                        visibleItems.last.instanceId)
                                      const SizedBox(width: spacing),
                                  ],
                                ],
                              ),
                            ),
                            if (showPager)
                              SizedBox(
                                height: 40,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton.filledTonal(
                                      key: const Key(
                                        'street-scrap-material-page-back',
                                      ),
                                      tooltip: strings.text(
                                        'board.previousMaterials',
                                      ),
                                      onPressed: page == 0
                                          ? null
                                          : () => setState(
                                              () =>
                                                  _materialTrayPage = page - 1,
                                            ),
                                      icon: const Icon(
                                        Icons.chevron_left_rounded,
                                      ),
                                    ),
                                    Semantics(
                                      label: strings.text(
                                        'board.pageCount',
                                        arguments: {
                                          'current': '${page + 1}',
                                          'total': '$pageCount',
                                        },
                                      ),
                                      child: SizedBox(
                                        width: 64,
                                        child: LinearProgressIndicator(
                                          value: (page + 1) / pageCount,
                                          minHeight: 5,
                                        ),
                                      ),
                                    ),
                                    IconButton.filledTonal(
                                      key: const Key(
                                        'street-scrap-material-page-next',
                                      ),
                                      tooltip: strings.text(
                                        'board.nextMaterials',
                                      ),
                                      onPressed: page >= pageCount - 1
                                          ? null
                                          : () => setState(
                                              () =>
                                                  _materialTrayPage = page + 1,
                                            ),
                                      icon: const Icon(
                                        Icons.chevron_right_rounded,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
      ],
    );
  }

  Widget _buildWideMaterialRail(
    BuildContext context, {
    required StreetScrapLocalizations strings,
    required List<StreetScrapObject> trayItems,
    required List<StreetScrapObject> overviewItems,
    required StreetScrapObject? selected,
    required List<MapEntry<String, StreetScrapTraitPresentation>>
    selectedTraits,
    required List<PopupMenuEntry<String>> actions,
    required bool enabled,
    required bool selectedCanMove,
    required List<StreetScrapTraitMaintenanceProfile> selectedMaintenance,
  }) {
    final theme = Theme.of(context);
    final detached = trayItems;
    // Keep every material in the side shelf, whether it is loose or already
    // placed on the board. Selecting a placed object must not make the shelf
    // disappear and leave only a duplicate detail card.
    final overviewMode = detached.isEmpty;
    final shelfItemsById = {
      for (final item in [...detached, ...overviewItems]) item.instanceId: item,
    };
    final shelfItems = shelfItemsById.values.toList(growable: false);
    final materialFocusMode = _materialsExpanded;
    final filteredShelfItems = _materialCategory == 'all'
        ? shelfItems
        : shelfItems
              .where((item) => _materialCategoryFor(item) == _materialCategory)
              .toList(growable: false);
    // In the full-screen material catalog, exact visual duplicates share one
    // large card with a quantity badge. The inventory objects themselves stay
    // independent, so selecting a stack still selects one movable instance.
    final materialStackCounts = <String, int>{};
    final materialStackCards = <String, StreetScrapObject>{};
    for (final item in filteredShelfItems) {
      final stackKey = _materialVisualStackKey(item);
      materialStackCounts.update(
        stackKey,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
      materialStackCards.putIfAbsent(stackKey, () => item);
    }
    final galleryItems = materialFocusMode
        ? materialStackCards.values.toList(growable: false)
        : filteredShelfItems;

    return Column(
      children: [
        if (selected != null)
          Card(
            margin: EdgeInsets.zero,
            child: SizedBox(
              height: materialFocusMode ? 48 : 88,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    if (!materialFocusMode) ...[
                      StreetScrapItemSprite(
                        itemId: selected.itemId,
                        source: selected.source,
                        contentItemId:
                            selected.containerState['contentItemId'] as String?,
                        woodBoardSpriteBytes: widget.woodBoardSpriteBytes,
                        threadSpoolSpriteBytes: widget.threadSpoolSpriteBytes,
                        materialAtlasBytes: widget.materialAtlasBytes,
                        toolAtlasBytes: widget.toolAtlasBytes,
                        materialPackArtBytes: widget.materialPackArtBytes,
                        mineralPackSpriteBytes: widget.mineralPackArtBytes,
                        woodChipBundleSpriteBytes:
                            widget.woodChipBundleArtBytes,
                        size: 80,
                        visualScale: 1.08,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!materialFocusMode)
                            Text(
                              strings.itemName(selected.itemId),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall,
                            ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Tooltip(
                                message: strings.itemSource(selected.source),
                                child: Icon(
                                  _streetScrapIsProcessed(selected, strings)
                                      ? Icons.construction_rounded
                                      : Icons.search_rounded,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (materialFocusMode)
                                Tooltip(
                                  message: strings.itemQuality(
                                    selected.quality,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.shield_outlined,
                                        size: 17,
                                      ),
                                      const SizedBox(width: 3),
                                      Text('${selected.quality}'),
                                    ],
                                  ),
                                ),
                              if (!materialFocusMode)
                                Tooltip(
                                  message: strings.itemQuality(
                                    selected.quality,
                                  ),
                                  child: Text('${selected.quality}'),
                                ),
                              if (selectedTraits.isNotEmpty)
                                Tooltip(
                                  message: selectedTraits
                                      .map(
                                        (trait) =>
                                            '${trait.value.name}・${trait.value.effect}',
                                      )
                                      .join('\n'),
                                  child: Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 16,
                                    color: theme.colorScheme.tertiary,
                                  ),
                                ),
                              const Spacer(),
                              if (selectedCanMove && actions.isNotEmpty)
                                PopupMenuButton<String>(
                                  key: const Key(
                                    'street-scrap-wide-material-actions',
                                  ),
                                  tooltip: strings.text('board.moreMaterials'),
                                  onSelected: (action) {
                                    if (action == 'rotate') {
                                      unawaited(_rotateSelected());
                                    } else if (action == 'unpack') {
                                      unawaited(_unpackSelected());
                                    } else if (action == 'mealPack') {
                                      unawaited(_packSelectedSharedMeal());
                                    } else if (action.startsWith('pack:')) {
                                      final rule = widget
                                          .catalog
                                          .packingRules
                                          .values
                                          .where(
                                            (value) =>
                                                value.inputItemId ==
                                                action.substring(5),
                                          )
                                          .firstOrNull;
                                      if (rule != null) {
                                        unawaited(_packSelected(rule));
                                      }
                                    } else if (action.startsWith(
                                      'maintenance:',
                                    )) {
                                      final maintenance = selectedMaintenance
                                          .where(
                                            (value) =>
                                                value.traitId ==
                                                action.substring(12),
                                          )
                                          .firstOrNull;
                                      if (maintenance != null) {
                                        unawaited(
                                          _startTraitMaintenance(
                                            selected,
                                            maintenance,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  itemBuilder: (context) => actions,
                                ),
                              IconButton(
                                tooltip: strings.text('board.clearSelection'),
                                onPressed: () => _select(selected.instanceId),
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (selected != null) const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: SizedBox(
            height: 48,
            child: Row(
              children: [
                for (final category in _materialCategories)
                  Expanded(
                    child: Semantics(
                      key: Key('street-scrap-category-$category'),
                      label: strings.text('board.category.$category'),
                      button: true,
                      selected: _materialCategory == category,
                      onTap: () => setState(() {
                        _materialCategory = category;
                        _workspaceDetachedPage = 0;
                      }),
                      child: Tooltip(
                        message: strings.text('board.category.$category'),
                        excludeFromSemantics: true,
                        child: ExcludeSemantics(
                          child: Center(
                            child: AnimatedContainer(
                              key: ValueKey(
                                'street-scrap-category-chip-$category',
                              ),
                              duration: const Duration(milliseconds: 160),
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: _materialCategory == category
                                    ? _materialCategoryAccents[category]!
                                          .withValues(alpha: .2)
                                    : theme.colorScheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(13),
                                border: Border.all(
                                  color: _materialCategory == category
                                      ? _materialCategoryAccents[category]!
                                      : theme.colorScheme.outlineVariant,
                                  width: _materialCategory == category ? 2 : 1,
                                ),
                                boxShadow: _materialCategory == category
                                    ? [
                                        BoxShadow(
                                          color:
                                              _materialCategoryAccents[category]!
                                                  .withValues(alpha: .16),
                                          blurRadius: 10,
                                        ),
                                      ]
                                    : const [],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => setState(() {
                                    _materialCategory = category;
                                    _workspaceDetachedPage = 0;
                                  }),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Icon(
                                        _materialCategoryIcons[category],
                                        size: 23,
                                        color: _materialCategory == category
                                            ? _materialCategoryAccents[category]
                                            : theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                      ),
                                      if (_materialCategory == category)
                                        Positioned(
                                          bottom: 2,
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              color:
                                                  _materialCategoryAccents[category],
                                              shape: BoxShape.circle,
                                            ),
                                            child: const SizedBox.square(
                                              dimension: 4,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxColumns = materialFocusMode
                  // Keep the artwork large enough to read at a glance. More
                  // items are reached by paging, never by shrinking cards.
                  ? constraints.maxWidth >= 700
                        ? 2
                        : 1
                  : constraints.maxWidth < 440
                  ? 1
                  : 2;
              final columns = galleryItems.isEmpty
                  ? 1
                  : (materialFocusMode
                            ? galleryItems.length.clamp(1, maxColumns)
                            : maxColumns)
                        .toInt();
              const spacing = 8.0;
              const shelfPadding = 4.0;
              // Focus mode shows one row of large art. Narrow screens use one
              // card; wide screens use two. The catalog never scrolls.
              final maxRows = materialFocusMode ? 1 : 2;
              final pageCapacity = columns * maxRows;
              final focusTileLimit = materialFocusMode ? 500.0 : 320.0;
              final widthExtent =
                  ((constraints.maxWidth -
                              shelfPadding * 2 -
                              spacing * (columns - 1)) /
                          columns)
                      .clamp(112.0, focusTileLimit)
                      .toDouble();
              final reservedPagerHeight = galleryItems.length > pageCapacity
                  ? 52.0
                  : 0.0;
              final availableTileHeight =
                  constraints.maxHeight -
                  reservedPagerHeight -
                  shelfPadding * 2;
              final visibleCount = galleryItems.length.clamp(0, pageCapacity);
              final targetRows = materialFocusMode
                  ? (visibleCount / columns).ceil().clamp(1, maxRows)
                  : (galleryItems.length / columns).ceil().clamp(1, 2);
              final extentForTargetRows =
                  (availableTileHeight - spacing * (targetRows - 1)) /
                  targetRows;
              final focusHeightLimit = extentForTargetRows
                  .clamp(112.0, focusTileLimit)
                  .toDouble();
              final tileExtent = materialFocusMode
                  ? widthExtent.clamp(112.0, focusHeightLimit).toDouble()
                  : widthExtent;
              final galleryWidth =
                  (columns * tileExtent + spacing * (columns - 1))
                      .clamp(0.0, constraints.maxWidth)
                      .toDouble();
              final rowCount = materialFocusMode ? maxRows : 2;
              final pageSize = rowCount * columns;
              final pageCount = galleryItems.isEmpty
                  ? 0
                  : (galleryItems.length / pageSize).ceil();
              final activePage = _workspaceDetachedPage.clamp(
                0,
                pageCount == 0 ? 0 : pageCount - 1,
              );
              final pageItems = galleryItems
                  .skip(activePage * pageSize)
                  .take(pageSize)
                  .toList();
              return Column(
                children: [
                  Expanded(
                    child: pageItems.isEmpty
                        ? Center(
                            child: overviewMode
                                ? Material(
                                    color:
                                        theme.colorScheme.surfaceContainerHigh,
                                    borderRadius: BorderRadius.circular(24),
                                    child: InkWell(
                                      key: const Key(
                                        'street-scrap-empty-material-explore',
                                      ),
                                      borderRadius: BorderRadius.circular(24),
                                      onTap: _enterExpeditionFromStreetScene,
                                      child: Semantics(
                                        button: true,
                                        label: strings.text('expedition.title'),
                                        child: Tooltip(
                                          message: strings.text(
                                            'expedition.title',
                                          ),
                                          child: Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              const CustomPaint(
                                                painter:
                                                    _StreetScrapCornerPainter(),
                                              ),
                                              _StreetScrapIdleProtagonist(
                                                pose: _protagonistPose,
                                                art: widget.protagonistArt,
                                              ),
                                              Align(
                                                alignment:
                                                    Alignment.bottomCenter,
                                                child: Padding(
                                                  padding: const EdgeInsets.all(
                                                    18,
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      DecoratedBox(
                                                        decoration: BoxDecoration(
                                                          color: theme
                                                              .colorScheme
                                                              .primaryContainer,
                                                          shape:
                                                              BoxShape.circle,
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: Colors
                                                                  .black
                                                                  .withValues(
                                                                    alpha: .25,
                                                                  ),
                                                              blurRadius: 14,
                                                              offset:
                                                                  const Offset(
                                                                    0,
                                                                    5,
                                                                  ),
                                                            ),
                                                          ],
                                                        ),
                                                        child: Padding(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                20,
                                                              ),
                                                          child: Icon(
                                                            Icons
                                                                .travel_explore_rounded,
                                                            size: 52,
                                                            color: theme
                                                                .colorScheme
                                                                .onPrimaryContainer,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                : Icon(
                                    Icons.inventory_2_outlined,
                                    size: 64,
                                    color: theme.colorScheme.outlineVariant,
                                  ),
                          )
                        : Center(
                            child: SizedBox(
                              width: galleryWidth,
                              child: GridView.builder(
                                key: const Key(
                                  'street-scrap-wide-material-shelf',
                                ),
                                physics: const NeverScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(shelfPadding),
                                itemCount: pageItems.length,
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: columns,
                                      crossAxisSpacing: spacing,
                                      mainAxisSpacing: spacing,
                                      mainAxisExtent: tileExtent,
                                    ),
                                itemBuilder: (context, index) {
                                  final item = pageItems[index];
                                  final stackCount =
                                      materialStackCounts[_materialVisualStackKey(
                                        item,
                                      )] ??
                                      1;
                                  final itemSelected =
                                      item.instanceId == _selectedInstanceId;
                                  // Full-detail fallback sprites already fill
                                  // their square viewport. Scaling those long
                                  // silhouettes clips the ends; keep them
                                  // fully visible while compact vector glyphs
                                  // can still grow to read at a glance.
                                  final imageScale =
                                      streetScrapOfflineFallbackAssetFor(
                                            item.itemId,
                                          ) !=
                                          null
                                      ? 1.0
                                      : switch (item.itemId) {
                                          'wood.driftwood' ||
                                          'container.broken_bottle' => 1.0,
                                          _ => materialFocusMode ? 1.3 : 1.48,
                                        };
                                  final centerTrailingCard =
                                      columns > 1 &&
                                      pageItems.length % columns == 1 &&
                                      index == pageItems.length - 1;
                                  return Center(
                                    child: Transform.translate(
                                      offset: centerTrailingCard
                                          ? Offset(
                                              tileExtent / 2 + spacing / 2,
                                              0,
                                            )
                                          : Offset.zero,
                                      child: SizedBox.square(
                                        dimension: tileExtent,
                                        child: Semantics(
                                          button: true,
                                          selected: itemSelected,
                                          label: strings.text(
                                            'board.itemSemantics',
                                            arguments: {
                                              'name': strings.itemName(
                                                item.itemId,
                                              ),
                                              'source': strings.itemSource(
                                                item.source,
                                              ),
                                              'quality': strings.itemQuality(
                                                item.quality,
                                              ),
                                              'width':
                                                  '${item.footprint.width}',
                                              'height':
                                                  '${item.footprint.height}',
                                              'extra': '',
                                            },
                                          ),
                                          child: Tooltip(
                                            message: strings.itemName(
                                              item.itemId,
                                            ),
                                            child: Material(
                                              key: ValueKey(
                                                overviewMode
                                                    ? 'street-scrap-wide-overview-${item.instanceId}'
                                                    : 'street-scrap-wide-shelf-${item.instanceId}',
                                              ),
                                              color: itemSelected
                                                  ? const Color(0xFF405744)
                                                  : const Color(0xFF26362D),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(18),
                                                side: BorderSide(
                                                  color: itemSelected
                                                      ? const Color(0xFFB9D5A8)
                                                      : const Color(0xFF526355),
                                                  width: itemSelected
                                                      ? 2.5
                                                      : 1.25,
                                                ),
                                              ),
                                              clipBehavior: Clip.antiAlias,
                                              child: InkWell(
                                                onTap: enabled
                                                    ? () => _select(
                                                        item.instanceId,
                                                      )
                                                    : null,
                                                child: Stack(
                                                  children: [
                                                    Center(
                                                      child: Stack(
                                                        alignment:
                                                            Alignment.center,
                                                        children: [
                                                          Container(
                                                            width:
                                                                tileExtent *
                                                                .66,
                                                            height:
                                                                tileExtent *
                                                                .66,
                                                            decoration: BoxDecoration(
                                                              shape: BoxShape
                                                                  .circle,
                                                              gradient: RadialGradient(
                                                                colors: [
                                                                  theme
                                                                      .colorScheme
                                                                      .surface
                                                                      .withValues(
                                                                        alpha:
                                                                            .72,
                                                                      ),
                                                                  theme
                                                                      .colorScheme
                                                                      .surface
                                                                      .withValues(
                                                                        alpha:
                                                                            0,
                                                                      ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                          StreetScrapItemSprite(
                                                            itemId: item.itemId,
                                                            source: item.source,
                                                            contentItemId:
                                                                item.containerState['contentItemId']
                                                                    as String?,
                                                            woodBoardSpriteBytes:
                                                                widget
                                                                    .woodBoardSpriteBytes,
                                                            threadSpoolSpriteBytes:
                                                                widget
                                                                    .threadSpoolSpriteBytes,
                                                            materialAtlasBytes:
                                                                widget
                                                                    .materialAtlasBytes,
                                                            toolAtlasBytes: widget
                                                                .toolAtlasBytes,
                                                            materialPackArtBytes:
                                                                widget
                                                                    .materialPackArtBytes,
                                                            mineralPackSpriteBytes:
                                                                widget
                                                                    .mineralPackArtBytes,
                                                            woodChipBundleSpriteBytes:
                                                                widget
                                                                    .woodChipBundleArtBytes,
                                                            size:
                                                                tileExtent - 8,
                                                            // Avoid cropping
                                                            // the material's
                                                            // silhouette in
                                                            // the enlarged
                                                            // gallery.
                                                            visualScale:
                                                                imageScale,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Positioned.fill(
                                                      child: IgnorePointer(
                                                        child: DecoratedBox(
                                                          decoration: BoxDecoration(
                                                            gradient: LinearGradient(
                                                              begin: Alignment
                                                                  .topLeft,
                                                              end: Alignment
                                                                  .bottomRight,
                                                              colors: [
                                                                Colors.white
                                                                    .withValues(
                                                                      alpha:
                                                                          .045,
                                                                    ),
                                                                Colors
                                                                    .transparent,
                                                                Colors.black
                                                                    .withValues(
                                                                      alpha: .1,
                                                                    ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    Positioned(
                                                      left: 7,
                                                      top: 7,
                                                      child: DecoratedBox(
                                                        decoration: BoxDecoration(
                                                          color:
                                                              _streetScrapIsProcessed(
                                                                item,
                                                                strings,
                                                              )
                                                              ? const Color(
                                                                  0xFFE2C48E,
                                                                )
                                                              : const Color(
                                                                  0xFFB8D6C3,
                                                                ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                9,
                                                              ),
                                                        ),
                                                        child: Padding(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                4,
                                                              ),
                                                          child: Icon(
                                                            _streetScrapIsProcessed(
                                                                  item,
                                                                  strings,
                                                                )
                                                                ? Icons
                                                                      .construction_rounded
                                                                : Icons
                                                                      .search_rounded,
                                                            size: 16,
                                                            color: const Color(
                                                              0xFF27352C,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    if (materialFocusMode &&
                                                        stackCount > 1)
                                                      Positioned(
                                                        right: 7,
                                                        top: 7,
                                                        child: DecoratedBox(
                                                          decoration: BoxDecoration(
                                                            color: const Color(
                                                              0xFFE8D6A6,
                                                            ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  12,
                                                                ),
                                                            boxShadow: [
                                                              BoxShadow(
                                                                color: Colors
                                                                    .black
                                                                    .withValues(
                                                                      alpha:
                                                                          .22,
                                                                    ),
                                                                blurRadius: 8,
                                                              ),
                                                            ],
                                                          ),
                                                          child: Padding(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal: 9,
                                                                  vertical: 5,
                                                                ),
                                                            child: Text(
                                                              '×$stackCount',
                                                              style: theme
                                                                  .textTheme
                                                                  .labelLarge
                                                                  ?.copyWith(
                                                                    color: const Color(
                                                                      0xFF26362D,
                                                                    ),
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w800,
                                                                  ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    if (item
                                                            .traits
                                                            .isNotEmpty &&
                                                        item.instanceId !=
                                                            _selectedInstanceId)
                                                      Positioned(
                                                        right: 7,
                                                        top: 7,
                                                        child: Tooltip(
                                                          message:
                                                              StreetScrapTraitPresentation.forTraits(
                                                                    item.traits,
                                                                    localizations:
                                                                        strings,
                                                                  )
                                                                  .map(
                                                                    (trait) =>
                                                                        '${trait.value.name}・${trait.value.effect}',
                                                                  )
                                                                  .join('\n'),
                                                          child: DecoratedBox(
                                                            decoration: BoxDecoration(
                                                              color: theme
                                                                  .colorScheme
                                                                  .tertiaryContainer,
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    9,
                                                                  ),
                                                            ),
                                                            child: Padding(
                                                              padding:
                                                                  const EdgeInsets.all(
                                                                    4,
                                                                  ),
                                                              child: Icon(
                                                                Icons
                                                                    .auto_awesome_rounded,
                                                                size: 16,
                                                                color: theme
                                                                    .colorScheme
                                                                    .onTertiaryContainer,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    Positioned(
                                                      right: 6,
                                                      bottom: 4,
                                                      child: DecoratedBox(
                                                        decoration: BoxDecoration(
                                                          color: const Color(
                                                            0xFFE2C48E,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                12,
                                                              ),
                                                        ),
                                                        child: Padding(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 7,
                                                                vertical: 3,
                                                              ),
                                                          child: Text(
                                                            '${item.quality}',
                                                            style: theme
                                                                .textTheme
                                                                .labelSmall
                                                                ?.copyWith(
                                                                  color: const Color(
                                                                    0xFF32291D,
                                                                  ),
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w800,
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    Positioned(
                                                      left: 7,
                                                      right: 42,
                                                      bottom: 5,
                                                      child: DecoratedBox(
                                                        decoration: BoxDecoration(
                                                          color: const Color(
                                                            0xFFE8D8B7,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                12,
                                                              ),
                                                        ),
                                                        child: Padding(
                                                          padding: EdgeInsets.symmetric(
                                                            horizontal:
                                                                materialFocusMode
                                                                ? 9
                                                                : 11,
                                                            vertical:
                                                                materialFocusMode
                                                                ? 5
                                                                : 7,
                                                          ),
                                                          child: Text(
                                                            key: Key(
                                                              'street-scrap-material-name-${item.instanceId}',
                                                            ),
                                                            strings.itemName(
                                                              item.itemId,
                                                            ),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style:
                                                                (materialFocusMode
                                                                        ? theme
                                                                              .textTheme
                                                                              .labelLarge
                                                                        : theme
                                                                              .textTheme
                                                                              .titleSmall)
                                                                    ?.copyWith(
                                                                      color: const Color(
                                                                        0xFF30281E,
                                                                      ),
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w700,
                                                                    ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                  ),
                  if (pageCount > 1)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          key: const Key('street-scrap-wide-page-previous'),
                          tooltip: strings.text('board.previousPage'),
                          onPressed: activePage == 0
                              ? null
                              : () => setState(
                                  () => _workspaceDetachedPage = activePage - 1,
                                ),
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        Semantics(
                          label: strings.text(
                            'board.pageCount',
                            arguments: {
                              'current': '${activePage + 1}',
                              'total': '$pageCount',
                            },
                          ),
                          child: SizedBox(
                            width: 64,
                            child: LinearProgressIndicator(
                              value: (activePage + 1) / pageCount,
                              minHeight: 5,
                            ),
                          ),
                        ),
                        IconButton(
                          key: const Key('street-scrap-wide-page-next'),
                          tooltip: strings.text('board.nextPage'),
                          onPressed: activePage >= pageCount - 1
                              ? null
                              : () => setState(
                                  () => _workspaceDetachedPage = activePage + 1,
                                ),
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                      ],
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  String _friendlyError(Object error) {
    final strings = StreetScrapLocalizations.of(context);
    if (error is StateError) {
      final message = error.message.toString();
      final mealPackError = switch (message) {
        'sharedMealPackLocked' ||
        'chapter5ExpansionNotInstalled' => 'mealPack.error.locked',
        'sharedMealNotCooked' => 'mealPack.error.notCooked',
        'sharedMealMustBeInBackpack' => 'mealPack.error.backpack',
        'mealBoxMissing' => 'mealPack.error.container',
        'mealBoxNotEmpty' => 'mealPack.error.notEmpty',
        'mealBoxNeedsCleaning' => 'mealPack.error.needsCleaning',
        _ => null,
      };
      if (mealPackError != null) return strings.text(mealPackError);
    }
    if (error is StateError &&
        error.message.toString().startsWith('craftInputLocked:')) {
      return strings.text('board.error.craftLocked');
    }
    if (error is StateError && error.message.toString().contains('space')) {
      return strings.text('board.error.noSpace');
    }
    if (error is FormatException || error is StateError) {
      return strings.text('board.error.invalidPlacement');
    }
    return strings.text('board.error.saveFailed');
  }

  Set<String> get _lockedCraftIds {
    final raw = widget.session.snapshot.state['craftOperation'];
    if (raw == null) return const {};
    if (raw is! Map ||
        raw['lockedInstanceIds'] is! List ||
        (raw['lockedInstanceIds'] as List).any((id) => id is! String)) {
      throw const FormatException('加工鎖定物件存檔格式錯誤。');
    }
    return (raw['lockedInstanceIds'] as List).cast<String>().toSet();
  }

  String _ownerDescription(
    StreetScrapLocalizations strings,
    StreetScrapInventory inventory,
    StreetScrapObject item,
  ) {
    final placement = inventory.placements[item.instanceId];
    if (placement != null) {
      return strings.text(
        'board.ownerLocation',
        arguments: {
          'grid': strings.text(
            placement.gridId == 'board'
                ? 'board.gridNameWorking'
                : 'board.gridNameBackpack',
          ),
          'x': '${placement.x + 1}',
          'y': '${placement.y + 1}',
        },
      );
    }
    for (final entry in inventory.storage.entries) {
      if (entry.value.contains(item.instanceId)) {
        final storageName = switch (entry.key) {
          'home-tutorial-crate' => strings.itemName('storage.wooden_crate'),
          'chapter5.reinforced_chest' => strings.itemName(
            'storage.reinforced_chest',
          ),
          _ => entry.key,
        };
        return strings.text(
          'board.ownerStorage',
          arguments: {'storage': storageName},
        );
      }
    }
    return strings.text('board.ownerPending');
  }
}

class _StreetScrapCornerPainter extends CustomPainter {
  const _StreetScrapCornerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 320;
    canvas.save();
    canvas.scale(scale, scale);
    final paint = Paint()..isAntiAlias = false;
    final height = size.height / scale;
    final width = size.width / scale;

    paint.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xff536c64), Color(0xffa88962), Color(0xff443f35)],
      stops: [0, .58, 1],
    ).createShader(Rect.fromLTWH(0, 0, width, height));
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), paint);
    paint.shader = null;

    // Low apartment silhouettes and warm windows make the empty shelf feel
    // like an explorable place instead of a blank placeholder.
    paint.color = const Color(0xff394b46);
    canvas.drawRect(
      Rect.fromLTWH(0, height * .25, width * .27, height * .39),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(width * .73, height * .19, width * .27, height * .45),
      paint,
    );
    paint.color = const Color(0xffdfb776);
    for (final x in [18.0, 48.0, 250.0, 280.0]) {
      for (final y in [height * .32, height * .43]) {
        canvas.drawRect(Rect.fromLTWH(x, y, 10, 15), paint);
      }
    }

    // Pavement and a shallow gutter.
    paint.color = const Color(0xff756d59);
    final pavement = Path()
      ..moveTo(0, height * .64)
      ..lineTo(width, height * .58)
      ..lineTo(width, height)
      ..lineTo(0, height)
      ..close();
    canvas.drawPath(pavement, paint);
    paint.color = const Color(0xffc2a27b);
    canvas.drawRect(Rect.fromLTWH(0, height * .65, width, 5), paint);
    paint.color = const Color(0xff514d41);
    canvas.drawRect(Rect.fromLTWH(0, height * .69, width, 3), paint);

    // Reusable street finds: a recycling crate, folded carton and bottle.
    final crateX = width * .17;
    final crateY = height * .49;
    paint.color = const Color(0xff456057);
    canvas.drawRect(Rect.fromLTWH(crateX, crateY, 54, 66), paint);
    paint.color = const Color(0xff82917a);
    canvas.drawRect(Rect.fromLTWH(crateX + 7, crateY + 8, 40, 7), paint);
    canvas.drawRect(Rect.fromLTWH(crateX + 7, crateY + 28, 40, 7), paint);
    canvas.drawRect(Rect.fromLTWH(crateX + 7, crateY + 48, 40, 7), paint);
    paint.color = const Color(0xffba9161);
    final carton = Path()
      ..moveTo(width * .49, height * .58)
      ..lineTo(width * .69, height * .55)
      ..lineTo(width * .73, height * .67)
      ..lineTo(width * .51, height * .70)
      ..close();
    canvas.drawPath(carton, paint);
    paint.color = const Color(0xffd0aa78);
    canvas.drawRect(
      Rect.fromLTWH(width * .52, height * .58, width * .11, 5),
      paint,
    );
    paint.color = const Color(0xff5b8176);
    canvas.drawRect(Rect.fromLTWH(width * .81, height * .52, 23, 50), paint);
    paint.color = const Color(0xff87a496);
    canvas.drawRect(Rect.fromLTWH(width * .84, height * .48, 10, 8), paint);
    canvas.drawRect(Rect.fromLTWH(width * .815, height * .60, 18, 4), paint);

    // Small warm street lamp glow.
    paint.color = const Color(0xffd8bb81).withValues(alpha: .75);
    canvas.drawRect(
      Rect.fromLTWH(width * .87, height * .28, 5, height * .23),
      paint,
    );
    canvas.drawRect(Rect.fromLTWH(width * .84, height * .26, 14, 6), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StreetScrapCornerPainter oldDelegate) => false;
}

class _StreetScrapIdleProtagonist extends StatefulWidget {
  const _StreetScrapIdleProtagonist({required this.pose, required this.art});

  /// 0 is the static idle image; 1–3 select the action sprite sheet cells.
  final int pose;
  final StreetScrapProtagonistArt? art;

  @override
  State<_StreetScrapIdleProtagonist> createState() =>
      _StreetScrapIdleProtagonistState();
}

class _StreetScrapIdleProtagonistState
    extends State<_StreetScrapIdleProtagonist> {
  static const _ambientPoses = [0, 2, 3];
  static const _poseInterval = Duration(milliseconds: 1800);

  Timer? _poseTimer;
  int _ambientPoseIndex = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPoseTimer();
  }

  @override
  void didUpdateWidget(covariant _StreetScrapIdleProtagonist oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pose != widget.pose) _syncPoseTimer();
  }

  @override
  void dispose() {
    _poseTimer?.cancel();
    super.dispose();
  }

  void _syncPoseTimer() {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion || widget.pose != 0) {
      _poseTimer?.cancel();
      _poseTimer = null;
      if (reduceMotion && _ambientPoseIndex != 0) {
        _ambientPoseIndex = 0;
      }
      return;
    }
    _poseTimer ??= Timer.periodic(_poseInterval, (_) {
      if (!mounted || widget.pose != 0) return;
      setState(() {
        _ambientPoseIndex = (_ambientPoseIndex + 1) % _ambientPoses.length;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentPose = widget.pose == 0
        ? _ambientPoses[_ambientPoseIndex]
        : widget.pose;
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // The three equal action-sheet cells each have a 628:835 aspect ratio.
          final frameWidth = (constraints.maxWidth * .48)
              .clamp(0.0, constraints.maxHeight * .68 * (628 / 835))
              .toDouble();
          final frameHeight = frameWidth * (835 / 628);
          final displayedPose = currentPose.clamp(0, 3);
          return Align(
            alignment: const Alignment(.42, -.08),
            child: SizedBox(
              key: const Key('street-scrap-empty-scene-protagonist'),
              width: frameWidth,
              height: frameHeight,
              child: AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 240),
                child: SizedBox.expand(
                  child: StreetScrapProtagonistSprite(
                    pose: displayedPose,
                    height: frameHeight,
                    art: widget.art,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StreetScrapGrid extends StatelessWidget {
  const _StreetScrapGrid({
    required this.grid,
    required this.objects,
    required this.placements,
    required this.selectedInstanceId,
    required this.cursorX,
    required this.cursorY,
    required this.enabled,
    required this.onEmptyCellTap,
    required this.onOccupiedCellTap,
    required this.onDrop,
    this.woodBoardSpriteBytes,
    this.threadSpoolSpriteBytes,
    this.materialAtlasBytes,
    this.toolAtlasBytes,
    this.materialPackArtBytes,
    this.mineralPackArtBytes,
    this.woodChipBundleArtBytes,
  });

  final StreetScrapGridSpec grid;
  final Map<String, StreetScrapObject> objects;
  final List<StreetScrapPlacement> placements;
  final String? selectedInstanceId;
  final int cursorX;
  final int cursorY;
  final bool enabled;
  final void Function(int x, int y) onEmptyCellTap;
  final void Function(String instanceId, int x, int y) onOccupiedCellTap;
  final void Function(String instanceId, int x, int y) onDrop;
  final Uint8List? woodBoardSpriteBytes;
  final Uint8List? threadSpoolSpriteBytes;
  final Uint8List? materialAtlasBytes;
  final Uint8List? toolAtlasBytes;
  final Uint8List? materialPackArtBytes;
  final Uint8List? mineralPackArtBytes;
  final Uint8List? woodChipBundleArtBytes;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final cellSize = constraints.maxWidth / grid.width;
      return SizedBox(
        height: cellSize * grid.height,
        child: Stack(
          children: [
            GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: grid.width,
              ),
              itemCount: grid.width * grid.height,
              itemBuilder: (context, index) {
                final x = index % grid.width;
                final y = index ~/ grid.width;
                final cursor = x == cursorX && y == cursorY;
                final occupied = _isOccupied(x, y);
                final strings = StreetScrapLocalizations.of(context);
                final gridName = strings.text(
                  grid.id == 'board'
                      ? 'board.gridNameWorking'
                      : 'board.gridNameBackpack',
                );
                return Semantics(
                  container: true,
                  excludeSemantics: occupied,
                  button: !occupied,
                  enabled: enabled && !occupied,
                  onTap: enabled && !occupied
                      ? () => onEmptyCellTap(x, y)
                      : null,
                  label: strings.text(
                    'board.cellSemantics',
                    arguments: {
                      'grid': gridName,
                      'row': '${y + 1}',
                      'column': '${x + 1}',
                      'state': strings.text(
                        occupied ? 'board.cellOccupied' : 'board.cellEmpty',
                      ),
                      'cursor': cursor ? strings.text('board.cellCursor') : '',
                    },
                  ),
                  hint: !occupied && enabled
                      ? strings.text('board.cellHint')
                      : null,
                  child: ExcludeSemantics(
                    child: DragTarget<String>(
                      onAcceptWithDetails: enabled
                          ? (details) => onDrop(details.data, x, y)
                          : null,
                      builder: (context, candidateData, rejectedData) {
                        final isDropTarget = candidateData.isNotEmpty;
                        return InkWell(
                          key: Key('street-scrap-cell-${grid.id}-$x-$y'),
                          onTap: enabled ? () => onEmptyCellTap(x, y) : null,
                          child: Container(
                            margin: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: isDropTarget
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer
                                  : Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(
                                color: cursor || isDropTarget
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context)
                                          .colorScheme
                                          .outlineVariant
                                          .withValues(alpha: .55),
                                width: cursor || isDropTarget ? 2.5 : 1,
                              ),
                              boxShadow: isDropTarget || cursor
                                  ? const []
                                  : [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: .12,
                                        ),
                                        blurRadius: 3,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
            for (final placement in placements)
              _positionedItem(context, placement, cellSize),
          ],
        ),
      );
    },
  );

  Widget _positionedItem(
    BuildContext context,
    StreetScrapPlacement placement,
    double cellSize,
  ) {
    final strings = StreetScrapLocalizations.of(context);
    final item = objects[placement.instanceId]!;
    final footprint = item.footprint.rotated(placement.rotation);
    final selected = item.instanceId == selectedInstanceId;
    return Positioned(
      left: placement.x * cellSize + 2,
      top: placement.y * cellSize + 2,
      width: footprint.width * cellSize - 4,
      height: footprint.height * cellSize - 4,
      child: Semantics(
        key: ValueKey('street-scrap-object-${item.instanceId}'),
        container: true,
        button: true,
        enabled: enabled,
        selected: selected,
        label: strings.text(
          'board.objectSemantics',
          arguments: {
            'grid': strings.text(
              placement.gridId == 'board'
                  ? 'board.gridNameWorking'
                  : 'board.gridNameBackpack',
            ),
            'row': '${placement.y + 1}',
            'column': '${placement.x + 1}',
            'name': strings.itemName(item.itemId),
            'source': strings.itemSource(item.source),
            'quality': strings.itemQuality(item.quality),
            'width': '${footprint.width}',
            'height': '${footprint.height}',
          },
        ),
        hint: enabled ? strings.text('board.objectHint') : null,
        onTap: enabled
            ? () => onOccupiedCellTap(item.instanceId, placement.x, placement.y)
            : null,
        child: ExcludeSemantics(
          child: Draggable<String>(
            data: item.instanceId,
            maxSimultaneousDrags: enabled ? 1 : 0,
            feedback: Material(
              elevation: 8,
              color: Theme.of(context).colorScheme.primaryContainer,
              child: SizedBox(
                width: footprint.width * cellSize - 4,
                height: footprint.height * cellSize - 4,
                child: Center(
                  child: Text(
                    strings.itemName(item.itemId),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            childWhenDragging: Opacity(
              opacity: 0.35,
              child: _itemTile(context, item, placement, selected, cellSize),
            ),
            child: _itemTile(context, item, placement, selected, cellSize),
          ),
        ),
      ),
    );
  }

  bool _isOccupied(int x, int y) {
    for (final placement in placements) {
      if (placement.gridId != grid.id) continue;
      final item = objects[placement.instanceId];
      if (item == null) continue;
      final footprint = item.footprint.rotated(placement.rotation);
      if (x >= placement.x &&
          x < placement.x + footprint.width &&
          y >= placement.y &&
          y < placement.y + footprint.height) {
        return true;
      }
    }
    return false;
  }

  Widget _itemTile(
    BuildContext context,
    StreetScrapObject item,
    StreetScrapPlacement placement,
    bool selected,
    double cellSize,
  ) {
    final footprint = item.footprint.rotated(placement.rotation);
    return Material(
      color: selected
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.tertiaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outline,
          width: selected ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('street-scrap-item-${item.instanceId}'),
        onTap: enabled
            ? () => onOccupiedCellTap(item.instanceId, placement.x, placement.y)
            : null,
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Center(
            child: StreetScrapItemSprite(
              itemId: item.itemId,
              source: item.source,
              contentItemId: item.containerState['contentItemId'] as String?,
              woodBoardSpriteBytes: woodBoardSpriteBytes,
              threadSpoolSpriteBytes: threadSpoolSpriteBytes,
              materialAtlasBytes: materialAtlasBytes,
              toolAtlasBytes: toolAtlasBytes,
              materialPackArtBytes: materialPackArtBytes,
              mineralPackSpriteBytes: mineralPackArtBytes,
              woodChipBundleSpriteBytes: woodChipBundleArtBytes,
              // Scale art to the item's usable footprint, not one grid cell.
              // Large objects (crates, boards) should visually fill their tile;
              // narrow objects still stay within their shorter dimension.
              size:
                  ((footprint.width < footprint.height
                                  ? footprint.width
                                  : footprint.height) *
                              cellSize -
                          4)
                      .clamp(24, 320)
                      .toDouble(),
              // Let the pixel art lead the interaction; item names remain
              // available from selection details and accessibility labels.
              visualScale: 1.28,
            ),
          ),
        ),
      ),
    );
  }
}

class _ObjectListTile extends StatelessWidget {
  const _ObjectListTile({
    super.key,
    required this.item,
    required this.selected,
    required this.enabled,
    required this.onTap,
    required this.onDragUpdate,
    this.subtitle,
    this.woodBoardSpriteBytes,
    this.threadSpoolSpriteBytes,
    this.materialAtlasBytes,
    this.toolAtlasBytes,
    this.materialPackArtBytes,
    this.mineralPackArtBytes,
    this.woodChipBundleArtBytes,
  });

  final StreetScrapObject item;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final void Function(DragUpdateDetails details) onDragUpdate;
  final String? subtitle;
  final Uint8List? woodBoardSpriteBytes;
  final Uint8List? threadSpoolSpriteBytes;
  final Uint8List? materialAtlasBytes;
  final Uint8List? toolAtlasBytes;
  final Uint8List? materialPackArtBytes;
  final Uint8List? mineralPackArtBytes;
  final Uint8List? woodChipBundleArtBytes;

  @override
  Widget build(BuildContext context) {
    final strings = StreetScrapLocalizations.of(context);
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      selected: selected,
      label: strings.text(
        'board.itemSemantics',
        arguments: {
          'name': strings.itemName(item.itemId),
          'source': strings.itemSource(item.source),
          'quality': strings.itemQuality(item.quality),
          'width': '${item.footprint.width}',
          'height': '${item.footprint.height}',
          'extra': subtitle == null
              ? ''
              : strings.text(
                  'board.itemSemanticsExtra',
                  arguments: {'subtitle': subtitle!},
                ),
        },
      ),
      hint: enabled ? strings.text('board.itemHint') : null,
      onTap: enabled ? onTap : null,
      child: ExcludeSemantics(
        child: LongPressDraggable<String>(
          data: item.instanceId,
          maxSimultaneousDrags: enabled ? 1 : 0,
          onDragUpdate: onDragUpdate,
          feedback: Material(
            elevation: 8,
            child: SizedBox(width: 260, child: _card(context, enabled: false)),
          ),
          childWhenDragging: Opacity(opacity: 0.35, child: _card(context)),
          child: _card(context),
        ),
      ),
    );
  }

  Widget _card(BuildContext context, {bool enabled = true}) => Card(
    color: selected ? Theme.of(context).colorScheme.primaryContainer : null,
    child: ListTile(
      enabled: enabled && this.enabled,
      onTap: enabled && this.enabled ? onTap : null,
      leading: StreetScrapItemSprite(
        itemId: item.itemId,
        source: item.source,
        contentItemId: item.containerState['contentItemId'] as String?,
        woodBoardSpriteBytes: woodBoardSpriteBytes,
        threadSpoolSpriteBytes: threadSpoolSpriteBytes,
        materialAtlasBytes: materialAtlasBytes,
        toolAtlasBytes: toolAtlasBytes,
        materialPackArtBytes: materialPackArtBytes,
        mineralPackSpriteBytes: mineralPackArtBytes,
        woodChipBundleSpriteBytes: woodChipBundleArtBytes,
        size: 36,
      ),
      title: Text(StreetScrapLocalizations.of(context).itemName(item.itemId)),
      subtitle: Text(
        subtitle ??
            StreetScrapLocalizations.of(context).text(
              'board.itemMetadata',
              arguments: {
                'source': StreetScrapLocalizations.of(
                  context,
                ).itemSource(item.source),
                'quality': StreetScrapLocalizations.of(
                  context,
                ).itemQuality(item.quality),
              },
            ),
      ),
      trailing: Text('${item.footprint.width}×${item.footprint.height}'),
    ),
  );
}

class _StreetScrapMoveUndo {
  const _StreetScrapMoveUndo({
    required this.instanceId,
    required this.previousPlacement,
    required this.previousStorageId,
    required this.expectedRevision,
  });

  final String instanceId;
  final StreetScrapPlacement? previousPlacement;
  final String? previousStorageId;
  final int expectedRevision;
}

bool _streetScrapIsProcessed(
  StreetScrapObject item,
  StreetScrapLocalizations strings,
) => strings.itemSource(item.source) == strings.text('board.itemSourceCrafted');

class _StreetScrapHudChip extends StatelessWidget {
  const _StreetScrapHudChip({
    required this.icon,
    required this.value,
    this.progress,
  });

  final IconData icon;
  final String value;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 38),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: colors.primary),
          const SizedBox(width: 4),
          if (value.isNotEmpty)
            Text(value, style: Theme.of(context).textTheme.labelLarge),
          if (progress != null) ...[
            const SizedBox(width: 6),
            SizedBox(
              width: 24,
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
