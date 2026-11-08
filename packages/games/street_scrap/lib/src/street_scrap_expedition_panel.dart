import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'street_scrap_expedition.dart';
import 'street_scrap_silhouette_dialog.dart';
import 'street_scrap_localizations.dart';
import 'street_scrap_inventory.dart';
import 'street_scrap_progress.dart';
import 'street_scrap_audio.dart';
import 'street_scrap_item_sprite.dart';
import 'street_scrap_protagonist_sprite.dart';
import 'street_scrap_module.dart';

class StreetScrapExpeditionPanel extends StatefulWidget {
  const StreetScrapExpeditionPanel({
    super.key,
    required this.session,
    required this.catalog,
    required this.rules,
    required this.maxStamina,
    required this.onInventoryChanged,
    this.onOrganizeBackpack,
    this.onSound,
    this.woodBoardSpriteBytes,
    this.threadSpoolSpriteBytes,
    this.materialAtlasBytes,
    this.toolAtlasBytes,
    this.materialPackArtBytes,
    this.mineralPackSpriteBytes,
    this.woodChipBundleSpriteBytes,
    this.protagonistArt,
  });

  final StreetScrapSession session;
  final StreetScrapInventoryCatalog catalog;
  final StreetScrapExpeditionRules rules;
  final int maxStamina;
  final VoidCallback onInventoryChanged;
  final Future<void> Function()? onOrganizeBackpack;
  final ValueChanged<StreetScrapAudioCue>? onSound;
  final Uint8List? woodBoardSpriteBytes;
  final Uint8List? threadSpoolSpriteBytes;
  final Uint8List? materialAtlasBytes;
  final Uint8List? toolAtlasBytes;
  final Uint8List? materialPackArtBytes;
  final Uint8List? mineralPackSpriteBytes;
  final Uint8List? woodChipBundleSpriteBytes;
  final StreetScrapProtagonistArt? protagonistArt;

  @override
  State<StreetScrapExpeditionPanel> createState() =>
      _StreetScrapExpeditionPanelState();
}

