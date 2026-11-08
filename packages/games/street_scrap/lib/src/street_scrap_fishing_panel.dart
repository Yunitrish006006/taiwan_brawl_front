import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'street_scrap_fishing.dart';
import 'street_scrap_inventory.dart';
import 'street_scrap_progress.dart';
import 'street_scrap_audio.dart';
import 'street_scrap_localizations.dart';
import 'street_scrap_locked_activity_panel.dart';
import 'street_scrap_item_sprite.dart';

class StreetScrapFishingPanel extends StatefulWidget {
  const StreetScrapFishingPanel({
    super.key,
    required this.session,
    required this.rules,
    required this.defaultStamina,
    required this.catalog,
    required this.grids,
    this.materialAtlasBytes,
    this.fishingSceneArtBytes,
    this.assistedControls = false,
    this.onChanged,
    this.onSound,
  });

  final StreetScrapSession session;
  final StreetScrapFishingRules rules;
  final int defaultStamina;
  final StreetScrapInventoryCatalog catalog;
  final Map<String, StreetScrapGridSpec> grids;
  final Uint8List? materialAtlasBytes;
  final Uint8List? fishingSceneArtBytes;
  final bool assistedControls;
  final VoidCallback? onChanged;
  final ValueChanged<StreetScrapAudioCue>? onSound;

  @override
  State<StreetScrapFishingPanel> createState() =>
      _StreetScrapFishingPanelState();
}

class _StreetScrapFishingPanelState extends State<StreetScrapFishingPanel> {
  bool _saving = false;
  String? _error;
  Timer? _signalTimer;
  bool _heldForSignal = false;
  bool _stayedInPrompt = false;
  double _promptWidth = 0;

  String _spotLabel(StreetScrapLocalizations strings, Object? rawSpotId) {
    final spotId = rawSpotId is String ? rawSpotId : '';
    for (final spot in widget.rules.spots) {
      if (spot.id == spotId) {
        return strings.fishingSpotName(spotId, spot.name);
      }
    }
    return strings.fishingSpotName(
      spotId,
      strings.text('fishing.spot.unknown'),
    );
  }

  String _friendlyError(Object error) {
    final strings = StreetScrapLocalizations.of(context);
    if (error is StreetScrapConcurrentWrite ||
        error is StreetScrapStaleRevision) {
      return strings.text('fishing.error.concurrentWrite');
    }
    if (error is FormatException) {
      return strings.text('fishing.error.saveMalformed');
    }
    if (error is StateError && error.message.toString().contains('space')) {
      return strings.text('board.error.noSpace');
    }
    final code = error is StateError ? error.message.toString() : '';
    final key = switch (code) {
      'fishingLocked' || 'fishingSpotLocked' => 'fishing.error.locked',
      'fishingEquipmentUnavailable' => 'fishing.error.equipmentUnavailable',
      'craftInProgress' ||
      'expeditionMustBeResolved' ||
      'fishingActivityPending' => 'fishing.error.otherActivityPending',
      'fishingResultMustBeClaimed' => 'fishing.error.claimPrevious',
      'insufficientStamina' => 'fishing.error.insufficientStamina',
      'fishingActivityMissing' ||
      'fishingSignalSequenceInvalid' => 'fishing.error.activityUnavailable',
      'fishingResultMissing' ||
      'fishingRewardChoiceInvalid' ||
      'fishingInventoryMissing' => 'fishing.error.resultUnavailable',
      'raftLocked' || 'floatLocked' => 'fishing.error.locked',
      'raftAlreadyPlaced' ||
      'raftNotPlaced' ||
      'floatAlreadyEquipped' ||
      'floatNotEquipped' ||
      'floatUnavailable' ||
      'raftUnavailable' ||
      'raftTargetGridInvalid' ||
      'floatTargetGridInvalid' => 'fishing.error.equipmentUnavailable',
      'q2.02FishRequired' ||
      'q2.03AlreadyComplete' ||
      'wholeFishUnavailable' => 'fishing.error.dispositionUnavailable',
      _ => null,
    };
    return strings.text(key ?? 'fishing.error.operationFailed');
  }

  @override
  void dispose() {
    _signalTimer?.cancel();
    super.dispose();
  }

