import 'package:flutter/material.dart';

import 'street_scrap_inventory.dart';
import 'street_scrap_progress.dart';
import 'street_scrap_woodworking.dart';
import 'street_scrap_water.dart';
import 'street_scrap_orders.dart';
import 'street_scrap_chapter5.dart';
import 'street_scrap_module.dart';
import 'street_scrap_audio.dart';
import 'street_scrap_localizations.dart';
import 'street_scrap_locked_activity_panel.dart';
import 'street_scrap_item_sprite.dart';
import 'street_scrap_protagonist_sprite.dart';

class StreetScrapWoodworkingPanel extends StatefulWidget {
  const StreetScrapWoodworkingPanel({
    super.key,
    required this.session,
    required this.catalog,
    this.repairCatalog,
    this.orderCatalog,
    this.maxStamina = 60,
    required this.onOpenRecipes,
    required this.onChanged,
    this.onSound,
    this.protagonistArt,
  });

  final StreetScrapSession session;
  final StreetScrapInventoryCatalog catalog;
  final StreetScrapToolRepairCatalog? repairCatalog;
  final StreetScrapOrderCatalog? orderCatalog;
  final int maxStamina;
  final VoidCallback onOpenRecipes;
  final VoidCallback onChanged;
  final ValueChanged<StreetScrapAudioCue>? onSound;
  final StreetScrapProtagonistArt? protagonistArt;

  @override
  State<StreetScrapWoodworkingPanel> createState() =>
      _StreetScrapWoodworkingPanelState();
}