class _StreetScrapExpeditionPanelState
    extends State<StreetScrapExpeditionPanel> {
  int _classificationPage = 0;
  final _routeActionsKey = GlobalKey();
  Map<String, StreetScrapGridSpec> get _grids =>
      streetScrapGridSpecsForState(widget.session.snapshot.state);
  bool _busy = false;
  String? _error;
  bool _needsBackpackSpace = false;
  int? _activityPose;
  Timer? _activityPoseTimer;

  StreetScrapExpedition? get _expedition {
    final raw = widget.session.snapshot.state['expedition'];
    if (raw == null) return null;
    if (raw is! Map) throw const FormatException('探索存檔格式錯誤。');
    final expedition = StreetScrapExpedition.fromJson(
      Map<String, Object?>.from(raw),
    );
    expedition.validateAgainst(widget.rules);
    return expedition;
  }

  int get _stamina =>
      widget.session.snapshot.state['stamina'] as int? ?? widget.maxStamina;

  Map<String, bool> get _tutorialTasks {
    final raw = widget.session.snapshot.state['tutorialTasks'];
    if (raw == null) return const {};
    if (raw is! Map || raw.values.any((value) => value is! bool)) {
      throw const FormatException('教學任務存檔格式錯誤。');
    }
    return {
      for (final entry in raw.entries) entry.key as String: entry.value as bool,
    };
  }

  Map<String, String> get _recyclingClassifications {
    final raw = widget.session.snapshot.state['recyclingClassifications'];
    if (raw == null) return const {};
    if (raw is! Map ||
        raw.entries.any(
          (entry) =>
              entry.key is! String ||
              !streetScrapRecyclingCategories.containsKey(entry.value),
        )) {
      throw const FormatException('回收分類存檔格式錯誤。');
    }
    return {
      for (final entry in raw.entries)
        entry.key as String: entry.value as String,
    };
  }

  StreetScrapInventory get _inventory {
    final raw = widget.session.snapshot.state['inventory'];
    if (raw == null) return widget.catalog.emptyInventory(grids: _grids);
    if (raw is! Map) throw const FormatException('背包存檔格式錯誤。');
    return widget.catalog.inventoryFromJson(
      grids: _grids,
      json: Map<String, Object?>.from(raw),
    );
  }

  List<String> _deliveryCandidates(String itemId) {
    final inventory = _inventory;
    return inventory.placements.values
        .where((placement) => placement.gridId == 'backpack')
        .map((placement) => placement.instanceId)
        .where((id) => inventory.objects[id]?.itemId == itemId)
        .take(2)
        .toList(growable: false);
  }

  List<StreetScrapObject> get _classifiableBackpackItems {
    final inventory = _inventory;
    return inventory.placements.values
        .where((placement) => placement.gridId == 'backpack')
        .map((placement) => inventory.objects[placement.instanceId]!)
        .where(
          (item) => streetScrapRecyclingCategoryForItem(item.itemId) != null,
        )
        .toList(growable: false);
  }

  ({int number, int total}) _classificationSamplePosition(
    StreetScrapObject item,
  ) {
    final siblings = _classifiableBackpackItems
        .where((candidate) => candidate.itemId == item.itemId)
        .toList(growable: false);
    return (
      number:
          siblings.indexWhere(
            (candidate) => candidate.instanceId == item.instanceId,
          ) +
          1,
      total: siblings.length,
    );
  }

  Widget _classificationSampleIcon(StreetScrapObject item, {double size = 64}) {
    final position = _classificationSamplePosition(item);
    final isTutorialSample = streetScrapRecyclingTutorialSamples.containsKey(
      item.instanceId,
    );
    final sprite = StreetScrapItemSprite(
      itemId: item.itemId,
      source: item.source,
      size: size,
      woodBoardSpriteBytes: widget.woodBoardSpriteBytes,
      threadSpoolSpriteBytes: widget.threadSpoolSpriteBytes,
      materialAtlasBytes: widget.materialAtlasBytes,
      toolAtlasBytes: widget.toolAtlasBytes,
      materialPackArtBytes: widget.materialPackArtBytes,
      mineralPackSpriteBytes: widget.mineralPackSpriteBytes,
      woodChipBundleSpriteBytes: widget.woodChipBundleSpriteBytes,
      visualScale: streetScrapOfflineFallbackAssetFor(item.itemId) == null
          ? 1.24
          : 1.0,
    );
    if (position.total < 2 && !isTutorialSample) return sprite;
    final strings = StreetScrapLocalizations.of(context);
    final sampleLabel = <String>[
      strings.itemName(item.itemId),
      if (position.total > 1) '${position.number} of ${position.total}',
      if (isTutorialSample) strings.text('expedition.tutorialSample'),
    ].join(' · ');
    return Semantics(
      label: sampleLabel,
      image: true,
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: sprite),
              if (isTutorialSample)
                Positioned(
                  top: -5,
                  right: -5,
                  child: Tooltip(
                    message: strings.text('expedition.tutorialSample'),
                    child: ExcludeSemantics(
                      child: DecoratedBox(
                        key: Key(
                          'street-scrap-tutorial-sample-badge-${item.instanceId}',
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.tertiaryContainer,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.surface,
                            width: 1.5,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(3),
                          child: Icon(
                            Icons.school_outlined,
                            size: 16,
                            color: Theme.of(
                              context,
                            ).colorScheme.onTertiaryContainer,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: -5,
                bottom: -4,
                child: Tooltip(
                  message: '${position.number}/${position.total}',
                  child: ExcludeSemantics(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.surface,
                          width: 1.5,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        child: Text(
                          '${position.number}/${position.total}',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontSize: 9,
                                height: 1,
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
    );
  }

  IconData _recyclingCategoryIcon(String category) => switch (category) {
    'paper' => Icons.newspaper_rounded,
    'metal' => Icons.hardware_rounded,
    'cloth' => Icons.texture_rounded,
    'plastic' => Icons.recycling_rounded,
    _ => Icons.category_rounded,
  };

  List<StreetScrapObject> get _intactMaterialCandidates {
    final inventory = _inventory;
    return inventory.placements.values
        .where(
          (placement) =>
              placement.gridId == 'backpack' || placement.gridId == 'board',
        )
        .map((placement) => inventory.objects[placement.instanceId]!)
        .where(
          (item) =>
              item.source == 'fixed:metal_recycling_rack' &&
              const {'metal.sheet', 'wood.board'}.contains(item.itemId),
        )
        .toList(growable: false);
  }

  Future<void> _classifySample(StreetScrapObject item) async {
    final strings = StreetScrapLocalizations.of(context);
    final current = _recyclingClassifications[item.instanceId];
    final position = _classificationSamplePosition(item);
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            _classificationSampleIcon(item, size: 76),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                strings.itemName(item.itemId),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (position.total > 1) ...[
              const SizedBox(width: 8),
              Text(
                '${position.number}/${position.total}',
                key: Key(
                  'street-scrap-classification-dialog-sample-${position.number}',
                ),
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ],
        ),
        content: SizedBox(
          width: 320,
          child: GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.2,
            children: [
              for (final entry in streetScrapRecyclingCategories.entries)
                Semantics(
                  button: true,
                  selected: current == entry.key,
                  label: strings.text(
                    'expedition.recyclingCategory.${entry.key}',
                  ),
                  child: Material(
                    color: current == entry.key
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(18),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      key: Key(
                        'street-scrap-classification-category-${entry.key}',
                      ),
                      onTap: () => Navigator.pop(context, entry.key),
                      child: Stack(
                        children: [
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _recyclingCategoryIcon(entry.key),
                                  size: 38,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  strings.text(
                                    'expedition.recyclingCategory.${entry.key}',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (current == entry.key)
                            const Positioned(
                              top: 7,
                              right: 7,
                              child: Icon(Icons.check_circle_rounded),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(strings.text('expedition.cancel')),
          ),
        ],
      ),
    );
    if (selected == null || !mounted) return;
    await _run(() async {
      await classifyStreetScrapRecyclingSample(
        session: widget.session,
        commandId: 'recycling-sort-${DateTime.now().microsecondsSinceEpoch}',
        expectedRevision: widget.session.snapshot.revision,
        catalog: widget.catalog,
        grids: _grids,
        backpackGridId: 'backpack',
        instanceId: item.instanceId,
        category: selected,
      );
      widget.onInventoryChanged();
    });
  }

  Future<void> _claimRecyclingSamples() => _run(() async {
    await claimStreetScrapRecyclingSamples(
      session: widget.session,
      commandId: 'recycling-samples-${DateTime.now().microsecondsSinceEpoch}',
      expectedRevision: widget.session.snapshot.revision,
      catalog: widget.catalog,
      grids: _grids,
      backpackGridId: 'backpack',
    );
    widget.onInventoryChanged();
  });

  Future<void> _claimSewingKit() => _run(() async {
    await claimStreetScrapSewingTutorialKit(
      session: widget.session,
      commandId: 'sewing-kit-${DateTime.now().microsecondsSinceEpoch}',
      expectedRevision: widget.session.snapshot.revision,
      catalog: widget.catalog,
      grids: _grids,
      backpackGridId: 'backpack',
    );
    widget.onInventoryChanged();
  });

  Future<void> _chooseIntactMaterial(
    StreetScrapObject item,
    String choice,
  ) async {
    final strings = StreetScrapLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.text('expedition.intactMaterialTitle')),
        content: Text(
          '${strings.itemName(item.itemId)}・${strings.text('expedition.fixedRackQuality', arguments: {'quality': '${item.quality}'})}\n'
          '${strings.text(choice == 'keep' ? 'expedition.keepSourceQuality' : 'expedition.deliverIntact')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.text('expedition.return')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              strings.text(
                choice == 'keep'
                    ? 'expedition.confirmKeep'
                    : 'expedition.confirmDeliver',
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() async {
      await chooseStreetScrapIntactMaterial(
        session: widget.session,
        commandId: 'intact-choice-${DateTime.now().microsecondsSinceEpoch}',
        expectedRevision: widget.session.snapshot.revision,
        catalog: widget.catalog,
        grids: _grids,
        instanceId: item.instanceId,
        choice: choice,
      );
      widget.onInventoryChanged();
    });
  }

  Future<void> _deliverTutorialMaterials(String itemId) async {
    final strings = StreetScrapLocalizations.of(context);
    final ids = _deliveryCandidates(itemId);
    if (ids.length < 2) return;
    final inventory = _inventory;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final wideDialog = MediaQuery.sizeOf(context).width >= 560;
        return AlertDialog(
          title: Text(strings.text('expedition.confirmTutorialDelivery')),
          content: SizedBox(
            width: wideDialog ? 380 : null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    for (var index = 0; index < ids.length; index++) ...[
                      if (index > 0) const SizedBox(width: 8),
                      Expanded(
                        child: _TutorialDeliveryItemCard(
                          item: inventory.objects[ids[index]]!,
                          number: index + 1,
                          artSize: wideDialog ? 112 : 104,
                          localizations: strings,
                          woodBoardSpriteBytes: widget.woodBoardSpriteBytes,
                          threadSpoolSpriteBytes: widget.threadSpoolSpriteBytes,
                          materialAtlasBytes: widget.materialAtlasBytes,
                          toolAtlasBytes: widget.toolAtlasBytes,
                          materialPackArtBytes: widget.materialPackArtBytes,
                          mineralPackSpriteBytes: widget.mineralPackSpriteBytes,
                          woodChipBundleSpriteBytes:
                              widget.woodChipBundleSpriteBytes,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 18,
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            strings.text('expedition.deliveryConsumesItems'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSecondaryContainer,
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
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(strings.text('expedition.cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(strings.text('expedition.confirmTutorialDelivery')),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    await _run(() async {
      await deliverStreetScrapTutorialMaterials(
        session: widget.session,
        commandId: 'tutorial-deliver-${DateTime.now().microsecondsSinceEpoch}',
        expectedRevision: widget.session.snapshot.revision,
        catalog: widget.catalog,
        grids: _grids,
        backpackGridId: 'backpack',
        eligibleItemIds: [itemId],
        quantity: 2,
      );
      widget.onInventoryChanged();
    });
  }

  Future<void> _start() => _run(() async {
    final micros = DateTime.now().microsecondsSinceEpoch;
    await startStreetScrapExpeditionCommand(
      session: widget.session,
      commandId: 'expedition-start-$micros',
      expectedRevision: widget.session.snapshot.revision,
      phase: widget.session.snapshot.state['chapter'] as int? ?? 0,
      seed: micros & 0x7fffffff,
      defaultStamina: widget.maxStamina,
      rules: widget.rules,
    );
    widget.onInventoryChanged();
  }, activityPose: 1);

  Future<void> _claimStarterVessels() => _run(() async {
    await claimStreetScrapStarterVessels(
      session: widget.session,
      commandId: 'q0-starter-vessels-${widget.session.snapshot.revision}',
      expectedRevision: widget.session.snapshot.revision,
      catalog: widget.catalog,
      grids: _grids,
      backpackGridId: 'backpack',
    );
    widget.onInventoryChanged();
  });

  Future<void> _move() => _run(() async {
    final current = _expedition!;
    await _transition('move', current.move(widget.rules));
  }, activityPose: 1);

  Future<void> _return() => _run(() async {
    final current = _expedition!;
    await _transition('return', current.returnHome());
  }, activityPose: 1);

  Future<void> _surveyFixed() async {
    final current = _expedition;
    if (current == null) return;
    final strings = StreetScrapLocalizations.of(context);
    final location = widget.rules.locationFor(current.phase, current.nodeIndex);
    final selectedOption = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        var page = 0;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final screenHeight = MediaQuery.sizeOf(sheetContext).height;
            const pageSize = 4;
            final pageCount = (location.options.length / pageSize).ceil();
            final cardExtent =
                ((screenHeight * 0.76 - (pageCount > 1 ? 148 : 94)) / 2)
                    .clamp(88.0, 200.0)
                    .toDouble();
            final artSize = cardExtent - 58;
            return SafeArea(
              child: SizedBox(
                height: screenHeight * 0.76,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 34,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              sheetContext,
                            ).colorScheme.outlineVariant,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        strings.text('expedition.chooseMaterial'),
                        style: Theme.of(sheetContext).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      GridView.builder(
                        key: const Key('street-scrap-expedition-material-grid'),
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: (location.options.length - page * pageSize)
                            .clamp(0, pageSize),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          mainAxisExtent: cardExtent,
                        ),
                        itemBuilder: (context, index) {
                          final optionIndex = page * pageSize + index;
                          final option = location.options[optionIndex];
                          final name = strings.itemName(option.itemId);
                          return Semantics(
                            button: true,
                            label: '$name, ${option.quantity}',
                            child: Material(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainer,
                              borderRadius: BorderRadius.circular(16),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                key: Key(
                                  'street-scrap-expedition-material-option-$optionIndex',
                                ),
                                onTap: () =>
                                    Navigator.pop(context, optionIndex),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    10,
                                    8,
                                    10,
                                    8,
                                  ),
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: ExcludeSemantics(
                                          child: StreetScrapItemSprite(
                                            itemId: option.itemId,
                                            source: 'found:expedition',
                                            size: artSize,
                                            visualScale: 1.3,
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
                                                widget.mineralPackSpriteBytes,
                                            woodChipBundleSpriteBytes: widget
                                                .woodChipBundleSpriteBytes,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.labelLarge,
                                      ),
                                      const SizedBox(height: 4),
                                      DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.secondaryContainer,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 9,
                                            vertical: 2,
                                          ),
                                          child: Text(
                                            '×${option.quantity}',
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
                            ),
                          );
                        },
                      ),
                      if (pageCount > 1) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              key: const Key(
                                'street-scrap-expedition-material-previous-page',
                              ),
                              tooltip: strings.text('board.previousPage'),
                              onPressed: page == 0
                                  ? null
                                  : () => setSheetState(() => page--),
                              icon: const Icon(Icons.chevron_left),
                            ),
                            Text(
                              strings.text(
                                'board.pageCount',
                                arguments: {
                                  'current': '${page + 1}',
                                  'total': '$pageCount',
                                },
                              ),
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                            IconButton(
                              key: const Key(
                                'street-scrap-expedition-material-next-page',
                              ),
                              tooltip: strings.text('board.nextPage'),
                              onPressed: page + 1 >= pageCount
                                  ? null
                                  : () => setSheetState(() => page++),
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    if (selectedOption == null || !mounted) return;
    final clueSlot = current.targetSilhouetteIndex;
    final silhouette = await showDialog<int>(
      context: context,
      builder: (context) => StreetScrapSilhouetteSurveyDialog(
        clueSlot: clueSlot,
        materialItemId: location.options[selectedOption].itemId,
        materialLabel: strings.itemName(
          location.options[selectedOption].itemId,
        ),
      ),
    );
    if (silhouette == null || !mounted) return;
    await _run(() async {
      final fresh = _expedition!;
      final isCorrect = silhouette == fresh.targetSilhouetteIndex;
      final result = fresh.investigateFixed(
        rules: widget.rules,
        optionIndex: selectedOption,
        selectedVisibleTarget: isCorrect,
      );
      await _transition('fixed-survey', result.expedition);
      widget.onSound?.call(
        isCorrect ? StreetScrapAudioCue.discovery : StreetScrapAudioCue.miss,
      );
    }, activityPose: 2);
  }

  Future<void> _surveySurprise() => _run(() async {
    final result = _expedition!.investigateSurprise(widget.rules);
    await _transition('surprise-survey', result.expedition);
    widget.onSound?.call(StreetScrapAudioCue.discovery);
  }, activityPose: 2);

  Future<void> _claim() => _run(() async {
    final strings = StreetScrapLocalizations.of(context);
    final expedition = _expedition!;
    final vessels = _inventory.objects.values
        .where(
          (item) =>
              const {
                'container.clean',
                'container.clean_jar',
                'container.used_intact',
              }.contains(item.itemId) &&
              item.containerState['contentItemId'] == null &&
              item.containerState['cleanliness'] == 'clean' &&
              _inventory.placements.containsKey(item.instanceId),
        )
        .toList(growable: false);
    final assignments = <int, String>{};
    final selectedVessels = <String>{};
    for (var index = 0; index < expedition.pendingRewards.length; index++) {
      final reward = expedition.pendingRewards[index];
      if (reward['itemId'] != 'water.mineral') continue;
      final available = vessels
          .where((item) => !selectedVessels.contains(item.instanceId))
          .toList(growable: false);
      if (available.isEmpty) {
        throw StateError('noCleanEmptyBottle');
      }
      final vesselId = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(strings.text('expedition.chooseBottle')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                strings.text(
                  'expedition.mineralQuality',
                  arguments: {'quality': '${reward['quality']}'},
                ),
              ),
              const SizedBox(height: 8),
              for (
                var vesselIndex = 0;
                vesselIndex < available.length;
                vesselIndex++
              )
                Builder(
                  builder: (context) {
                    final vessel = available[vesselIndex];
                    return ListTile(
                      title: Text(
                        strings.text(
                          'expedition.vesselOption',
                          arguments: {
                            'item': strings.itemName(vessel.itemId),
                            'source': strings.itemSource(vessel.source),
                            'number': '${vesselIndex + 1}',
                          },
                        ),
                      ),
                      subtitle: Text(
                        strings.text(
                          'expedition.vesselQuality',
                          arguments: {'quality': '${vessel.quality}'},
                        ),
                      ),
                      onTap: () => Navigator.pop(context, vessel.instanceId),
                    );
                  },
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(strings.text('expedition.cancelClaim')),
            ),
          ],
        ),
      );
      if (vesselId == null || !mounted) return;
      assignments[index] = vesselId;
      selectedVessels.add(vesselId);
    }
    await claimStreetScrapExpeditionRewards(
      session: widget.session,
      commandId: 'expedition-claim-${DateTime.now().microsecondsSinceEpoch}',
      expectedRevision: widget.session.snapshot.revision,
      rules: widget.rules,
      catalog: widget.catalog,
      grids: _grids,
      backpackGridId: 'backpack',
      mineralWaterVessels: assignments,
    );
    widget.onInventoryChanged();
    widget.onSound?.call(StreetScrapAudioCue.pickup);
  });

  Future<void> _discardReward(
    int rewardIndex,
    Map<String, Object?> reward,
  ) async {
    final strings = StreetScrapLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.text('expedition.confirmDiscard')),
        content: Text(
          strings.text(
            'expedition.discardPrompt',
            arguments: {
              'item': strings.itemName(reward['itemId']! as String),
              'quantity': '${reward['quantity']}',
              'quality': '${reward['quality']}',
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.text('expedition.keepReward')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.text('expedition.confirmDiscardAction')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() async {
      await discardStreetScrapExpeditionReward(
        session: widget.session,
        commandId:
            'expedition-discard-${DateTime.now().microsecondsSinceEpoch}',
        expectedRevision: widget.session.snapshot.revision,
        rules: widget.rules,
        rewardIndex: rewardIndex,
      );
    });
  }

  Future<void> _transition(String kind, StreetScrapExpedition next) async {
    await applyStreetScrapExpeditionCommand(
      session: widget.session,
      commandId: 'expedition-$kind-${DateTime.now().microsecondsSinceEpoch}',
      expectedRevision: widget.session.snapshot.revision,
      rules: widget.rules,
      transition: (_) => next,
    );
    widget.onInventoryChanged();
    if (kind == 'move') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final actionContext = _routeActionsKey.currentContext;
        if (mounted && actionContext != null) {
          Scrollable.ensureVisible(
            actionContext,
            alignment: 0.8,
            duration: const Duration(milliseconds: 180),
          );
        }
      });
    }
  }

  Future<void> _run(
    Future<void> Function() action, {
    int activityPose = 3,
  }) async {
    if (_busy || widget.session.isReadOnly) return;
    _activityPoseTimer?.cancel();
    setState(() {
      _busy = true;
      _error = null;
      _needsBackpackSpace = false;
      _activityPose = MediaQuery.disableAnimationsOf(context)
          ? null
          : activityPose;
    });
    try {
      await action();
    } on Object catch (error) {
      if (mounted) {
        final message = error.toString();
        setState(() {
          _error = _friendlyError(error);
          _needsBackpackSpace = message.contains('No fitting space');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _activityPoseTimer = Timer(const Duration(milliseconds: 700), () {
          if (!mounted) return;
          setState(() => _activityPose = null);
        });
      }
    }
  }

  @override
  void dispose() {
    _activityPoseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    try {
      return _buildPanel(context);
    } on FormatException {
      final strings = StreetScrapLocalizations.of(context);
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Text(strings.text('expedition.error.malformedSave')),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildPanel(BuildContext context) {
    final strings = StreetScrapLocalizations.of(context);
    final expedition = _expedition;
    final currentLocation = expedition == null
        ? null
        : widget.rules.locationFor(expedition.phase, expedition.nodeIndex);
    final nodeInvestigated =
        expedition != null &&
        expedition.investigated.contains(expedition.nodeIndex);
    final pending =
        expedition?.pendingRewards ?? const <Map<String, Object?>>[];
    final tasks = _tutorialTasks;
    final classifications = _recyclingClassifications;
    final chapter = widget.session.snapshot.state['chapter'] as int? ?? 0;
    final samplesClaimed =
        widget.session.snapshot.state['recyclingSamplesClaimed'] == true;
    final sewingKitClaimed =
        widget.session.snapshot.state['q1.02KitClaimed'] == true;
    final intactCandidates = _intactMaterialCandidates;
    final rawSortedCategories =
        widget.session.snapshot.state['recyclingSortedCategories'];
    if (rawSortedCategories != null &&
        (rawSortedCategories is! List ||
            rawSortedCategories.any(
              (entry) =>
                  entry is! String ||
                  !streetScrapRecyclingCategories.containsKey(entry),
            ))) {
      throw const FormatException('回收分類進度存檔格式錯誤。');
    }
    final sortedCategories = <String>{
      if (rawSortedCategories is List) ...rawSortedCategories.cast<String>(),
    };
    final paperCount = _deliveryCandidates('paper.scrap').length;
    final ragCount = _deliveryCandidates('cloth.rag_piece').length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if ((expedition != null && !expedition.returned) ||
                        _activityPose != null)
                      SizedBox(
                        key: const Key('street-scrap-expedition-protagonist'),
                        height: 34,
                        child: StreetScrapProtagonistSprite(
                          pose: _activityPose ?? 2,
                          height: 34,
                          art: widget.protagonistArt,
                        ),
                      )
                    else
                      const Icon(Icons.explore_outlined),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        strings.text('expedition.title'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
                Text(
                  strings.text(
                    'expedition.stamina',
                    arguments: {
                      'current': '$_stamina',
                      'maximum': '${widget.maxStamina}',
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (widget.session.isReadOnly)
              Text(strings.text('expedition.readOnly')),
            if (_error != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                  if (_needsBackpackSpace && widget.onOrganizeBackpack != null)
                    Semantics(
                      key: const Key('street-scrap-open-backpack-organizer'),
                      button: true,
                      label: strings.text('expedition.organizeBackpack'),
                      child: IconButton.filledTonal(
                        tooltip: strings.text('expedition.organizeBackpack'),
                        onPressed: widget.session.isReadOnly
                            ? null
                            : () => widget.onOrganizeBackpack!.call(),
                        icon: const Icon(Icons.backpack_outlined),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            _phaseZeroRoute(context, strings, tasks),
            if (chapter == 0 &&
                tasks['q0.vesselsClaimed'] != true &&
                widget.catalog.footprints.containsKey('container.used_intact'))
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  key: const Key('street-scrap-claim-starter-vessels'),
                  onPressed: _busy || widget.session.isReadOnly
                      ? null
                      : _claimStarterVessels,
                  icon: const Icon(Icons.water_drop_outlined),
                  label: Text(strings.text('expedition.claimStarterVessels')),
                ),
              ),
            if (chapter == 0 && expedition == null)
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Semantics(
                  key: const Key('street-scrap-phase-zero-scene'),
                  label: strings.text('expedition.scene.description'),
                  image: true,
                  child: ExcludeSemantics(
                    child: SizedBox(
                      width: double.infinity,
                      height: (MediaQuery.sizeOf(context).height - 520).clamp(
                        140.0,
                        360.0,
                      ),
                      child: const ClipRRect(
                        borderRadius: BorderRadius.all(Radius.circular(18)),
                        child: CustomPaint(
                          painter: _StreetScavengingScenePainter(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (tasks['q0.01'] == true &&
                tasks['q0.02'] == true &&
                tasks['q0.03'] != true) ...[
              if (paperCount >= 2)
                OutlinedButton(
                  onPressed: _busy || widget.session.isReadOnly
                      ? null
                      : () => _deliverTutorialMaterials('paper.scrap'),
                  child: Text(strings.text('expedition.deliverPaper')),
                ),
              if (ragCount >= 2)
                OutlinedButton(
                  onPressed: _busy || widget.session.isReadOnly
                      ? null
                      : () => _deliverTutorialMaterials('cloth.rag_piece'),
                  child: Text(strings.text('expedition.deliverRags')),
                ),
              if (paperCount < 2 && ragCount < 2)
                Text(strings.text('expedition.materialsUnavailable')),
            ],
            if (chapter >= 1) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      strings.text('expedition.phaseOne'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  for (final category in streetScrapRecyclingCategories.keys)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Tooltip(
                        message: strings.text(
                          'expedition.recyclingCategory.$category',
                        ),
                        child: Semantics(
                          label: strings.text(
                            'expedition.recyclingCategory.$category',
                          ),
                          value: sortedCategories.contains(category)
                              ? strings.text('expedition.step.complete')
                              : null,
                          child: CircleAvatar(
                            radius: 17,
                            backgroundColor: sortedCategories.contains(category)
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                            child: Icon(
                              sortedCategories.contains(category)
                                  ? Icons.check_rounded
                                  : {
                                      'paper': Icons.newspaper_outlined,
                                      'metal': Icons.hardware_outlined,
                                      'cloth': Icons.texture_outlined,
                                      'plastic': Icons.recycling_outlined,
                                    }[category],
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (!samplesClaimed)
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton.filledTonal(
                    tooltip: strings.text('expedition.claimSortingSamples'),
                    onPressed: _busy || widget.session.isReadOnly
                        ? null
                        : _claimRecyclingSamples,
                    icon: const Icon(Icons.inventory_2_outlined),
                  ),
                ),
              if (_classifiableBackpackItems.isNotEmpty)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 820 ? 3 : 2;
                    // Keep mobile material art large and the panel short:
                    // show one row, then page horizontally through the rest.
                    final pageSize = columns == 3 ? 6 : 2;
                    final pageCount =
                        (_classifiableBackpackItems.length / pageSize).ceil();
                    final page = _classificationPage.clamp(0, pageCount - 1);
                    final pageItems = _classifiableBackpackItems
                        .skip(page * pageSize)
                        .take(pageSize)
                        .toList(growable: false);
                    final tileWidth =
                        (constraints.maxWidth - (columns - 1) * 10) / columns;
                    final tileHeight = constraints.maxWidth >= 820
                        ? 174.0
                        : 164.0;
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final item in pageItems)
                          SizedBox(
                            key: Key(
                              'street-scrap-classification-${item.instanceId}',
                            ),
                            width: tileWidth,
                            height: tileHeight,
                            child: Material(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: _busy || widget.session.isReadOnly
                                    ? null
                                    : () => _classifySample(item),
                                child: Stack(
                                  children: [
                                    Center(
                                      child: KeyedSubtree(
                                        key: Key(
                                          'street-scrap-classification-icon-${item.instanceId}',
                                        ),
                                        child: _classificationSampleIcon(
                                          item,
                                          size: tileHeight - 28,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      left: 8,
                                      right: 8,
                                      bottom: 6,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .surface
                                              .withValues(alpha: .84),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          child: Text(
                                            strings.itemName(item.itemId),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.labelLarge,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      right: 7,
                                      top: 7,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .surface
                                              .withValues(alpha: .86),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(5),
                                          child: Icon(
                                            classifications[item.instanceId] ==
                                                    null
                                                ? Icons.tune_rounded
                                                : Icons.check_rounded,
                                            size: 17,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        if (pageCount > 1)
                          SizedBox(
                            width: constraints.maxWidth,
                            height: 42,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  key: const Key(
                                    'street-scrap-classification-previous-page',
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  tooltip: strings.text('board.previousPage'),
                                  onPressed: page == 0
                                      ? null
                                      : () => setState(
                                          () => _classificationPage = page - 1,
                                        ),
                                  icon: const Icon(Icons.chevron_left_rounded),
                                ),
                                Text('${page + 1} / $pageCount'),
                                IconButton(
                                  key: const Key(
                                    'street-scrap-classification-next-page',
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  tooltip: strings.text('board.nextPage'),
                                  onPressed: page >= pageCount - 1
                                      ? null
                                      : () => setState(
                                          () => _classificationPage = page + 1,
                                        ),
                                  icon: const Icon(Icons.chevron_right_rounded),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
              if (tasks['q1.01'] == true)
                Text(strings.text('expedition.sortingComplete')),
              if (tasks['q1.01'] == true) ...[
                const Divider(),
                _tutorialTaskGroup(
                  key: 'sewing',
                  title: strings.text('expedition.sewingTitle'),
                  tasks: tasks,
                  items: [
                    (
                      'q1.02.unpicked',
                      strings.text('expedition.task.unpickThread'),
                    ),
                    (
                      'q1.02.threadReady',
                      strings.text('expedition.task.joinThread'),
                    ),
                    ('q1.02.sewn', strings.text('expedition.task.sewStrip')),
                  ],
                ),
                if (tasks['q1.02'] == true)
                  Text(strings.text('expedition.sewingComplete')),
                if (!sewingKitClaimed)
                  OutlinedButton.icon(
                    onPressed: _busy || widget.session.isReadOnly
                        ? null
                        : _claimSewingKit,
                    icon: const Icon(Icons.handyman_outlined),
                    label: Text(strings.text('expedition.claimSewingKit')),
                  ),
              ],
              if (tasks['q1.02'] == true) ...[
                const Divider(),
                _tutorialTaskRow(
                  'q1.03',
                  strings.text('expedition.task.intactMaterial'),
                  tasks,
                ),
                if (tasks['q1.03'] != true && intactCandidates.isNotEmpty)
                  for (final item in intactCandidates)
                    Card(
                      child: ListTile(
                        title: Text(
                          '${strings.itemName(item.itemId)}｜${strings.text('expedition.intactFound')}',
                        ),
                        subtitle: Text(
                          strings.text(
                            'expedition.fixedRackQuality',
                            arguments: {'quality': '${item.quality}'},
                          ),
                        ),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            TextButton(
                              onPressed: _busy || widget.session.isReadOnly
                                  ? null
                                  : () => _chooseIntactMaterial(item, 'keep'),
                              child: Text(strings.text('expedition.keep')),
                            ),
                            TextButton(
                              onPressed: _busy || widget.session.isReadOnly
                                  ? null
                                  : () =>
                                        _chooseIntactMaterial(item, 'deliver'),
                              child: Text(strings.text('expedition.deliver')),
                            ),
                          ],
                        ),
                      ),
                    ),
                if (tasks['q1.03'] != true && intactCandidates.isEmpty)
                  Text(strings.text('expedition.intactLessonHint')),
                if (tasks['q1.03'] == true)
                  Text(
                    strings.text(
                      'expedition.intactLessonComplete',
                      arguments: {
                        'choice': strings.text(
                          widget.session.snapshot.state['q1.03Choice'] == 'keep'
                              ? 'expedition.kept'
                              : 'expedition.delivered',
                        ),
                      },
                    ),
                  ),
              ],
            ],
            if (chapter >= 2) ...[
              const SizedBox(height: 12),
              _tutorialTaskGroup(
                key: 'phase-two',
                title: strings.text('expedition.phaseTwo'),
                tasks: tasks,
                items: [
                  ('q2.01', strings.text('expedition.task.castLine')),
                  ('q2.02', strings.text('expedition.task.landFish')),
                  ('q2.03', strings.text('expedition.task.chooseFishUse')),
                ],
              ),
            ],
            if (chapter >= 3) ...[
              const SizedBox(height: 12),
              _tutorialTaskGroup(
                key: 'phase-three',
                title: strings.text('expedition.phaseThree'),
                tasks: tasks,
                items: [
                  ('q3.01', strings.text('expedition.task.pressRod')),
                  ('q3.02', strings.text('expedition.task.nailBoard')),
                  ('q3.03', strings.text('expedition.task.repairTool')),
                  ('q3.04', strings.text('expedition.task.storeCrate')),
                  ('q3.05', strings.text('expedition.task.upgradeBagOptional')),
                ],
              ),
            ],
            if (chapter >= 4) ...[
              const SizedBox(height: 12),
              _tutorialTaskGroup(
                key: 'phase-four',
                title: strings.text('expedition.phaseFour'),
                tasks: tasks,
                items: [
                  ('q4.01', strings.text('expedition.task.filterWater')),
                  ('q4.02', strings.text('expedition.task.cookMeal')),
                  ('q4.03', strings.text('expedition.task.useOrDeliverMeal')),
                ],
              ),
            ],
            if (chapter >= 5) ...[
              const SizedBox(height: 12),
              _tutorialTaskGroup(
                key: 'phase-five',
                title: strings.text('expedition.phaseFive'),
                tasks: tasks,
                items: [
                  ('q5.01', strings.text('expedition.task.advancedOrders')),
                  ('q5.02', strings.text('expedition.task.stableLiving')),
                ],
              ),
            ],
            if (expedition == null || expedition.claimed)
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 54,
                      child: Semantics(
                        key: const Key('street-scrap-expedition-start'),
                        label: strings.text('expedition.start'),
                        button: true,
                        child: ExcludeSemantics(
                          child: FilledButton.icon(
                            onPressed:
                                _busy ||
                                    widget.session.isReadOnly ||
                                    _stamina < widget.rules.movementCost
                                ? null
                                : _start,
                            icon: const Icon(
                              Icons.directions_walk_rounded,
                              size: 26,
                            ),
                            label: Text(
                              strings.text('expedition.startShort'),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    avatar: const Icon(Icons.bolt_rounded),
                    label: Text('${widget.rules.movementCost}'),
                  ),
                ],
              )
            else ...[
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Chip(
                    avatar: const Icon(Icons.route_rounded, size: 18),
                    label: Text(
                      strings.text(
                        'expedition.node',
                        arguments: {
                          'current': '${expedition.nodeIndex + 1}',
                          'total': '${widget.rules.nodeCount}',
                        },
                      ),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  if (currentLocation != null)
                    Chip(
                      avatar: const Icon(Icons.place_outlined, size: 18),
                      label: Text(
                        currentLocation.label.isEmpty
                            ? currentLocation.id
                            : currentLocation.label,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              if (expedition.returned) ...[
                const SizedBox(height: 8),
                Text(strings.text('expedition.returned')),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 340 ? 3 : 2;
                    final gap = 8.0;
                    final cardWidth =
                        (constraints.maxWidth - gap * (columns - 1)) / columns;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (final reward in pending)
                          SizedBox(
                            width: cardWidth,
                            child: _ExpeditionRewardCard(
                              reward: reward,
                              detailsLabel: reward['itemId'] == 'water.mineral'
                                  ? '${strings.text('expedition.mineralWaterReward', arguments: {'quality': '${reward['quality']}'})} · ${strings.expeditionRewardSource('${reward['source']}')}'
                                  : strings.text(
                                      'expedition.rewardDetails',
                                      arguments: {
                                        'quality': '${reward['quality']}',
                                        'source': strings
                                            .expeditionRewardSource(
                                              '${reward['source']}',
                                            ),
                                      },
                                    ),
                              itemLabel: strings.itemName(
                                reward['itemId'] as String,
                              ),
                              discardLabel: strings.text(
                                'expedition.discardItem',
                              ),
                              onDiscard: _busy || widget.session.isReadOnly
                                  ? null
                                  : () => _discardReward(
                                      pending.indexOf(reward),
                                      reward,
                                    ),
                              woodBoardSpriteBytes: widget.woodBoardSpriteBytes,
                              threadSpoolSpriteBytes:
                                  widget.threadSpoolSpriteBytes,
                              materialAtlasBytes: widget.materialAtlasBytes,
                              toolAtlasBytes: widget.toolAtlasBytes,
                              materialPackArtBytes: widget.materialPackArtBytes,
                              mineralPackSpriteBytes:
                                  widget.mineralPackSpriteBytes,
                              woodChipBundleSpriteBytes:
                                  widget.woodChipBundleSpriteBytes,
                            ),
                          ),
                      ],
                    );
                  },
                ),
                FilledButton.icon(
                  onPressed:
                      _busy || expedition.claimed || widget.session.isReadOnly
                      ? null
                      : _claim,
                  icon: const Icon(Icons.backpack_outlined),
                  label: Text(strings.text('expedition.claimAll')),
                ),
              ] else ...[
                if (nodeInvestigated)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(strings.text('expedition.alreadyInvestigated')),
                  ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final gap = 8.0;
                    final width = (constraints.maxWidth - gap) / 2;
                    final canInvestigate =
                        !nodeInvestigated && currentLocation != null;
                    return Wrap(
                      key: _routeActionsKey,
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        if (canInvestigate)
                          SizedBox(
                            width: width,
                            child: _ExpeditionActionTile(
                              key: const Key('expedition-action-fixed'),
                              icon: Icons.search_rounded,
                              label: strings.text(
                                'expedition.surveyFixedShort',
                              ),
                              semanticLabel: strings.text(
                                'expedition.surveyFixed',
                              ),
                              cost: widget.rules.investigationCost,
                              enabled:
                                  !_busy &&
                                  !widget.session.isReadOnly &&
                                  _stamina >= widget.rules.investigationCost,
                              onPressed: _surveyFixed,
                            ),
                          ),
                        if (canInvestigate)
                          SizedBox(
                            width: width,
                            child: _ExpeditionActionTile(
                              key: const Key('expedition-action-surprise'),
                              icon: Icons.auto_awesome_rounded,
                              label: strings.text(
                                'expedition.surveySurpriseShort',
                              ),
                              semanticLabel: strings.text(
                                'expedition.surveySurprise',
                              ),
                              cost: widget.rules.investigationCost,
                              enabled:
                                  !_busy &&
                                  !widget.session.isReadOnly &&
                                  _stamina >= widget.rules.investigationCost,
                              onPressed: _surveySurprise,
                            ),
                          ),
                        if (expedition.nodeIndex + 1 < widget.rules.nodeCount)
                          SizedBox(
                            width: width,
                            child: _ExpeditionActionTile(
                              key: const Key('expedition-action-next'),
                              icon: Icons.arrow_forward_rounded,
                              label: strings.text('expedition.nextNodeShort'),
                              semanticLabel: strings.text(
                                'expedition.nextNode',
                              ),
                              cost: widget.rules.movementCost,
                              enabled:
                                  !_busy &&
                                  !widget.session.isReadOnly &&
                                  _stamina >= widget.rules.movementCost,
                              onPressed: _move,
                            ),
                          ),
                        SizedBox(
                          width: width,
                          child: _ExpeditionActionTile(
                            key: const Key('expedition-action-return'),
                            icon: Icons.home_rounded,
                            label: strings.text('expedition.returnShort'),
                            semanticLabel: strings.text(
                              'expedition.returnFree',
                            ),
                            enabled: !_busy && !widget.session.isReadOnly,
                            onPressed: _return,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ],
            if (_busy) const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _tutorialTaskGroup({
    required String key,
    required String title,
    required Map<String, bool> tasks,
    required List<(String, String)> items,
  }) {
    final completed = items.where((item) => tasks[item.$1] == true).length;
    final remaining = items
        .where((item) => tasks[item.$1] != true)
        .toList(growable: false);
    final next = remaining.isEmpty ? null : remaining.first;
    final strings = StreetScrapLocalizations.of(context);
    final nextIcon = next == null
        ? Icons.task_alt_rounded
        : _tutorialTaskIcon(next.$1);
    final summaryLabel = next == null
        ? '$completed/${items.length} · ${strings.text('expedition.step.complete')}'
        : '$completed/${items.length} · ${strings.text('expedition.step.next')} · ${next.$2}';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ExpansionTile(
        key: Key('street-scrap-task-group-$key'),
        initiallyExpanded: false,
        leading: CircleAvatar(
          radius: 18,
          child: Icon(
            completed == items.length
                ? Icons.task_alt_rounded
                : Icons.checklist_rounded,
            size: 21,
          ),
        ),
        title: Text(title),
        subtitle: Semantics(
          key: Key('street-scrap-task-summary-$key'),
          label: summaryLabel,
          child: ExcludeSemantics(
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      key: Key('street-scrap-task-progress-$key'),
                      value: completed / items.length,
                      minHeight: 7,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: next?.$2 ?? strings.text('expedition.step.complete'),
                  child: Icon(nextIcon, size: 20),
                ),
                const SizedBox(width: 6),
                Text('$completed/${items.length}'),
              ],
            ),
          ),
        ),
        children: [
          for (final item in items)
            Semantics(
              key: Key('street-scrap-task-${item.$1}'),
              label:
                  '${item.$2} · ${strings.text(tasks[item.$1] == true ? 'expedition.step.complete' : 'expedition.step.next')}',
              child: ExcludeSemantics(
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    tasks[item.$1] == true
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                  ),
                  title: Text(item.$2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _tutorialTaskIcon(String id) => switch (id) {
    'q1.01' => Icons.recycling_rounded,
    'q1.02' => Icons.cut_rounded,
    'q1.03' => Icons.hardware_rounded,
    'q2.01' => Icons.sailing_rounded,
    'q2.02' => Icons.phishing_rounded,
    'q2.03' => Icons.set_meal_rounded,
    'q3.01' => Icons.compress_rounded,
    'q3.02' => Icons.construction_rounded,
    'q3.03' => Icons.build_rounded,
    'q3.04' => Icons.inventory_2_outlined,
    'q3.05' => Icons.backpack_outlined,
    'q4.01' => Icons.water_drop_outlined,
    'q4.02' => Icons.soup_kitchen_outlined,
    'q4.03' => Icons.restaurant_outlined,
    'q5.01' => Icons.assignment_turned_in_outlined,
    'q5.02' => Icons.home_work_outlined,
    _ => Icons.checklist_rounded,
  };

  Widget _tutorialTaskRow(String id, String title, Map<String, bool> tasks) =>
      ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          tasks[id] == true ? Icons.check_circle : Icons.radio_button_unchecked,
        ),
        title: Text(title),
      );

  Widget _phaseZeroRoute(
    BuildContext context,
    StreetScrapLocalizations strings,
    Map<String, bool> tasks,
  ) {
    final theme = Theme.of(context);
    const steps = [
      (
        id: 'q0.01',
        icon: Icons.travel_explore_rounded,
        shortLabel: 'expedition.step.search',
        fullLabel: 'expedition.task.firstItem',
      ),
      (
        id: 'q0.02',
        icon: Icons.backpack_rounded,
        shortLabel: 'expedition.step.keep',
        fullLabel: 'expedition.task.keepItem',
      ),
      (
        id: 'q0.03',
        icon: Icons.volunteer_activism_rounded,
        shortLabel: 'expedition.step.deliver',
        fullLabel: 'expedition.task.deliverMaterials',
      ),
    ];
    final colors = [
      theme.colorScheme.primaryContainer,
      theme.colorScheme.secondaryContainer,
      theme.colorScheme.tertiaryContainer,
    ];
    final compact = steps.every((step) => tasks[step.id] == true);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.text('expedition.phaseZero'),
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var index = 0; index < steps.length; index++) ...[
              if (index > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: theme.colorScheme.outline,
                    size: 22,
                  ),
                ),
              Expanded(
                child: _phaseZeroStepCard(
                  context,
                  step: steps[index],
                  color: colors[index],
                  complete: tasks[steps[index].id] == true,
                  compact: compact,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _phaseZeroStepCard(
    BuildContext context, {
    required ({String id, IconData icon, String shortLabel, String fullLabel})
    step,
    required Color color,
    required bool complete,
    required bool compact,
  }) {
    final strings = StreetScrapLocalizations.of(context);
    final theme = Theme.of(context);
    final status = complete
        ? strings.text('expedition.step.complete')
        : strings.text('expedition.step.next');
    final label = '${strings.text(step.fullLabel)} · $status';
    return Semantics(
      key: Key('street-scrap-${step.id}-visual-step'),
      container: true,
      label: label,
      value: status,
      child: ExcludeSemantics(
        child: Tooltip(
          message: label,
          child: Container(
            constraints: BoxConstraints(minHeight: compact ? 48 : 112),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 4 : 6,
              vertical: compact ? 4 : 10,
            ),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: complete
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
                width: complete ? 2 : 1,
              ),
            ),
            child: compact
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 22,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          strings.text(step.shortLabel),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        complete ? Icons.check_circle_rounded : step.icon,
                        size: 42,
                        color: complete
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSecondaryContainer,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        strings.text(step.shortLabel),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelLarge,
                      ),
                      Text(
                        complete ? '✓' : '·',
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  String _friendlyError(Object error) {
    final message = error.toString();
    final strings = StreetScrapLocalizations.of(context);
    for (final code in [
      'recyclingClassificationLocked',
      'starterVesselsLocked',
      'starterVesselsAlreadyClaimed',
      'recyclingSamplesAlreadyClaimed',
      'recyclingSampleUnavailable',
      'sewingTutorialKitLocked',
      'sewingTutorialKitAlreadyClaimed',
      'intactMaterialLessonLocked',
      'intactMaterialLessonComplete',
      'intactMaterialUnavailable',
      'insufficientStamina',
      'nodeAlreadyInvestigated',
      'claimPreviousRewardsFirst',
      'noCleanEmptyBottle',
    ]) {
      if (message.contains(code)) {
        return strings.text('expedition.error.$code');
      }
    }
    if (message.contains('No fitting space')) {
      return strings.text('expedition.error.noFittingSpace');
    }
    return strings.text('expedition.error.operationFailed');
  }
}

class _TutorialDeliveryItemCard extends StatelessWidget {
  const _TutorialDeliveryItemCard({
    required this.item,
    required this.number,
    required this.artSize,
    required this.localizations,
    this.woodBoardSpriteBytes,
    this.threadSpoolSpriteBytes,
    this.materialAtlasBytes,
    this.toolAtlasBytes,
    this.materialPackArtBytes,
    this.mineralPackSpriteBytes,
    this.woodChipBundleSpriteBytes,
  });

  final StreetScrapObject item;
  final int number;
  final double artSize;
  final StreetScrapLocalizations localizations;
  final Uint8List? woodBoardSpriteBytes;
  final Uint8List? threadSpoolSpriteBytes;
  final Uint8List? materialAtlasBytes;
  final Uint8List? toolAtlasBytes;
  final Uint8List? materialPackArtBytes;
  final Uint8List? mineralPackSpriteBytes;
  final Uint8List? woodChipBundleSpriteBytes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = localizations.itemName(item.itemId);
    final source = localizations.itemSource(item.source);
    final quality = localizations.itemQuality(item.quality);
    final processed =
        item.source.toLowerCase().contains('crafted') ||
        item.source.toLowerCase().contains('recycled') ||
        item.source.contains('加工');

    return Semantics(
      label: '$name・$source・$quality・$number',
      child: Card(
        color: theme.colorScheme.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    child: Text('$number/2'),
                  ),
                ),
              ),
              SizedBox.square(
                dimension: artSize,
                child: ExcludeSemantics(
                  child: StreetScrapItemSprite(
                    itemId: item.itemId,
                    source: item.source,
                    contentItemId:
                        item.containerState['contentItemId'] as String?,
                    size: artSize,
                    visualScale: 1.28,
                    woodBoardSpriteBytes: woodBoardSpriteBytes,
                    threadSpoolSpriteBytes: threadSpoolSpriteBytes,
                    materialAtlasBytes: materialAtlasBytes,
                    toolAtlasBytes: toolAtlasBytes,
                    materialPackArtBytes: materialPackArtBytes,
                    mineralPackSpriteBytes: mineralPackSpriteBytes,
                    woodChipBundleSpriteBytes: woodChipBundleSpriteBytes,
                  ),
                ),
              ),
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Tooltip(
                    message: source,
                    child: Icon(
                      processed
                          ? Icons.construction_rounded
                          : Icons.search_rounded,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Tooltip(message: quality, child: Text('${item.quality}')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpeditionRewardCard extends StatelessWidget {
  const _ExpeditionRewardCard({
    required this.reward,
    required this.detailsLabel,
    required this.itemLabel,
    required this.discardLabel,
    required this.onDiscard,
    required this.woodBoardSpriteBytes,
    required this.threadSpoolSpriteBytes,
    required this.materialAtlasBytes,
    required this.toolAtlasBytes,
    required this.materialPackArtBytes,
    required this.mineralPackSpriteBytes,
    required this.woodChipBundleSpriteBytes,
  });

  final Map<String, Object?> reward;
  final String detailsLabel;
  final String itemLabel;
  final String discardLabel;
  final VoidCallback? onDiscard;
  final Uint8List? woodBoardSpriteBytes;
  final Uint8List? threadSpoolSpriteBytes;
  final Uint8List? materialAtlasBytes;
  final Uint8List? toolAtlasBytes;
  final Uint8List? materialPackArtBytes;
  final Uint8List? mineralPackSpriteBytes;
  final Uint8List? woodChipBundleSpriteBytes;

  @override
  Widget build(BuildContext context) {
    final itemId = reward['itemId']! as String;
    final quantity = reward['quantity']! as int;
    final quality = reward['quality']! as int;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label: '$itemLabel × $quantity. $detailsLabel',
              child: SizedBox.square(
                dimension: 112,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    StreetScrapItemSprite(
                      itemId: itemId,
                      source: '${reward['source']}',
                      size: 112,
                      visualScale: 1.25,
                      woodBoardSpriteBytes: woodBoardSpriteBytes,
                      threadSpoolSpriteBytes: threadSpoolSpriteBytes,
                      materialAtlasBytes: materialAtlasBytes,
                      toolAtlasBytes: toolAtlasBytes,
                      materialPackArtBytes: materialPackArtBytes,
                      mineralPackSpriteBytes: mineralPackSpriteBytes,
                      woodChipBundleSpriteBytes: woodChipBundleSpriteBytes,
                    ),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          child: Text('×$quantity'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              itemLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.auto_awesome, size: 14),
                const SizedBox(width: 3),
                Text('$quality'),
                const Spacer(),
                IconButton(
                  tooltip: discardLabel,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints.tightFor(
                    width: 36,
                    height: 36,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: onDiscard,
                  icon: const Icon(Icons.delete_outline, size: 19),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpeditionActionTile extends StatelessWidget {
  const _ExpeditionActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.enabled,
    required this.onPressed,
    this.cost,
  });

  final IconData icon;
  final String label;
  final String semanticLabel;
  final bool enabled;
  final VoidCallback onPressed;
  final int? cost;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      onTap: enabled ? onPressed : null,
      child: ExcludeSemantics(
        child: Material(
          color: colors.surfaceContainer,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            child: SizedBox(
              height: 88,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, size: 27),
                        if (cost != null) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.bolt_rounded,
                            size: 16,
                            color: colors.tertiary,
                          ),
                          Text('$cost'),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StreetScavengingScenePainter extends CustomPainter {
  const _StreetScavengingScenePainter();

  void _rect(
    Canvas canvas,
    Paint paint,
    double x,
    double y,
    double w,
    double h,
  ) {
    canvas.drawRect(Rect.fromLTWH(x, y, w, h), paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 400, size.height / 200);
    final paint = Paint()..isAntiAlias = false;

    _rect(canvas, paint..color = const Color(0xFF9AB0B0), 0, 0, 400, 150);
    _rect(canvas, paint..color = const Color(0xFF6D7775), 0, 150, 400, 50);
    _rect(canvas, paint..color = const Color(0xFFB86F50), 16, 43, 100, 107);
    _rect(canvas, paint..color = const Color(0xFFE2C79B), 125, 22, 151, 128);
    _rect(canvas, paint..color = const Color(0xFF965744), 286, 53, 97, 97);

    for (final x in [30.0, 70.0]) {
      _rect(canvas, paint..color = const Color(0xFF35474A), x, 62, 21, 25);
      _rect(canvas, paint..color = const Color(0xFFD5B98A), x + 8, 62, 4, 25);
      _rect(canvas, paint..color = const Color(0xFFD5B98A), x, 72, 21, 4);
    }
    for (final x in [300.0, 344.0]) {
      _rect(canvas, paint..color = const Color(0xFF344246), x, 72, 22, 28);
      _rect(canvas, paint..color = const Color(0xFFC4A275), x + 9, 72, 4, 28);
      _rect(canvas, paint..color = const Color(0xFFC4A275), x, 84, 22, 4);
    }

    _rect(canvas, paint..color = const Color(0xFF465C60), 143, 72, 116, 58);
    _rect(canvas, paint..color = const Color(0xFFD5A16F), 137, 59, 128, 16);
    for (var x = 137.0; x < 265; x += 32) {
      _rect(canvas, paint..color = const Color(0xFFB8654D), x, 59, 16, 16);
    }
    _rect(canvas, paint..color = const Color(0xFFD5A16F), 160, 89, 33, 41);
    _rect(canvas, paint..color = const Color(0xFF28383B), 209, 87, 31, 31);

    _rect(canvas, paint..color = const Color(0xFF8D9990), 0, 145, 400, 5);
    for (var x = 8.0; x < 400; x += 48) {
      _rect(canvas, paint..color = const Color(0xFF596864), x, 164, 28, 3);
    }

    // Reusable crate, folded board, and bottle make the scavenging goal legible
    // before the player has collected their first item.
    _rect(canvas, paint..color = const Color(0xFF415B50), 186, 124, 50, 38);
    _rect(canvas, paint..color = const Color(0xFF92A58D), 192, 130, 38, 4);
    _rect(canvas, paint..color = const Color(0xFF92A58D), 192, 141, 38, 4);
    _rect(canvas, paint..color = const Color(0xFF8A593F), 77, 151, 45, 28);
    _rect(canvas, paint..color = const Color(0xFFB9825C), 71, 146, 57, 9);
    _rect(canvas, paint..color = const Color(0xFF5A8790), 282, 146, 13, 31);
    _rect(canvas, paint..color = const Color(0xFF91B3B1), 285, 140, 7, 7);
    _rect(canvas, paint..color = const Color(0xFFE8D3A6), 246, 110, 5, 5);
    _rect(canvas, paint..color = const Color(0xFFE8D3A6), 242, 114, 13, 4);
    _rect(canvas, paint..color = const Color(0xFFE8D3A6), 246, 118, 5, 5);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StreetScavengingScenePainter oldDelegate) =>
      false;
}