  Future<void> _cast(StreetScrapFishingSpot spot) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final revision = widget.session.snapshot.revision;
      await castStreetScrapLine(
        session: widget.session,
        commandId: 'cast-${spot.id}-$revision',
        expectedRevision: revision,
        rules: widget.rules,
        spotId: spot.id,
        defaultStamina: widget.defaultStamina,
      );
      widget.onSound?.call(StreetScrapAudioCue.tap);
      widget.onChanged?.call();
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _resolveSignal({required int heldMilliseconds}) async {
    final revision = widget.session.snapshot.revision;
    setState(() => _saving = true);
    try {
      final result = await resolveStreetScrapFishingSignal(
        session: widget.session,
        commandId: 'signal-$revision',
        expectedRevision: revision,
        rules: widget.rules,
        heldMilliseconds: heldMilliseconds,
      );
      final details = result.result;
      if (details is Map && details['complete'] == true) {
        final pending = details['result'];
        widget.onSound?.call(
          pending is Map && pending['kind'] == 'fish'
              ? StreetScrapAudioCue.success
              : StreetScrapAudioCue.miss,
        );
      } else {
        widget.onSound?.call(StreetScrapAudioCue.tap);
      }
      widget.onChanged?.call();
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _claim({String? failureItemId}) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final revision = widget.session.snapshot.revision;
      await claimStreetScrapFishingResult(
        session: widget.session,
        commandId: 'claim-fishing-$revision',
        expectedRevision: revision,
        catalog: widget.catalog,
        grids: widget.grids,
        backpackGridId: 'backpack',
        failureRewardItemId: failureItemId,
      );
      widget.onSound?.call(StreetScrapAudioCue.pickup);
      widget.onChanged?.call();
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _runEquipmentAction(
    Future<StreetScrapCommandResult> Function(int revision) action,
  ) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await action(widget.session.snapshot.revision);
      widget.onSound?.call(StreetScrapAudioCue.tap);
      widget.onChanged?.call();
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _equipFloat(String instanceId) => _runEquipmentAction(
    (revision) => equipStreetScrapFishingFloat(
      session: widget.session,
      commandId: 'equip-fishing-float-$revision',
      expectedRevision: revision,
      catalog: widget.catalog,
      grids: widget.grids,
      floatInstanceId: instanceId,
    ),
  );

  Future<void> _unequipFloat(String gridId) => _runEquipmentAction(
    (revision) => unequipStreetScrapFishingFloat(
      session: widget.session,
      commandId: 'unequip-fishing-float-$revision',
      expectedRevision: revision,
      catalog: widget.catalog,
      grids: widget.grids,
      targetGridId: gridId,
    ),
  );

  Future<void> _placeRaft(String instanceId) => _runEquipmentAction(
    (revision) => placeStreetScrapRaft(
      session: widget.session,
      commandId: 'place-dock-raft-$revision',
      expectedRevision: revision,
      catalog: widget.catalog,
      grids: widget.grids,
      raftInstanceId: instanceId,
    ),
  );

  Future<void> _recallRaft(String gridId) => _runEquipmentAction(
    (revision) => recallStreetScrapRaft(
      session: widget.session,
      commandId: 'recall-dock-raft-$revision',
      expectedRevision: revision,
      catalog: widget.catalog,
      grids: widget.grids,
      targetGridId: gridId,
    ),
  );

  Future<void> _keepWholeFish() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final revision = widget.session.snapshot.revision;
      await keepStreetScrapWholeFish(
        session: widget.session,
        commandId: 'keep-whole-fish-$revision',
        expectedRevision: revision,
        catalog: widget.catalog,
        grids: widget.grids,
      );
      widget.onSound?.call(StreetScrapAudioCue.pickup);
      widget.onChanged?.call();
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = StreetScrapLocalizations.of(context);
    final state = widget.session.snapshot.state;
    final chapter = state['chapter'] as int? ?? 0;
    if (chapter < 2) {
      return StreetScrapLockedActivityPanel(
        featureId: 'fishing',
        title: strings.text('fishing.title'),
        unlockLabel: strings.text(
          'recipes.lockedPhase',
          arguments: {'phase': '2'},
        ),
        icon: Icons.phishing_rounded,
      );
    }
    final rawActivity = state['fishingActivity'];
    final activity = rawActivity is Map ? rawActivity : null;
    final pendingRaw = state['fishingPendingResult'];
    final pending = pendingRaw is Map ? pendingRaw : null;
    final unlocked = state['unlockedFishingSpots'];
    final unlockedIds = unlocked is List
        ? unlocked.whereType<String>().toSet()
        : <String>{};
    final stamina = state['stamina'] as int? ?? widget.defaultStamina;
    final rawInventory = state['inventory'];
    StreetScrapInventory? inventory;
    if (rawInventory is Map) {
      try {
        inventory = widget.catalog.inventoryFromJson(
          grids: widget.grids,
          json: Map<String, Object?>.from(rawInventory),
        );
      } on Object {
        inventory = null;
      }
    }
    final carriedItems = inventory == null
        ? const <StreetScrapObject>[]
        : inventory.objects.values
              .where((item) {
                final gridId = inventory!.placements[item.instanceId]?.gridId;
                return gridId == 'board' || gridId == 'backpack';
              })
              .toList(growable: false);
    final availableFloat = carriedItems
        .where((item) => item.itemId == 'toolpart.float')
        .firstOrNull;
    final availableRaft = carriedItems
        .where((item) => item.itemId == 'structure.raft')
        .firstOrNull;
    final rawEquipment = state['fishingEquipment'];
    final equippedFloat = rawEquipment is Map && rawEquipment['float'] is Map;
    final rawFacilities = state['fishingFacilities'];
    final placedRaft = rawFacilities is Map && rawFacilities['dockRaft'] is Map;
    final canManageEquipment =
        activity == null &&
        pending == null &&
        !_saving &&
        !widget.session.isReadOnly;
    final tasks = state['tutorialTasks'];
    final offerFishDisposition =
        tasks is Map && tasks['q2.02'] == true && tasks['q2.03'] != true;
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final compact = viewportWidth < 520;
    final interactionActive = activity != null || pending != null;
    final signals = (activity?['signals'] as List?)?.length ?? 0;
    final sceneHeight = compact
        ? (viewportHeight * (interactionActive ? .22 : .27))
              .clamp(132.0, 248.0)
              .toDouble()
        : (viewportHeight * (interactionActive ? .35 : .48))
              .clamp(220.0, 440.0)
              .toDouble();
    return Card(
      key: const Key('street-scrap-fishing-panel'),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.phishing_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    strings.text('fishing.title'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                _FishingStatusPill(icon: Icons.bolt_rounded, label: '$stamina'),
              ],
            ),
            const SizedBox(height: 10),
            _FishingScene(
              height: sceneHeight,
              active: activity != null,
              artBytes: widget.fishingSceneArtBytes,
            ),
            if (chapter >= 2 && activity == null && pending == null) ...[
              if (equippedFloat)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: PopupMenuButton<String>(
                    key: const Key('street-scrap-unequip-float'),
                    tooltip: strings.text('fishing.unequipFloat'),
                    enabled: canManageEquipment,
                    onSelected: _unequipFloat,
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'board',
                        child: Text(strings.text('fishing.toBoard')),
                      ),
                      PopupMenuItem(
                        value: 'backpack',
                        child: Text(strings.text('fishing.toBackpack')),
                      ),
                    ],
                    icon: const Icon(Icons.sailing_rounded),
                  ),
                )
              else if (availableFloat != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OutlinedButton.icon(
                    key: const Key('street-scrap-equip-float'),
                    onPressed: canManageEquipment
                        ? () => _equipFloat(availableFloat.instanceId)
                        : null,
                    icon: const Icon(Icons.sailing_rounded),
                    label: Text(strings.text('fishing.equipFloat')),
                  ),
                ),
              if (chapter >= 3 && placedRaft)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: PopupMenuButton<String>(
                    key: const Key('street-scrap-recall-raft'),
                    tooltip: strings.text('fishing.recallRaft'),
                    enabled: canManageEquipment,
                    onSelected: _recallRaft,
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'board',
                        child: Text(strings.text('fishing.toBoard')),
                      ),
                      PopupMenuItem(
                        value: 'backpack',
                        child: Text(strings.text('fishing.toBackpack')),
                      ),
                    ],
                    icon: const Icon(Icons.anchor_rounded),
                  ),
                )
              else if (chapter >= 3 && availableRaft != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OutlinedButton.icon(
                    key: const Key('street-scrap-place-raft'),
                    onPressed: canManageEquipment
                        ? () => _placeRaft(availableRaft.instanceId)
                        : null,
                    icon: const Icon(Icons.anchor_rounded),
                    label: Text(strings.text('fishing.placeRaft')),
                  ),
                ),
            ],
            if (pending != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  SizedBox(
                    width: compact ? 76 : 96,
                    height: compact ? 76 : 96,
                    child: StreetScrapItemSprite(
                      itemId: pending['kind'] == 'fish'
                          ? 'fish.raw'
                          : ((pending['choices'] as List?)?.firstOrNull
                                    as String? ??
                                'wood.driftwood'),
                      source: 'native',
                      size: compact ? 76 : 96,
                      materialAtlasBytes: widget.materialAtlasBytes,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.text(
                            pending['kind'] == 'fish'
                                ? 'fishing.fishLanded'
                                : 'fishing.missed',
                          ),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (pending['kind'] == 'fish')
                          _FishingStatusPill(
                            icon: Icons.star_rounded,
                            label: '${pending['quality']}',
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (pending['kind'] == 'fish')
                FilledButton.icon(
                  key: const Key('street-scrap-claim-fish'),
                  onPressed: _saving || widget.session.isReadOnly
                      ? null
                      : () => _claim(),
                  icon: const Icon(Icons.backpack_rounded),
                  label: Text(
                    strings.text(
                      'fishing.claimWhole',
                      arguments: {'quality': '${pending['quality']}'},
                    ),
                  ),
                )
              else if (pending['choices'] is List)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final itemId
                        in (pending['choices'] as List).whereType<String>())
                      OutlinedButton.icon(
                        key: Key('street-scrap-claim-$itemId'),
                        onPressed: _saving || widget.session.isReadOnly
                            ? null
                            : () => _claim(failureItemId: itemId),
                        icon: Icon(switch (itemId) {
                          'wood.driftwood' => Icons.park_rounded,
                          'fish.bone' => Icons.set_meal_rounded,
                          _ => Icons.category_rounded,
                        }),
                        label: Text(strings.itemName(itemId)),
                      ),
                  ],
                ),
            ] else if (activity != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _spotLabel(strings, activity['spotId']),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text('${activity['costPaid']} ⚡'),
                ],
              ),
              const SizedBox(height: 8),
              _FishingSignalProgress(
                current: signals,
                total: widget.rules.signalsPerCast,
                semanticsLabel: strings.text(
                  'fishing.progress',
                  arguments: {
                    'cost': '${activity['costPaid']}',
                    'signals': '$signals',
                    'total': '${widget.rules.signalsPerCast}',
                  },
                ),
              ),
              const SizedBox(height: 8),
              if (activity['guided'] == true)
                FilledButton(
                  key: const Key('street-scrap-guided-fish'),
                  onPressed: _saving || widget.session.isReadOnly
                      ? null
                      : () => _resolveSignal(
                          heldMilliseconds: widget.rules.signalHoldMilliseconds,
                        ),
                  child: Text(strings.text('fishing.guided')),
                )
              else ...[
                Semantics(
                  liveRegion: true,
                  label: strings.text(
                    widget.assistedControls
                        ? 'fishing.assistedSignalPrompt'
                        : 'fishing.signalPrompt',
                    arguments: {'number': '${signals + 1}'},
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.waves_rounded, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          strings.text(
                            'fishing.signalPromptShort',
                            arguments: {'number': '${signals + 1}'},
                          ),
                        ),
                      ),
                      _FishingStatusPill(
                        icon: Icons.timer_outlined,
                        label:
                            '${widget.rules.signalHoldMilliseconds ~/ 1000}s',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (widget.assistedControls)
                  FilledButton(
                    key: const Key('street-scrap-fishing-assisted-signal'),
                    onPressed: _saving || widget.session.isReadOnly
                        ? null
                        : () => _resolveSignal(
                            heldMilliseconds:
                                widget.rules.signalHoldMilliseconds,
                          ),
                    child: Text(strings.text('fishing.assistedTap')),
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      _promptWidth =
                          constraints.maxWidth *
                          ((activity['promptWidthPercent'] as int?) ??
                              widget.rules.basePromptWidthPercent) /
                          100;
                      return Container(
                        key: const Key('street-scrap-fishing-track'),
                        height: 96,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Listener(
                          key: const Key('street-scrap-fishing-prompt-zone'),
                          onPointerDown: (_) {
                            _heldForSignal = false;
                            _stayedInPrompt = true;
                            _signalTimer?.cancel();
                            _signalTimer = Timer(
                              Duration(
                                milliseconds:
                                    widget.rules.signalHoldMilliseconds,
                              ),
                              () => _heldForSignal = _stayedInPrompt,
                            );
                          },
                          onPointerMove: (event) {
                            if (event.localPosition.dx < 0 ||
                                event.localPosition.dx > _promptWidth ||
                                event.localPosition.dy < 0 ||
                                event.localPosition.dy > 72) {
                              _stayedInPrompt = false;
                              _heldForSignal = false;
                              _signalTimer?.cancel();
                            }
                          },
                          onPointerUp: (_) {
                            _signalTimer?.cancel();
                            _signalTimer = null;
                            if (!_saving) {
                              _resolveSignal(
                                heldMilliseconds:
                                    _heldForSignal && _stayedInPrompt
                                    ? widget.rules.signalHoldMilliseconds
                                    : 0,
                              );
                            }
                            _heldForSignal = false;
                            _stayedInPrompt = false;
                          },
                          onPointerCancel: (_) {
                            _signalTimer?.cancel();
                            _signalTimer = null;
                            _heldForSignal = false;
                            _stayedInPrompt = false;
                          },
                          child: Semantics(
                            button: true,
                            label: strings.text(
                              'fishing.promptZoneSemantics',
                              arguments: {
                                'percent':
                                    '${activity['promptWidthPercent'] as int? ?? widget.rules.basePromptWidthPercent}',
                              },
                            ),
                            child: Container(
                              width: _promptWidth,
                              height: 72,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.touch_app_rounded, size: 22),
                                  Text(strings.text('fishing.promptZoneShort')),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ] else ...[
              for (final spot in widget.rules.spots.where(
                (spot) => unlockedIds.contains(spot.id),
              ))
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          strings.fishingSpotName(spot.id, spot.name),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        key: Key('street-scrap-cast-${spot.id}'),
                        onPressed:
                            _saving ||
                                widget.session.isReadOnly ||
                                stamina < widget.rules.castCost
                            ? null
                            : () => _cast(spot),
                        icon: const Icon(Icons.phishing_rounded),
                        label: Text(
                          strings.text(
                            _saving ? 'fishing.saving' : 'fishing.castShort',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _FishingStatusPill(
                        icon: Icons.bolt_rounded,
                        label: '${widget.rules.castCost}',
                      ),
                    ],
                  ),
                ),
            ],
            if (offerFishDisposition) ...[
              const Divider(height: 24),
              OutlinedButton.icon(
                key: const Key('street-scrap-keep-whole-fish'),
                onPressed: _saving || widget.session.isReadOnly
                    ? null
                    : _keepWholeFish,
                icon: const Icon(Icons.set_meal_rounded),
                label: Text(strings.text('fishing.keepWhole')),
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FishingStatusPill extends StatelessWidget {
  const _FishingStatusPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 16), const SizedBox(width: 4), Text(label)],
      ),
    ),
  );
}

class _FishingSignalProgress extends StatelessWidget {
  const _FishingSignalProgress({
    required this.current,
    required this.total,
    required this.semanticsLabel,
  });
  final int current;
  final int total;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: semanticsLabel,
      child: Row(
        children: [
          for (var i = 0; i < total; i++) ...[
            Expanded(
              child: Container(
                height: 10,
                decoration: BoxDecoration(
                  color: i < current
                      ? colors.primary
                      : colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            if (i != total - 1) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _FishingScene extends StatelessWidget {
  const _FishingScene({
    required this.height,
    required this.active,
    required this.artBytes,
  });
  final double height;
  final bool active;
  final Uint8List? artBytes;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'Pixel-art fishing scene at a quiet Taiwanese harbor',
    child: ClipRRect(
      key: const Key('street-scrap-fishing-scene'),
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (artBytes case final bytes?)
              Image.memory(
                bytes,
                key: const Key('street-scrap-fishing-scene-art'),
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
                filterQuality: FilterQuality.none,
                excludeFromSemantics: true,
              )
            else
              CustomPaint(
                key: const Key('street-scrap-fishing-scene-fallback'),
                painter: _FishingSceneFallbackPainter(),
              ),
            CustomPaint(painter: _FishingScenePainter(active: active)),
          ],
        ),
      ),
    ),
  );
}

class _FishingScenePainter extends CustomPainter {
  const _FishingScenePainter({required this.active});
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = false;
    final rod = Path()
      ..moveTo(size.width * .91, size.height * .57)
      ..lineTo(size.width * .965, size.height * .12)
      ..lineTo(size.width * .98, size.height * .60);
    canvas.drawPath(
      rod,
      paint
        ..color = const Color(0xff273d3b)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );
    canvas.drawCircle(
      Offset(size.width * .98, size.height * .60),
      active ? 6 : 4.5,
      paint
        ..style = PaintingStyle.fill
        ..color = active ? const Color(0xffffcf62) : const Color(0xfff3eee0)
        ..strokeWidth = 0,
    );
  }

  @override
  bool shouldRepaint(covariant _FishingScenePainter oldDelegate) =>
      oldDelegate.active != active;
}

class _FishingSceneFallbackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()..isAntiAlias = false;
    final colors = <Color>[
      const Color(0xffc9e1df),
      const Color(0xff89b9b5),
      const Color(0xff578d91),
      const Color(0xff3e686c),
    ];
    canvas.drawRect(rect, paint..color = colors.first);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * .38, size.width, size.height * .62),
      paint..color = colors[1],
    );
    for (var i = 0; i < 7; i++) {
      final y = size.height * (.49 + i * .065);
      canvas.drawRect(
        Rect.fromLTWH(
          size.width * (.08 + (i % 3) * .28),
          y,
          size.width * .18,
          4,
        ),
        paint..color = i.isEven ? colors[0] : colors[2],
      );
    }
    final hill = Path()
      ..moveTo(0, size.height * .42)
      ..lineTo(size.width * .13, size.height * .23)
      ..lineTo(size.width * .30, size.height * .40)
      ..lineTo(size.width * .46, size.height * .19)
      ..lineTo(size.width * .64, size.height * .41)
      ..lineTo(size.width, size.height * .31)
      ..lineTo(size.width, size.height * .49)
      ..lineTo(0, size.height * .49)
      ..close();
    canvas.drawPath(hill, paint..color = const Color(0xff759c81));
    for (var i = 0; i < 5; i++) {
      canvas.drawRect(
        Rect.fromLTWH(
          size.width * (.08 + i * .09),
          size.height * (.36 + (i % 2) * .045),
          size.width * .07,
          size.height * .1,
        ),
        paint..color = const Color(0xffd7b991),
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * .60,
        size.height * .53,
        size.width * .40,
        size.height * .16,
      ),
      paint..color = const Color(0xff805d43),
    );
    for (var i = 0; i < 6; i++) {
      canvas.drawRect(
        Rect.fromLTWH(
          size.width * (.62 + i * .065),
          size.height * .55,
          5,
          size.height * .12,
        ),
        paint..color = const Color(0xffb58b61),
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(size.width * .82, size.height * .68, 8, size.height * .22),
      paint..color = const Color(0xff654936),
    );
    final personX = size.width * .74;
    canvas.drawRect(
      Rect.fromLTWH(personX, size.height * .28, 13, 13),
      paint..color = const Color(0xff273d3b),
    );
    canvas.drawRect(
      Rect.fromLTWH(personX + 2, size.height * .40, 10, size.height * .17),
      paint..color = const Color(0xff385d58),
    );
    canvas.drawRect(
      Rect.fromLTWH(personX - 5, size.height * .55, 22, 5),
      paint..color = const Color(0xff273d3b),
    );
  }

  @override
  bool shouldRepaint(covariant _FishingSceneFallbackPainter oldDelegate) =>
      false;
}