class _StreetScrapWoodworkingPanelState
    extends State<StreetScrapWoodworkingPanel> {
  bool _busy = false;
  String? _error;
  String? _selectedWaterVesselId;
  String? _selectedTargetVesselId;
  String? _selectedWaterSourceId;
  String? _selectedChapterFiveShelterId;
  String? _selectedChapterFiveChestId;
  String? _selectedRepairToolId;
  String? _selectedRepairRuleId;
  final Set<String> _selectedRepairMaterialIds = {};

  Future<void> _claimKit() async {
    await _runSupply(
      () => claimStreetScrapWoodPressKit(
        session: widget.session,
        commandId: 'q3.01.claim-wood-press-kit',
        expectedRevision: widget.session.snapshot.revision,
        catalog: widget.catalog,
        grids: streetScrapGridSpecsForState(widget.session.snapshot.state),
      ),
    );
  }

  Future<void> _claimWaterKit() async {
    await _runSupply(
      () => claimStreetScrapWaterFilterKit(
        session: widget.session,
        commandId: 'q4.01.claim-filter-kit',
        expectedRevision: widget.session.snapshot.revision,
        catalog: widget.catalog,
        grids: streetScrapGridSpecsForState(widget.session.snapshot.state),
      ),
    );
  }

  Widget _completedWaterLessonStep(
    StreetScrapLocalizations strings, {
    required IconData icon,
    required String shortLabel,
    required String accessibilityLabel,
  }) => Semantics(
    label: strings.text(accessibilityLabel),
    child: ExcludeSemantics(
      child: Chip(
        avatar: Icon(icon, size: 18),
        label: Text(strings.text(shortLabel)),
        visualDensity: VisualDensity.compact,
      ),
    ),
  );

  Widget _waterRuleBadge(
    StreetScrapLocalizations strings, {
    required IconData icon,
    required String labelKey,
    required String detailKey,
  }) => Tooltip(
    message: strings.text(detailKey),
    child: Semantics(
      label: strings.text(detailKey),
      child: ExcludeSemantics(
        child: Chip(
          avatar: Icon(icon, size: 16),
          label: Text(strings.text(labelKey)),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    ),
  );

  Widget _woodRecipeFlow(
    StreetScrapLocalizations strings, {
    required Map<String, int> inputs,
    required String outputItemId,
  }) {
    final compactLayout = MediaQuery.sizeOf(context).width < 600;
    final artworkSize = compactLayout ? 64.0 : 80.0;
    final materialWidth = compactLayout ? 76.0 : 92.0;
    Widget material(String itemId, int quantity) => Semantics(
      label: '${strings.itemName(itemId)} × $quantity',
      child: SizedBox(
        width: materialWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StreetScrapItemSprite(
              itemId: itemId,
              source: 'found_native',
              size: artworkSize,
            ),
            Text('×$quantity', style: Theme.of(context).textTheme.labelLarge),
            Text(
              strings.itemName(itemId),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        runSpacing: 8,
        children: [
          for (final entry in inputs.entries) ...[
            if (entry.key != inputs.keys.first)
              Icon(
                Icons.add_rounded,
                size: 20,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            material(entry.key, entry.value),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              Icons.arrow_forward_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          material(outputItemId, 1),
        ],
      ),
    );
  }

  Future<void> _claimSoupKit() async {
    await _runSupply(
      () => claimStreetScrapBasicSoupKit(
        session: widget.session,
        commandId: 'q4.02.claim-soup-kit',
        expectedRevision: widget.session.snapshot.revision,
        catalog: widget.catalog,
        grids: streetScrapGridSpecsForState(widget.session.snapshot.state),
      ),
    );
  }

  List<StreetScrapObject> get _waterVessels => _currentInventory.objects.values
      .where(
        (item) => const {
          'container.clean',
          'container.clean_jar',
          'container.used_intact',
        }.contains(item.itemId),
      )
      .toList(growable: false);

  Future<void> _fillWater(String sourceId) async {
    final id = _selectedWaterVesselId ?? _waterVessels.firstOrNull?.instanceId;
    if (id == null) return;
    await _runSupply(
      () => fillStreetScrapVessel(
        session: widget.session,
        commandId: 'water-fill-${DateTime.now().microsecondsSinceEpoch}',
        expectedRevision: widget.session.snapshot.revision,
        catalog: widget.catalog,
        grids: streetScrapGridSpecsForState(widget.session.snapshot.state),
        vesselId: id,
        sourceId: sourceId,
        maxStamina: widget.maxStamina,
      ),
    );
  }

  Future<void> _pourWater() async {
    final source =
        _selectedWaterVesselId ?? _waterVessels.firstOrNull?.instanceId;
    final target =
        _selectedTargetVesselId ??
        _waterVessels
            .where((item) => item.instanceId != source)
            .firstOrNull
            ?.instanceId;
    if (source == null || target == null) return;
    await _runSupply(
      () => transferStreetScrapWater(
        session: widget.session,
        commandId: 'water-pour-${DateTime.now().microsecondsSinceEpoch}',
        expectedRevision: widget.session.snapshot.revision,
        catalog: widget.catalog,
        grids: streetScrapGridSpecsForState(widget.session.snapshot.state),
        sourceVesselId: source,
        targetVesselId: target,
      ),
    );
  }

  Future<void> _emptyWater() async {
    final id = _selectedWaterVesselId ?? _waterVessels.firstOrNull?.instanceId;
    if (id == null) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          StreetScrapLocalizations.of(
            context,
          ).text('water.confirmDiscardTitle'),
        ),
        content: Text(
          StreetScrapLocalizations.of(context).text('water.confirmDiscardBody'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              StreetScrapLocalizations.of(context).text('water.cancel'),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              StreetScrapLocalizations.of(context).text('water.confirmDiscard'),
            ),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    await _runSupply(
      () => emptyStreetScrapWaterVessel(
        session: widget.session,
        commandId: 'water-empty-${DateTime.now().microsecondsSinceEpoch}',
        expectedRevision: widget.session.snapshot.revision,
        catalog: widget.catalog,
        grids: streetScrapGridSpecsForState(widget.session.snapshot.state),
        vesselId: id,
      ),
    );
  }

  Future<void> _washVessel() async {
    final source =
        _selectedWaterVesselId ?? _waterVessels.firstOrNull?.instanceId;
    final target =
        _selectedTargetVesselId ??
        _waterVessels
            .where((item) => item.instanceId != source)
            .firstOrNull
            ?.instanceId;
    if (target == null || source == null) return;
    await _runSupply(
      () => washStreetScrapVessel(
        session: widget.session,
        commandId: 'water-wash-${DateTime.now().microsecondsSinceEpoch}',
        expectedRevision: widget.session.snapshot.revision,
        catalog: widget.catalog,
        grids: streetScrapGridSpecsForState(widget.session.snapshot.state),
        targetVesselId: target,
        waterVesselId: source,
      ),
    );
  }

  Future<void> _eatSoup() async {
    final strings = StreetScrapLocalizations.of(context);
    final mealBox = _currentInventory.objects.values
        .where(
          (item) =>
              streetScrapMealContainerItemIds.contains(item.itemId) &&
              const {
                'meal.soup_basic',
                'meal.soup_fish',
                'meal.soup_vegetable',
                'meal.failed',
              }.contains(item.containerState['contentItemId']),
        )
        .firstOrNull;
    if (mealBox == null) {
      setState(() => _error = strings.text('meal.errorMissingMeal'));
      return;
    }
    final meal = mealBox.containerState['contentItemId']! as String;
    final quality =
        mealBox.containerState['contentQuality'] as int? ?? mealBox.quality;
    final recovery = streetScrapMealRecovery(meal, quality);
    final stamina =
        widget.session.snapshot.state['stamina'] as int? ?? widget.maxStamina;
    final overflow = (stamina + recovery - widget.maxStamina).clamp(
      0,
      widget.maxStamina,
    );
    final actualRecovery = widget.maxStamina - stamina < recovery
        ? widget.maxStamina - stamina
        : recovery;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.text('meal.eatDialogTitle')),
        content: Text(
          strings.text(
            'meal.eatDialogBody',
            arguments: {
              'recovery': '$recovery',
              'actual': '$actualRecovery',
              'overflowNotice': overflow > 0
                  ? strings.text(
                      'meal.eatDialogOverflow',
                      arguments: {'overflow': '$overflow'},
                    )
                  : '',
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.text('meal.cancelEating')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.text('meal.confirmEating')),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    await _runSupply(
      () => consumeStreetScrapSoup(
        session: widget.session,
        commandId: 'q4.03.eat-${mealBox.instanceId}',
        expectedRevision: widget.session.snapshot.revision,
        catalog: widget.catalog,
        grids: streetScrapGridSpecsForState(widget.session.snapshot.state),
        mealBoxInstanceId: mealBox.instanceId,
        maxStamina: widget.maxStamina,
      ),
    );
  }

  Future<void> _deliverSoup() async {
    final strings = StreetScrapLocalizations.of(context);
    final mealBox = _currentInventory.objects.values
        .where(
          (item) =>
              streetScrapMealContainerItemIds.contains(item.itemId) &&
              const {
                'meal.soup_basic',
                'meal.soup_fish',
                'meal.soup_vegetable',
              }.contains(item.containerState['contentItemId']),
        )
        .firstOrNull;
    if (mealBox == null) {
      setState(() => _error = strings.text('meal.errorNotDeliverable'));
      return;
    }
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.text('meal.deliverDialogTitle')),
        content: Text(strings.text('meal.deliverDialogBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.text('meal.keepMeal')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.text('meal.confirmDelivery')),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    final orderCatalog = widget.orderCatalog;
    if (orderCatalog == null) {
      setState(() => _error = strings.text('meal.errorOrderUnavailable'));
      return;
    }
    await _runSupply(
      () => deliverStreetScrapOrder(
        session: widget.session,
        commandId: 'q4.03.deliver-${mealBox.instanceId}',
        expectedRevision: widget.session.snapshot.revision,
        orderCatalog: orderCatalog,
        orderId: 'ss.order.meal',
        inventoryCatalog: widget.catalog,
        grids: streetScrapGridSpecsForState(widget.session.snapshot.state),
        containerInstanceId: mealBox.instanceId,
      ),
    );
  }

  Future<void> _claimNailKit() async {
    final revision = widget.session.snapshot.revision;
    await _runSupply(
      () => claimStreetScrapNailBoardKit(
        session: widget.session,
        // Scope the idempotency key to this save revision. A fixed historical
        // key can collide with an older receipt and make an unclaimed kit look
        // like a successful no-op after migration/recovery.
        commandId: 'q3.02.claim-nail-board-kit-r$revision',
        expectedRevision: revision,
        catalog: widget.catalog,
      ),
    );
  }

  Future<void> _claimRepairKit() async {
    final revision = widget.session.snapshot.revision;
    await _runSupply(
      () => claimStreetScrapToolRepairKit(
        session: widget.session,
        commandId: 'q3.03.claim-tool-repair-kit-r$revision',
        expectedRevision: revision,
        catalog: widget.catalog,
      ),
    );
  }

  Future<void> _repairTutorialCrowbar() async {
    final gridId = _currentInventory.placements['q303-crowbar']?.gridId;
    if (gridId == null) return;
    await _runSupply(
      () => repairStreetScrapTutorialCrowbar(
        session: widget.session,
        commandId: 'q3.03.repair-tutorial-crowbar',
        expectedRevision: widget.session.snapshot.revision,
        catalog: widget.catalog,
        grids: streetScrapWoodPressGrids,
        toolInstanceId: 'q303-crowbar',
        metalShardInstanceId: 'q303-metal-shard',
        bindingInstanceId: 'q303-binding',
        gridId: gridId,
      ),
    );
  }

  List<StreetScrapObject> get _repairableTools => _currentInventory
      .objects
      .values
      .where((item) {
        final maximum = widget.catalog.maximumDurability(
          item.itemId,
          item.quality,
          item.traits,
        );
        return !(_tutorialRepairPending &&
                item.source == 'tutorial:q3.03-kit') &&
            _repairRulesFor(item).isNotEmpty &&
            item.toolDurability != null &&
            item.toolDurability! > 0 &&
            maximum != null &&
            item.toolDurability! < maximum &&
            !(_currentInventory.placements[item.instanceId]?.gridId.startsWith(
                  'chapter5.',
                ) ??
                true);
      })
      .toList(growable: false);

  List<StreetScrapToolRepairRule> _repairRulesFor(StreetScrapObject? tool) {
    if (tool == null) return const [];
    return widget.repairCatalog?.forTool(
          tool.itemId,
          widget.session.snapshot.state['chapter'] as int? ?? 0,
        ) ??
        const [];
  }

  StreetScrapToolRepairRule? _repairRuleFor(StreetScrapObject? tool) {
    final rules = _repairRulesFor(tool);
    return rules
            .where((rule) => rule.id == _selectedRepairRuleId)
            .firstOrNull ??
        rules.firstOrNull;
  }

  String _repairTokenFor(StreetScrapObject item) {
    final contentId = item.containerState['contentItemId'];
    if (const {
          'container.clean',
          'container.clean_jar',
          'container.used_intact',
        }.contains(item.itemId) &&
        contentId is String) {
      return 'content:$contentId';
    }
    return item.itemId;
  }

  List<StreetScrapObject> _repairMaterialsFor(StreetScrapObject? tool) {
    if (tool == null) return const [];
    final gridId = _currentInventory.placements[tool.instanceId]?.gridId;
    if (gridId == null) return const [];
    final accepted =
        _repairRuleFor(
          tool,
        )?.materialOptions.expand((option) => option).toSet() ??
        <String>{};
    return _currentInventory.objects.values
        .where(
          (item) =>
              accepted.contains(_repairTokenFor(item)) &&
              !(_tutorialRepairPending &&
                  item.source == 'tutorial:q3.03-kit') &&
              _currentInventory.placements[item.instanceId]?.gridId == gridId,
        )
        .toList(growable: false);
  }

  bool _repairSelectionMatches(
    StreetScrapToolRepairRule? rule,
    Iterable<String> selected,
  ) {
    if (rule == null) return false;
    final ids = selected
        .map((id) {
          final item = _currentInventory.objects[id];
          return item == null ? null : _repairTokenFor(item);
        })
        .whereType<String>()
        .toList();
    return rule.materialOptions.any(
      (option) => _sameRepairSelection(option, ids),
    );
  }

  bool _repairSelectionCanAdd(
    StreetScrapToolRepairRule? rule,
    Iterable<String> selected,
    String candidateId,
  ) {
    if (rule == null) return false;
    final ids =
        [...selected, candidateId]
            .map((id) {
              final item = _currentInventory.objects[id];
              return item == null ? null : _repairTokenFor(item);
            })
            .whereType<String>()
            .toList()
          ..sort();
    return rule.materialOptions.any((option) {
      if (ids.length > option.length) return false;
      final remaining = [...option]..sort();
      for (final id in ids) {
        final index = remaining.indexOf(id);
        if (index < 0) return false;
        remaining.removeAt(index);
      }
      return true;
    });
  }

  bool _sameRepairSelection(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    final a = [...left]..sort();
    final b = [...right]..sort();
    for (var index = 0; index < a.length; index++) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }

  String _repairItemName(String itemId, StreetScrapLocalizations strings) =>
      switch (itemId) {
        'content:water.distilled' => strings.text(
          'repair.item.distilledWaterContent',
        ),
        'cloth.edge_scrap' => strings.text('repair.item.clothEdgeScrap'),
        'tool.rod_basic' => strings.text('repair.item.basicRod'),
        'tool.rod_repaired' => strings.text('repair.item.repairedRod'),
        'tool.rod_advanced' => strings.text('repair.item.advancedRod'),
        'tool.crowbar' => strings.text('repair.item.crowbar'),
        'tool.pliers' => strings.text('repair.item.pliers'),
        'tool.awl' => strings.text('repair.item.awl'),
        'toolpart.rig' => strings.text('repair.item.spareRig'),
        'metal.shard' => strings.text('repair.item.metalShard'),
        'cloth.binding' => strings.text('repair.item.binding'),
        'fish.bone' => strings.text('repair.item.fishBone'),
        _ => itemId,
      };

  Future<void> _repairSelectedTool() async {
    final toolId = _selectedRepairToolId;
    final tool = _repairableTools
        .where((item) => item.instanceId == toolId)
        .firstOrNull;
    final rule = _repairRuleFor(tool);
    if (toolId == null ||
        !_repairSelectionMatches(rule, _selectedRepairMaterialIds)) {
      return;
    }
    await _runSupply(
      () => repairStreetScrapTool(
        session: widget.session,
        commandId: 'tool-repair-${DateTime.now().microsecondsSinceEpoch}',
        expectedRevision: widget.session.snapshot.revision,
        catalog: widget.catalog,
        grids: streetScrapGridSpecsForState(widget.session.snapshot.state),
        toolInstanceId: toolId,
        materialInstanceIds: _selectedRepairMaterialIds.toList(),
        rule: rule!,
      ),
    );
    if (mounted) setState(_selectedRepairMaterialIds.clear);
  }

  Future<void> _claimCrateKit() async {
    await _runSupply(
      () => claimStreetScrapCrateKit(
        session: widget.session,
        commandId: 'q3.04.claim-crate-kit',
        expectedRevision: widget.session.snapshot.revision,
        catalog: widget.catalog,
      ),
    );
  }

  Future<void> _placeCrate() async {
    final inventory = _currentInventory;
    final crate = inventory.objects.values
        .where((item) => item.itemId == 'storage.wooden_crate')
        .firstOrNull;
    if (crate == null) {
      setState(
        () => _error = StreetScrapLocalizations.of(
          context,
        ).text('woodwork.errorCrateUncrafted'),
      );
      return;
    }
    final placement = inventory.placements[crate.instanceId];
    if (placement == null) {
      setState(
        () => _error = StreetScrapLocalizations.of(
          context,
        ).text('woodwork.errorCrateUnplaced'),
      );
      return;
    }
    await _runSupply(
      () => placeStreetScrapTutorialCrate(
        session: widget.session,
        commandId: 'q3.04.place-crate',
        expectedRevision: widget.session.snapshot.revision,
        catalog: widget.catalog,
        grids: streetScrapWoodPressGrids,
        crateInstanceId: crate.instanceId,
        gridId: placement.gridId,
      ),
    );
  }

  Future<void> _placeChapterFiveStructures() async {
    final inventory = _currentInventory;
    final shelters = inventory.objects.values
        .where((item) => item.itemId == 'structure.shelter')
        .where((item) => inventory.placements.containsKey(item.instanceId))
        .toList(growable: false);
    final chests = inventory.objects.values
        .where((item) => item.itemId == 'storage.reinforced_chest')
        .where((item) => inventory.placements.containsKey(item.instanceId))
        .toList(growable: false);
    final shelter =
        shelters
            .where((item) => item.instanceId == _selectedChapterFiveShelterId)
            .firstOrNull ??
        shelters.firstOrNull;
    final chest =
        chests
            .where((item) => item.instanceId == _selectedChapterFiveChestId)
            .firstOrNull ??
        chests.firstOrNull;
    if (shelter == null || chest == null) {
      setState(
        () => _error = StreetScrapLocalizations.of(
          context,
        ).text('woodwork.errorChapterFiveStructuresMissing'),
      );
      return;
    }
    final grids = streetScrapGridSpecsForState(widget.session.snapshot.state);
    await _runSupply(
      () => placeStreetScrapChapterFiveStructures(
        session: widget.session,
        commandId: 'q5.02.place-structures',
        expectedRevision: widget.session.snapshot.revision,
        catalog: widget.catalog,
        grids: grids,
        shelterInstanceId: shelter.instanceId,
        shelterGridId: inventory.placements[shelter.instanceId]!.gridId,
        chestInstanceId: chest.instanceId,
        chestGridId: inventory.placements[chest.instanceId]!.gridId,
      ),
    );
  }

  Future<void> _storeOneChapterFiveChestItem() async {
    final inventory = _currentInventory;
    final item = inventory.objects.values
        .where(
          (candidate) =>
              inventory.placements.containsKey(candidate.instanceId) &&
              candidate.containerContents.isEmpty &&
              !candidate.itemId.startsWith('storage.'),
        )
        .firstOrNull;
    if (item == null) {
      setState(
        () => _error = StreetScrapLocalizations.of(
          context,
        ).text('woodwork.errorNoChapterFiveStorageItem'),
      );
      return;
    }
    final placement = inventory.placements[item.instanceId]!;
    await _runSupply(
      () => storeStreetScrapInChapterFiveChest(
        session: widget.session,
        commandId:
            'q5.02.store-${item.instanceId}-${widget.session.snapshot.revision}',
        expectedRevision: widget.session.snapshot.revision,
        catalog: widget.catalog,
        grids: streetScrapGridSpecsForState(widget.session.snapshot.state),
        instanceId: item.instanceId,
        gridId: placement.gridId,
      ),
    );
  }

  Future<void> _withdrawOneChapterFiveChestItem() async {
    final ids =
        _currentInventory.storage[streetScrapChapter5ChestStorageId] ??
        const <String>[];
    if (ids.isEmpty) {
      setState(
        () => _error = StreetScrapLocalizations.of(
          context,
        ).text('woodwork.errorChapterFiveChestEmpty'),
      );
      return;
    }
    await _runSupply(
      () => withdrawStreetScrapFromChapterFiveChest(
        session: widget.session,
        commandId:
            'q5.02.withdraw-${ids.first}-${widget.session.snapshot.revision}',
        expectedRevision: widget.session.snapshot.revision,
        catalog: widget.catalog,
        grids: streetScrapGridSpecsForState(widget.session.snapshot.state),
        instanceId: ids.first,
        gridId: 'backpack',
      ),
    );
  }

  Future<void> _storeOneItem() async {
    final inventory = _currentInventory;
    final placement = inventory.placements.values
        .where(
          (entry) =>
              inventory.objects[entry.instanceId]?.itemId !=
              'storage.wooden_crate',
        )
        .firstOrNull;
    if (placement == null) {
      setState(
        () => _error = StreetScrapLocalizations.of(
          context,
        ).text('woodwork.errorNoCrateStorageItem'),
      );
      return;
    }
    await _runSupply(
      () => storeStreetScrapInTutorialCrate(
        session: widget.session,
        commandId: 'q3.04.store-${placement.instanceId}',
        expectedRevision: widget.session.snapshot.revision,
        catalog: widget.catalog,
        grids: streetScrapWoodPressGrids,
        instanceId: placement.instanceId,
        gridId: placement.gridId,
      ),
    );
  }

  Future<void> _withdrawOneItem() async {
    final inventory = _currentInventory;
    final itemIds = inventory.storage[streetScrapTutorialCrateStorageId];
    if (itemIds == null || itemIds.isEmpty) return;
    final id = itemIds.first;
    final grids = streetScrapGridSpecsForState(widget.session.snapshot.state);
    final destination = _firstGridThatFitsStoredItem(
      inventory: inventory,
      instanceId: id,
      grids: grids,
    );
    if (destination == null) {
      setState(
        () => _error = StreetScrapLocalizations.of(
          context,
        ).text('woodwork.errorNoWithdrawalSpace'),
      );
      return;
    }
    await _runSupply(
      () => withdrawStreetScrapFromTutorialCrate(
        session: widget.session,
        commandId: 'q3.04.withdraw-$id',
        expectedRevision: widget.session.snapshot.revision,
        catalog: widget.catalog,
        grids: grids,
        instanceId: id,
        gridId: destination,
      ),
    );
  }

  String? _firstGridThatFitsStoredItem({
    required StreetScrapInventory inventory,
    required String instanceId,
    required Map<String, StreetScrapGridSpec> grids,
  }) {
    for (final gridId in const ['backpack', 'board']) {
      final grid = grids[gridId]!;
      for (var y = 0; y < grid.height; y++) {
        for (var x = 0; x < grid.width; x++) {
          try {
            inventory.withdraw(
              instanceId,
              streetScrapTutorialCrateStorageId,
              gridId,
              x,
              y,
            );
            return gridId;
          } on StateError {
            // Keep searching; withdrawal candidates do not mutate the index.
          } on FormatException {
            // Occupied or out-of-bounds cells are not valid destinations.
          }
        }
      }
    }
    return null;
  }

  StreetScrapInventory get _currentInventory {
    final raw = widget.session.snapshot.state['inventory'];
    if (raw is! Map) throw StateError('inventoryMissing');
    return widget.catalog.inventoryFromJson(
      grids: streetScrapGridSpecsForState(widget.session.snapshot.state),
      json: Map<String, Object?>.from(raw),
    );
  }

  bool get _tutorialRepairPending {
    final tasks = widget.session.snapshot.state['tutorialTasks'];
    return tasks is Map &&
        tasks['q3.03.kitClaimed'] == true &&
        tasks['q3.03'] != true;
  }

  bool get _repairKitNeedsSupply {
    if (!_tutorialRepairPending) return false;
    final objects = _currentInventory.objects;
    return !objects.containsKey('q303-metal-shard') ||
        !objects.containsKey('q303-binding');
  }

  Future<void> _runSupply(
    Future<StreetScrapCommandResult> Function() issue,
  ) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await issue();
      final details = result.result;
      final cue = details is Map && details['succeeded'] is bool
          ? details['succeeded'] == true
                ? StreetScrapAudioCue.success
                : StreetScrapAudioCue.miss
          : StreetScrapAudioCue.tap;
      widget.onSound?.call(cue);
      widget.onChanged();
    } on StateError catch (error) {
      if (mounted) {
        final strings = StreetScrapLocalizations.of(context);
        setState(
          () => _error = switch (error.message) {
            'unknownWaterSource' => strings.text('water.errorUnknownSource'),
            'waterSourceLocked' => strings.text('water.errorSourceLocked'),
            'chapter5ExpansionNotInstalled' => strings.text(
              'water.errorExpansionMissing',
            ),
            'insufficientStamina' => strings.text('water.errorStamina'),
            'vesselMissing' ||
            'sourceVesselMissing' ||
            'targetVesselMissing' => strings.text('water.errorVesselMissing'),
            'cleanEmptyVesselRequired' => strings.text(
              'water.errorCleanBottle',
            ),
            'sameVessel' => strings.text('water.errorSameBottle'),
            'waterMissing' => strings.text('water.errorNoWater'),
            'targetNotCleanAndEmpty' ||
            'targetNotEmpty' => strings.text('water.errorTargetNotEmpty'),
            'filteredWaterRequired' => strings.text(
              'water.errorFilteredRequired',
            ),
            'q4.02Locked' ||
            'q4.03Locked' ||
            'orderLocked' ||
            'orderTutorialLocked' => strings.text('meal.errorLessonLocked'),
            'q4.03AlreadyComplete' || 'orderAlreadyCompleted' => strings.text(
              'meal.errorAlreadyComplete',
            ),
            'q3.04StoreItemFirst' => strings.text(
              'woodwork.errorStoreBeforeWithdraw',
            ),
            'q3.04StoredItemMissing' => strings.text(
              'woodwork.errorStoredItemMissing',
            ),
            'q3.04CrateNotPlaced' => strings.text(
              'woodwork.errorCrateNotPlaced',
            ),
            'q3.04StorageItemInvalid' => strings.text(
              'woodwork.errorStorageItemInvalid',
            ),
            'craftOperationActive' => strings.text(
              'craft.errorFinishPendingFirst',
            ),
            'storageCapacityExceeded' => strings.text(
              'woodwork.errorStorageFull',
            ),
            'insufficientInventorySpace' => strings.text(
              'woodwork.errorKitNoSpace',
            ),
            'q4.01InsufficientBackpackSpace' => strings.text(
              'water.errorKitBackpackSpace',
            ),
            'q4.01ContentUnavailable' => strings.text(
              'water.errorContentUnavailable',
            ),
            'staminaFull' => strings.text('meal.errorFullStamina'),
            'invalidStamina' => strings.text('meal.errorInvalidStamina'),
            'inventoryMissing' => strings.text(
              'meal.errorInventoryUnavailable',
            ),
            'mealBoxMissing' ||
            'orderContainerMissing' => strings.text('meal.errorBoxUnavailable'),
            'mealMissing' => strings.text('meal.errorUnknownMeal'),
            'mealNotDeliverable' ||
            'orderItemNotAccepted' => strings.text('meal.errorNotDeliverable'),
            'orderUnavailable' => strings.text('meal.errorOrderUnavailable'),
            'invalidExchangeTicketBalance' ||
            'invalidOrderBalance' => strings.text('meal.errorInvalidBalance'),
            'orderSelectionInvalid' => strings.text('meal.errorOrderSelection'),
            _ when error.message.startsWith('No fitting space for ') =>
              strings.text('woodwork.errorKitNoSpace'),
            _ => strings.text('game.errorOperationFailed'),
          },
        );
      }
    } on Object {
      if (mounted) {
        setState(
          () => _error = StreetScrapLocalizations.of(
            context,
          ).text('woodwork.errorSaveUnconfirmed'),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = StreetScrapLocalizations.of(context);
    final chapter = widget.session.snapshot.state['chapter'] as int? ?? 0;
    final craftOperationActive =
        widget.session.snapshot.state['craftOperation'] is Map;
    final tasks = widget.session.snapshot.state['tutorialTasks'];
    final unlocked = chapter >= 3 && tasks is Map && tasks['q2.03'] == true;
    if (!unlocked) {
      return StreetScrapLockedActivityPanel(
        featureId: 'woodworking',
        title: strings.text('woodwork.workbenchTitle'),
        unlockLabel: strings.text(
          'recipes.lockedPhase',
          arguments: {'phase': '3'},
        ),
        icon: Icons.handyman_rounded,
      );
    }
    final kitClaimed = tasks['q3.01.kitClaimed'] == true;
    final complete = tasks['q3.01'] == true;
    final nailBoardComplete = tasks['q3.02'] == true;
    final nailKitInventory = _currentInventory;
    final placedNailRodCount = nailKitInventory.placements.keys
        .map((id) => nailKitInventory.objects[id]!)
        .where((item) => item.itemId == 'wood.rod')
        .length;
    final placedNailBundleExists = nailKitInventory.placements.keys
        .map((id) => nailKitInventory.objects[id]!)
        .any((item) => item.itemId == 'metal.nail_bundle');
    final nailKitNeedsSupply =
        tasks['q3.02.kitClaimed'] != true ||
        placedNailRodCount < 3 ||
        !placedNailBundleExists;
    final repairComplete = tasks['q3.03'] == true;
    final crateKitClaimed = tasks['q3.04.kitClaimed'] == true;
    final crateCrafted = tasks['q3.04.crateCrafted'] == true;
    final cratePlaced = tasks['q3.04.placed'] == true;
    final crateComplete = tasks['q3.04'] == true;
    final bagUpgraded = tasks['q3.05'] == true;
    final chapterFiveUnlocked = chapter >= 5 && tasks['q5.01'] == true;
    final mineralSourceAvailable =
        chapter >= 5 &&
        widget.session.contentVersions.containsKey(
          streetScrapChapter5ResourceId,
        );
    final chapterFiveStructuresPlaced =
        tasks['q5.02.shelterPlaced'] == true &&
        tasks['q5.02.chestPlaced'] == true;
    final chapterFiveOrders =
        widget.session.snapshot.state['completedCycleOrders'] as int? ?? 0;
    final rawHomeStructures = widget.session.snapshot.state['homeStructures'];
    final placedHomeShelter = rawHomeStructures is Map
        ? rawHomeStructures['q5.02.shelter']
        : null;
    final chapterFiveShelterSupport = placedHomeShelter is Map
        ? (placedHomeShelter['supportBonusPercent'] as int? ?? 0)
        : 0;
    final backpackCapacity =
        widget.session.snapshot.state['backpackCapacity'] as int? ?? 16;
    final waterVessels = _waterVessels;
    final waterIds = waterVessels.map((item) => item.instanceId).toList();
    final selectedWaterId = waterIds.contains(_selectedWaterVesselId)
        ? _selectedWaterVesselId
        : waterIds.firstOrNull;
    final selectedTargetId = waterIds.contains(_selectedTargetVesselId)
        ? _selectedTargetVesselId
        : waterIds.where((id) => id != selectedWaterId).firstOrNull;
    final chapter5Inventory = _currentInventory;
    final chapter5Shelters = chapter5Inventory.objects.values
        .where(
          (item) =>
              item.itemId == 'structure.shelter' &&
              chapter5Inventory.placements.containsKey(item.instanceId),
        )
        .toList(growable: false);
    final chapter5Chests = chapter5Inventory.objects.values
        .where(
          (item) =>
              item.itemId == 'storage.reinforced_chest' &&
              chapter5Inventory.placements.containsKey(item.instanceId),
        )
        .toList(growable: false);
    final selectedChapter5Shelter =
        chapter5Shelters
            .where((item) => item.instanceId == _selectedChapterFiveShelterId)
            .firstOrNull ??
        chapter5Shelters.firstOrNull;
    final selectedChapter5Chest =
        chapter5Chests
            .where((item) => item.instanceId == _selectedChapterFiveChestId)
            .firstOrNull ??
        chapter5Chests.firstOrNull;
    final chapterFiveChestItemCount =
        (chapter5Inventory.storage[streetScrapChapter5ChestStorageId] ??
                const <String>[])
            .length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (craftOperationActive) ...[
                    SizedBox(
                      key: const Key('street-scrap-workbench-protagonist'),
                      height: 34,
                      child: StreetScrapProtagonistSprite(
                        pose: 3,
                        height: 34,
                        art: widget.protagonistArt,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      strings.text('woodwork.workbenchTitle'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (!complete)
                _woodRecipeFlow(
                  strings,
                  inputs: const {'wood.chip': 3, 'adhesive.recycled': 1},
                  outputItemId: 'wood.rod',
                )
              else if (!nailBoardComplete)
                _woodRecipeFlow(
                  strings,
                  inputs: const {'wood.rod': 3, 'metal.nail_bundle': 1},
                  outputItemId: 'wood.board',
                ),
              ExpansionTile(
                key: ValueKey(
                  'street-scrap-woodwork-details-$complete-$nailBoardComplete-$repairComplete-$crateComplete-$bagUpgraded',
                ),
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                leading: const Icon(Icons.info_outline_rounded),
                title: Text(strings.text('recipe.detailInfo')),
                children: [
                  Text(
                    crateComplete
                        ? bagUpgraded
                              ? strings.text(
                                  'woodwork.crateAndBagComplete',
                                  arguments: {'capacity': '$backpackCapacity'},
                                )
                              : strings.text(
                                  'woodwork.crateCompleteBagOptional',
                                  arguments: {'capacity': '$backpackCapacity'},
                                )
                        : repairComplete
                        ? strings.text('woodwork.repairCompleteStatus')
                        : nailBoardComplete
                        ? strings.text('woodwork.nailCompleteStatus')
                        : complete
                        ? strings.text('woodwork.pressCompleteStatus')
                        : strings.text('woodwork.pressInstructions'),
                  ),
                  if (!kitClaimed && !complete)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(strings.text('woodwork.pressKitDescription')),
                    ),
                  if (complete && !nailBoardComplete && nailKitNeedsSupply)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(strings.text('woodwork.nailKitDescription')),
                    ),
                ],
              ),
              if (!kitClaimed && !complete) ...[
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonal(
                    onPressed: _busy || widget.session.isReadOnly
                        ? null
                        : _claimKit,
                    child: Text(
                      _busy
                          ? strings.text('woodwork.claimingMaterials')
                          : strings.text('woodwork.claimPressKit'),
                    ),
                  ),
                ),
              ],
              if (complete && !nailBoardComplete && nailKitNeedsSupply) ...[
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonal(
                    onPressed: _busy || widget.session.isReadOnly
                        ? null
                        : _claimNailKit,
                    child: Text(
                      _busy
                          ? strings.text('woodwork.claimingMaterials')
                          : strings.text(
                              tasks['q3.02.kitClaimed'] == true
                                  ? 'woodwork.replenishNailKit'
                                  : 'woodwork.claimNailKit',
                            ),
                    ),
                  ),
                ),
              ],
              if (nailBoardComplete && !repairComplete) ...[
                const SizedBox(height: 8),
                if (tasks['q3.03.kitClaimed'] != true) ...[
                  Text(strings.text('woodwork.repairKitDescription')),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonal(
                      onPressed: _busy || widget.session.isReadOnly
                          ? null
                          : _claimRepairKit,
                      child: Text(
                        _busy
                            ? strings.text('woodwork.claimingMaterials')
                            : strings.text('woodwork.claimRepairKit'),
                      ),
                    ),
                  ),
                ] else if (_repairKitNeedsSupply) ...[
                  Text(strings.text('woodwork.repairKitDescription')),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonal(
                      onPressed: _busy || widget.session.isReadOnly
                          ? null
                          : _claimRepairKit,
                      child: Text(
                        _busy
                            ? strings.text('woodwork.claimingMaterials')
                            : strings.text('woodwork.replenishRepairKit'),
                      ),
                    ),
                  ),
                ] else
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonal(
                      onPressed: _busy || widget.session.isReadOnly
                          ? null
                          : _repairTutorialCrowbar,
                      child: Text(
                        _busy
                            ? strings.text('woodwork.repairingCrowbar')
                            : strings.text('woodwork.repairCrowbar'),
                      ),
                    ),
                  ),
              ],
              if ((widget.session.snapshot.state['chapter'] as int? ?? 0) >=
                      3 &&
                  widget.repairCatalog != null &&
                  !_tutorialRepairPending) ...[
                const SizedBox(height: 12),
                ExpansionTile(
                  key: const Key('street-scrap-repair-rules'),
                  tilePadding: EdgeInsets.zero,
                  leading: const Icon(Icons.build_circle_outlined),
                  title: Text(
                    strings.text('repair.title'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  children: [Text(strings.text('repair.rules'))],
                ),
                DropdownButtonFormField<String>(
                  initialValue:
                      _repairableTools.any(
                        (item) => item.instanceId == _selectedRepairToolId,
                      )
                      ? _selectedRepairToolId
                      : null,
                  decoration: InputDecoration(
                    labelText: strings.text('repair.selectTool'),
                  ),
                  items: _repairableTools
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.instanceId,
                          child: Text(
                            strings.text(
                              'repair.toolOption',
                              arguments: {
                                'name': _repairItemName(item.itemId, strings),
                                'durability': '${item.toolDurability}',
                              },
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _busy || widget.session.isReadOnly
                      ? null
                      : (value) => setState(() {
                          _selectedRepairToolId = value;
                          _selectedRepairRuleId = _repairRulesFor(
                            _repairableTools
                                .where((item) => item.instanceId == value)
                                .firstOrNull,
                          ).firstOrNull?.id;
                          _selectedRepairMaterialIds.clear();
                        }),
                ),
                Builder(
                  builder: (context) {
                    final tool = _repairableTools
                        .where(
                          (item) => item.instanceId == _selectedRepairToolId,
                        )
                        .firstOrNull;
                    final rules = _repairRulesFor(tool);
                    return rules.length < 2
                        ? const SizedBox.shrink()
                        : DropdownButtonFormField<String>(
                            initialValue:
                                rules.any(
                                  (rule) => rule.id == _selectedRepairRuleId,
                                )
                                ? _selectedRepairRuleId
                                : rules.firstOrNull?.id,
                            decoration: InputDecoration(
                              labelText: strings.text('repair.selectMethod'),
                            ),
                            items: rules
                                .map(
                                  (rule) => DropdownMenuItem(
                                    value: rule.id,
                                    child: Text(
                                      strings.text(
                                        rule.phase >= 5
                                            ? 'repair.preciseMethod'
                                            : 'repair.generalMethod',
                                        arguments: {
                                          'uses': '${rule.restoreUses}',
                                        },
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: _busy || widget.session.isReadOnly
                                ? null
                                : (value) => setState(() {
                                    _selectedRepairRuleId = value;
                                    _selectedRepairMaterialIds.clear();
                                  }),
                          );
                  },
                ),
                Builder(
                  builder: (context) {
                    final tool = _repairableTools
                        .where(
                          (item) => item.instanceId == _selectedRepairToolId,
                        )
                        .firstOrNull;
                    final rule = _repairRuleFor(tool);
                    final materials = _repairMaterialsFor(tool);
                    final maxSelected =
                        rule?.materialOptions
                            .map((option) => option.length)
                            .fold<int>(
                              0,
                              (current, count) =>
                                  count > current ? count : current,
                            ) ??
                        0;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(strings.text('repair.selectMaterials')),
                        ),
                        for (final item in materials)
                          CheckboxListTile(
                            controlAffinity: ListTileControlAffinity.trailing,
                            contentPadding: EdgeInsets.zero,
                            secondary: StreetScrapItemSprite(
                              itemId: item.itemId,
                              source: item.source,
                              size: 48,
                            ),
                            title: Text(strings.itemName(item.itemId)),
                            subtitle: Text(
                              strings.itemQuality(item.quality),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            value: _selectedRepairMaterialIds.contains(
                              item.instanceId,
                            ),
                            onChanged: _busy || widget.session.isReadOnly
                                ? null
                                : (checked) => setState(() {
                                    if (checked == true &&
                                        _selectedRepairMaterialIds.length <
                                            maxSelected &&
                                        _repairSelectionCanAdd(
                                          rule,
                                          _selectedRepairMaterialIds,
                                          item.instanceId,
                                        )) {
                                      _selectedRepairMaterialIds.add(
                                        item.instanceId,
                                      );
                                    } else if (checked != true) {
                                      _selectedRepairMaterialIds.remove(
                                        item.instanceId,
                                      );
                                    }
                                  }),
                          ),
                      ],
                    );
                  },
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonal(
                    onPressed:
                        _busy ||
                            widget.session.isReadOnly ||
                            !_repairSelectionMatches(
                              _repairRuleFor(
                                _repairableTools
                                    .where(
                                      (item) =>
                                          item.instanceId ==
                                          _selectedRepairToolId,
                                    )
                                    .firstOrNull,
                              ),
                              _selectedRepairMaterialIds,
                            )
                        ? null
                        : _repairSelectedTool,
                    child: Text(
                      strings.text(
                        _busy ? 'repair.inProgress' : 'repair.action',
                        arguments: {
                          'uses':
                              '${_repairRuleFor(_repairableTools.where((item) => item.instanceId == _selectedRepairToolId).firstOrNull)?.restoreUses ?? 0}',
                        },
                      ),
                    ),
                  ),
                ),
              ],
              if (repairComplete && !crateKitClaimed && !crateComplete) ...[
                const SizedBox(height: 8),
                Text(strings.text('woodwork.crateKitDescription')),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonal(
                    onPressed: _busy || widget.session.isReadOnly
                        ? null
                        : _claimCrateKit,
                    child: Text(
                      _busy
                          ? strings.text('woodwork.claimingMaterials')
                          : strings.text('woodwork.claimCrateMaterials'),
                    ),
                  ),
                ),
              ],
              if (crateKitClaimed && !crateCrafted && !crateComplete)
                Text(strings.text('woodwork.crateReady')),
              if (crateCrafted && !cratePlaced && !crateComplete)
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonal(
                    onPressed: _busy || widget.session.isReadOnly
                        ? null
                        : _placeCrate,
                    child: Text(
                      _busy
                          ? strings.text('woodwork.placingCrate')
                          : strings.text('woodwork.placeCrate'),
                    ),
                  ),
                ),
              if (cratePlaced && !crateComplete) ...[
                Text(
                  strings.text(
                    'woodwork.crateStorage',
                    arguments: {
                      'count':
                          '${(_currentInventory.storage[streetScrapTutorialCrateStorageId] ?? const []).length}',
                    },
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 8,
                    children: [
                      FilledButton.tonal(
                        onPressed: _busy || widget.session.isReadOnly
                            ? null
                            : _storeOneItem,
                        child: Text(strings.text('woodwork.storeOne')),
                      ),
                      OutlinedButton(
                        onPressed: _busy || widget.session.isReadOnly
                            ? null
                            : _withdrawOneItem,
                        child: Text(strings.text('woodwork.withdrawOne')),
                      ),
                    ],
                  ),
                ),
              ],
              if (crateComplete && chapter >= 4) ...[
                const Divider(),
                Text(
                  strings.text('woodwork.waterLessonTitle'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (tasks['q4.01'] != true ||
                    tasks['q4.02'] != true ||
                    tasks['q4.03'] != true)
                  Text(strings.text('woodwork.waterLessonDescription')),
                if (tasks['q4.01'] != true && tasks['q4.01.kitClaimed'] != true)
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonal(
                      onPressed: _busy || widget.session.isReadOnly
                          ? null
                          : _claimWaterKit,
                      child: Text(
                        _busy
                            ? strings.text('woodwork.claimingMaterials')
                            : strings.text('woodwork.claimWaterKit'),
                      ),
                    ),
                  )
                else if (tasks['q4.01'] != true)
                  Text(strings.text('woodwork.waterKitReady')),
                if (tasks['q4.01'] == true)
                  _completedWaterLessonStep(
                    strings,
                    icon: Icons.water_drop_outlined,
                    shortLabel: 'woodwork.lessonFiltered',
                    accessibilityLabel: 'woodwork.filteringComplete',
                  ),
                if (tasks['q4.01'] == true && tasks['q4.02'] != true) ...[
                  const SizedBox(height: 8),
                  Text(strings.text('woodwork.soupKitDescription')),
                  if (tasks['q4.02.kitClaimed'] != true)
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.tonal(
                        onPressed: _busy || widget.session.isReadOnly
                            ? null
                            : _claimSoupKit,
                        child: Text(
                          _busy
                              ? strings.text('woodwork.claimingMaterials')
                              : strings.text('woodwork.claimSoupKit'),
                        ),
                      ),
                    )
                  else
                    Text(strings.text('woodwork.soupKitReady')),
                ],
                if (tasks['q4.02'] == true)
                  _completedWaterLessonStep(
                    strings,
                    icon: Icons.soup_kitchen_outlined,
                    shortLabel: 'woodwork.lessonCooked',
                    accessibilityLabel: 'woodwork.soupComplete',
                  ),
                if (tasks['q4.02'] == true && tasks['q4.03'] != true) ...[
                  const SizedBox(height: 8),
                  Text(strings.text('woodwork.selfServeDescription')),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonal(
                      onPressed:
                          _busy ||
                              widget.session.isReadOnly ||
                              (widget.session.snapshot.state['stamina']
                                          as int? ??
                                      widget.maxStamina) >=
                                  widget.maxStamina
                          ? null
                          : _eatSoup,
                      child: Text(
                        _busy
                            ? strings.text('woodwork.processingMeal')
                            : strings.text('woodwork.consumeMeal'),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton(
                      onPressed: _busy || widget.session.isReadOnly
                          ? null
                          : _deliverSoup,
                      child: Text(
                        _busy
                            ? strings.text('woodwork.processingMeal')
                            : strings.text('woodwork.deliverMeal'),
                      ),
                    ),
                  ),
                ],
                if (tasks['q4.03'] == true)
                  _completedWaterLessonStep(
                    strings,
                    icon: Icons.restaurant_outlined,
                    shortLabel: 'woodwork.lessonMealUsed',
                    accessibilityLabel: 'woodwork.mealChoiceComplete',
                  ),
                if (chapter >= 4) ...[
                  const Divider(),
                  Text(
                    strings.text('water.title'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Semantics(
                    label: strings.text('water.rules'),
                    child: ExcludeSemantics(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 2,
                        children: [
                          _waterRuleBadge(
                            strings,
                            icon: Icons.bolt_rounded,
                            labelKey: 'water.rule.fill.short',
                            detailKey: 'water.rule.fill.detail',
                          ),
                          _waterRuleBadge(
                            strings,
                            icon: Icons.swap_horiz_rounded,
                            labelKey: 'water.rule.pour.short',
                            detailKey: 'water.rule.pour.detail',
                          ),
                          _waterRuleBadge(
                            strings,
                            icon: Icons.cleaning_services_outlined,
                            labelKey: 'water.rule.wash.short',
                            detailKey: 'water.rule.wash.detail',
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (waterIds.isEmpty)
                    Text(strings.text('water.noVessels'))
                  else ...[
                    DropdownButton<String>(
                      key: const Key('street-scrap-water-vessel'),
                      isExpanded: true,
                      value: selectedWaterId,
                      items: [
                        for (final item in waterVessels)
                          DropdownMenuItem(
                            value: item.instanceId,
                            child: Text(
                              strings.text(
                                'water.vessel',
                                arguments: {
                                  'id': strings.itemName(item.itemId),
                                  'content':
                                      item.containerState['contentItemId']
                                          is String
                                      ? strings.itemName(
                                          item.containerState['contentItemId']
                                              as String,
                                        )
                                      : strings.text('water.emptyBottle'),
                                  'quality':
                                      item.containerState['contentQuality']
                                          is int
                                      ? ' · ${strings.itemQuality(item.containerState['contentQuality'] as int)}'
                                      : '',
                                  'cleanliness':
                                      item.containerState['cleanliness'] ==
                                          'clean'
                                      ? strings.text('water.clean')
                                      : strings.text('water.unwashed'),
                                },
                              ),
                            ),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _selectedWaterVesselId = value),
                    ),
                    DropdownButton<String>(
                      key: const Key('street-scrap-water-source'),
                      isExpanded: true,
                      value:
                          _selectedWaterSourceId ==
                                  'new-neighborhood-mineral' &&
                              mineralSourceAvailable
                          ? _selectedWaterSourceId
                          : const {
                              'shore-turbid',
                              'shore-dirty',
                              'shore-muddy',
                            }.contains(_selectedWaterSourceId)
                          ? _selectedWaterSourceId
                          : 'shore-turbid',
                      items: [
                        DropdownMenuItem(
                          value: 'shore-turbid',
                          child: Text(strings.text('water.sourceTurbid')),
                        ),
                        DropdownMenuItem(
                          value: 'shore-dirty',
                          child: Text(strings.text('water.sourceDirty')),
                        ),
                        DropdownMenuItem(
                          value: 'shore-muddy',
                          child: Text(strings.text('water.sourceMuddy')),
                        ),
                        if (mineralSourceAvailable)
                          DropdownMenuItem(
                            value: 'new-neighborhood-mineral',
                            child: Text(strings.text('water.sourceMineral')),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _selectedWaterSourceId = value),
                    ),
                    if (selectedTargetId != null)
                      DropdownButton<String>(
                        isExpanded: true,
                        value: selectedTargetId,
                        items: [
                          for (final item in waterVessels.where(
                            (item) => item.instanceId != selectedWaterId,
                          ))
                            DropdownMenuItem(
                              value: item.instanceId,
                              child: Text(
                                strings.text(
                                  'water.target',
                                  arguments: {
                                    'id': strings.itemName(item.itemId),
                                  },
                                ),
                              ),
                            ),
                        ],
                        onChanged: (value) =>
                            setState(() => _selectedTargetVesselId = value),
                      ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed:
                              _busy ||
                                  widget.session.isReadOnly ||
                                  selectedWaterId == null
                              ? null
                              : () => _fillWater('public-refill'),
                          child: Text(strings.text('water.fillFiltered')),
                        ),
                        OutlinedButton(
                          onPressed:
                              _busy ||
                                  widget.session.isReadOnly ||
                                  selectedWaterId == null
                              ? null
                              : () => _fillWater(
                                  _selectedWaterSourceId ?? 'shore-turbid',
                                ),
                          child: Text(strings.text('water.fillSelected')),
                        ),
                        OutlinedButton(
                          onPressed:
                              _busy ||
                                  widget.session.isReadOnly ||
                                  selectedTargetId == null
                              ? null
                              : _pourWater,
                          child: Text(strings.text('water.pour')),
                        ),
                        OutlinedButton(
                          onPressed:
                              _busy ||
                                  widget.session.isReadOnly ||
                                  selectedWaterId == null
                              ? null
                              : _emptyWater,
                          child: Text(strings.text('water.empty')),
                        ),
                        OutlinedButton(
                          onPressed:
                              _busy ||
                                  widget.session.isReadOnly ||
                                  selectedTargetId == null
                              ? null
                              : _washVessel,
                          child: Text(strings.text('water.wash')),
                        ),
                        FilledButton.tonal(
                          onPressed: _busy || widget.session.isReadOnly
                              ? null
                              : widget.onOpenRecipes,
                          child: Text(strings.text('water.boil')),
                        ),
                      ],
                    ),
                  ],
                ],
              ],
              if (chapterFiveUnlocked) ...[
                const Divider(),
                Text(
                  strings.text('woodwork.chapter5Goal'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  strings.text(
                    'woodwork.chapter5Orders',
                    arguments: {'completed': '$chapterFiveOrders'},
                  ),
                ),
                Text(
                  chapterFiveStructuresPlaced
                      ? strings.text(
                          'woodwork.chapter5StructuresPlaced',
                          arguments: {'support': '$chapterFiveShelterSupport'},
                        )
                      : strings.text('woodwork.chapter5StructuresNeeded'),
                ),
                if (!chapterFiveStructuresPlaced && chapter5Shelters.isNotEmpty)
                  DropdownButton<String>(
                    key: const Key('street-scrap-q502-select-shelter'),
                    isExpanded: true,
                    value: selectedChapter5Shelter?.instanceId,
                    hint: Text(strings.text('woodwork.selectShelter')),
                    items: [
                      for (final item in chapter5Shelters)
                        DropdownMenuItem(
                          value: item.instanceId,
                          child: Text(
                            strings.text(
                              'woodwork.chapter5ShelterItem',
                              arguments: {
                                'id': strings.itemName(item.itemId),
                                'quality': '${item.quality}',
                                'support':
                                    '${item.traits['joint_reinforced'] == true ? 10 : 0}',
                              },
                            ),
                          ),
                        ),
                    ],
                    onChanged: (value) =>
                        setState(() => _selectedChapterFiveShelterId = value),
                  ),
                if (!chapterFiveStructuresPlaced && chapter5Chests.isNotEmpty)
                  DropdownButton<String>(
                    key: const Key('street-scrap-q502-select-chest'),
                    isExpanded: true,
                    value: selectedChapter5Chest?.instanceId,
                    hint: Text(strings.text('woodwork.selectChest')),
                    items: [
                      for (final item in chapter5Chests)
                        DropdownMenuItem(
                          value: item.instanceId,
                          child: Text(
                            strings.text(
                              'woodwork.chapter5ChestItem',
                              arguments: {
                                'id': strings.itemName(item.itemId),
                                'quality': '${item.quality}',
                              },
                            ),
                          ),
                        ),
                    ],
                    onChanged: (value) =>
                        setState(() => _selectedChapterFiveChestId = value),
                  ),
                if (!chapterFiveStructuresPlaced)
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonal(
                      key: const Key('street-scrap-place-q502-structures'),
                      onPressed:
                          _busy ||
                              widget.session.isReadOnly ||
                              chapter5Shelters.isEmpty ||
                              chapter5Chests.isEmpty
                          ? null
                          : _placeChapterFiveStructures,
                      child: Text(
                        _busy
                            ? strings.text('woodwork.placingStructures')
                            : strings.text('woodwork.placeStructures'),
                      ),
                    ),
                  ),
                if (chapterFiveStructuresPlaced) ...[
                  Text(
                    strings.text(
                      'woodwork.chapter5Storage',
                      arguments: {'count': '$chapterFiveChestItemCount'},
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        key: const Key('street-scrap-q502-store'),
                        onPressed: _busy || widget.session.isReadOnly
                            ? null
                            : _storeOneChapterFiveChestItem,
                        child: Text(strings.text('woodwork.storeOne')),
                      ),
                      OutlinedButton(
                        key: const Key('street-scrap-q502-withdraw'),
                        onPressed: _busy || widget.session.isReadOnly
                            ? null
                            : _withdrawOneChapterFiveChestItem,
                        child: Text(strings.text('woodwork.withdrawOne')),
                      ),
                    ],
                  ),
                ],
                if (tasks['q5.02'] == true)
                  Text(strings.text('woodwork.chapter5Complete')),
              ],
              if (_error != null)
                Text(
                  strings.text(
                    'woodwork.actionFailed',
                    arguments: {'details': _error!},
                  ),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: widget.onOpenRecipes,
                  icon: const Icon(Icons.handyman_outlined),
                  label: Text(strings.text('woodwork.openRecipes')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
