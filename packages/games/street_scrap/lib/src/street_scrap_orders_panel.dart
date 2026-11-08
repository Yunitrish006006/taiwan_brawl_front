import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'street_scrap_inventory.dart';
import 'street_scrap_orders.dart';
import 'street_scrap_progress.dart';
import 'street_scrap_module.dart';
import 'street_scrap_audio.dart';
import 'street_scrap_localizations.dart';
import 'street_scrap_item_sprite.dart';

class StreetScrapOrdersPanel extends StatefulWidget {
  const StreetScrapOrdersPanel({
    super.key,
    required this.session,
    required this.inventoryCatalog,
    required this.orderCatalog,
    required this.onChanged,
    this.chapter5Installed = false,
    this.onOpenLibrary,
    this.onSound,
    this.woodBoardSpriteBytes,
    this.threadSpoolSpriteBytes,
    this.materialAtlasBytes,
    this.toolAtlasBytes,
    this.materialPackArtBytes,
    this.mineralPackArtBytes,
    this.woodChipBundleArtBytes,
  });

  final StreetScrapSession session;
  final StreetScrapInventoryCatalog inventoryCatalog;
  final StreetScrapOrderCatalog orderCatalog;
  final VoidCallback onChanged;
  final bool chapter5Installed;
  final VoidCallback? onOpenLibrary;
  final ValueChanged<StreetScrapAudioCue>? onSound;
  final Uint8List? woodBoardSpriteBytes;
  final Uint8List? threadSpoolSpriteBytes;
  final Uint8List? materialAtlasBytes;
  final Uint8List? toolAtlasBytes;
  final Uint8List? materialPackArtBytes;
  final Uint8List? mineralPackArtBytes;
  final Uint8List? woodChipBundleArtBytes;

  @override
  State<StreetScrapOrdersPanel> createState() => _StreetScrapOrdersPanelState();
}

class _OrderRequirementCard extends StatelessWidget {
  const _OrderRequirementCard({
    super.key,
    required this.requirements,
    required this.availableCounts,
    required this.strings,
    required this.selected,
    required this.enabled,
    required this.onTap,
    required this.woodBoardSpriteBytes,
    required this.threadSpoolSpriteBytes,
    required this.materialAtlasBytes,
    required this.toolAtlasBytes,
    required this.materialPackArtBytes,
    required this.mineralPackArtBytes,
    required this.woodChipBundleArtBytes,
  });

  final List<StreetScrapOrderRequirement> requirements;
  final Map<String, int> availableCounts;
  final StreetScrapLocalizations strings;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final Uint8List? woodBoardSpriteBytes;
  final Uint8List? threadSpoolSpriteBytes;
  final Uint8List? materialAtlasBytes;
  final Uint8List? toolAtlasBytes;
  final Uint8List? materialPackArtBytes;
  final Uint8List? mineralPackArtBytes;
  final Uint8List? woodChipBundleArtBytes;

  String get _label => requirements
      .map((entry) => '${strings.itemName(entry.itemId)} × ${entry.quantity}')
      .join(' + ');

  String get _title =>
      requirements.map((entry) => strings.itemName(entry.itemId)).join(' + ');

  String get _availabilityLabel => requirements
      .map(
        (entry) => strings.text(
          'orders.materialAvailability',
          arguments: {
            'available': '${availableCounts[entry.itemId] ?? 0}',
            'required': '${entry.quantity}',
          },
        ),
      )
      .join('；');

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final borderColor = selected ? colors.primary : colors.outlineVariant;
    final spriteSize = requirements.length == 1 ? 108.0 : 48.0;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: '$_label；$_availabilityLabel',
      onTap: enabled ? onTap : null,
      child: ExcludeSemantics(
        child: Material(
          color: selected ? colors.secondaryContainer : colors.surfaceContainer,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onTap : null,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: borderColor, width: selected ? 2 : 1),
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (requirements.length == 1)
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        StreetScrapItemSprite(
                          itemId: requirements.single.itemId,
                          source: 'order:requirement',
                          size: spriteSize,
                          visualScale: 1.28,
                          woodBoardSpriteBytes: woodBoardSpriteBytes,
                          threadSpoolSpriteBytes: threadSpoolSpriteBytes,
                          materialAtlasBytes: materialAtlasBytes,
                          toolAtlasBytes: toolAtlasBytes,
                          materialPackArtBytes: materialPackArtBytes,
                          mineralPackSpriteBytes: mineralPackArtBytes,
                          woodChipBundleSpriteBytes: woodChipBundleArtBytes,
                        ),
                        Positioned(
                          right: -4,
                          bottom: -2,
                          child: _OrderQuantityBadge(
                            quantity: requirements.single.quantity,
                            available:
                                availableCounts[requirements.single.itemId] ??
                                0,
                          ),
                        ),
                      ],
                    )
                  else
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 4,
                      children: [
                        for (final entry in requirements.take(4))
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              StreetScrapItemSprite(
                                itemId: entry.itemId,
                                source: 'order:requirement',
                                size: spriteSize,
                                visualScale: 1.18,
                                woodBoardSpriteBytes: woodBoardSpriteBytes,
                                threadSpoolSpriteBytes: threadSpoolSpriteBytes,
                                materialAtlasBytes: materialAtlasBytes,
                                toolAtlasBytes: toolAtlasBytes,
                                materialPackArtBytes: materialPackArtBytes,
                                mineralPackSpriteBytes: mineralPackArtBytes,
                                woodChipBundleSpriteBytes:
                                    woodChipBundleArtBytes,
                              ),
                              Positioned(
                                right: -2,
                                bottom: -2,
                                child: _OrderQuantityBadge(
                                  quantity: entry.quantity,
                                  available: availableCounts[entry.itemId] ?? 0,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  const SizedBox(height: 2),
                  Text(
                    _title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  if (selected)
                    Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: colors.primary,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderQuantityBadge extends StatelessWidget {
  const _OrderQuantityBadge({required this.quantity, this.available});

  final int quantity;
  final int? available;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      child: Text(
        available == null ? '×$quantity' : '$available/$quantity',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

class _StreetScrapOrdersPanelState extends State<StreetScrapOrdersPanel> {
  final Map<String, int> _groupSelection = {};
  final Map<String, Set<String>> _itemSelection = {};
  final Map<String, String?> _containerSelection = {};
  final Map<String, Set<String>> _containerMultiSelection = {};
  final Map<String, int> _requirementPage = {};
  final Set<String> _busyOrders = {};
  String? _error;

  String _orderName(StreetScrapLocalizations strings, String orderId) {
    final key = 'orders.name.$orderId';
    final localized = strings.text(key);
    return localized == key ? orderId : localized;
  }

  String _orderSource(StreetScrapLocalizations strings, String source) {
    final key = 'orders.source.$source';
    final localized = strings.text(key);
    return localized == key ? source : localized;
  }

  String _recipeName(StreetScrapLocalizations strings, String recipeId) {
    final key = 'orders.recipe.$recipeId';
    final localized = strings.text(key);
    return localized == key ? recipeId : localized;
  }

  String _friendlyError(Object error, String operationKey) {
    final strings = StreetScrapLocalizations.of(context);
    final message = error.toString();
    for (final code in [
      'chapter5PrerequisiteIncomplete',
      'chapter5ExpansionNotInstalled',
      'orderChapterMalformed',
      'cycleOrderSlotsMalformed',
      'cycleOrderCursorMalformed',
      'cycleOrderNotActive',
      'orderUnavailable',
      'orderLocked',
      'orderNotAccepted',
      'orderAlreadyAccepted',
      'orderAlreadyCompleted',
      'tutorialStateMalformed',
      'orderTutorialLocked',
      'orderSourceEventRequired',
      'orderRecipeEventRequired',
      'orderSelectionInvalid',
      'orderContainerMissing',
      'orderItemMissing',
      'orderItemNotAccepted',
      'orderAcceptanceUnavailable',
      'orderAcceptanceStateMalformed',
      'recipeCompletionStateMalformed',
      'inventoryMissing',
      'acceptedCycleOrderCannotBeReplaced',
      'cycleOrderNoReplacement',
      'cycleOrderUnavailable',
      'invalidOrderBalance',
      'invalidCompletedOrderCount',
      'orderCompletionStateMalformed',
      'orderCompletionGroupInvalid',
    ]) {
      if (message.contains(code)) return strings.text('orders.error.$code');
    }
    return strings.text(
      'orders.error.operationFailed',
      arguments: {'operation': strings.text(operationKey)},
    );
  }

  Future<void> _enterChapterFive() async {
    try {
      await widget.session.apply(
        commandId: 'chapter-5-entry-${widget.session.snapshot.revision}',
        expectedRevision: widget.session.snapshot.revision,
        reduce: (state) {
          final tasks = state['tutorialTasks'];
          if (state['chapter'] != 4 ||
              tasks is! Map ||
              tasks['q4.03'] != true) {
            throw StateError('chapter5PrerequisiteIncomplete');
          }
          if (!widget.chapter5Installed ||
              !widget.session.contentVersions.containsKey(
                streetScrapChapter5ResourceId,
              )) {
            throw StateError('chapter5ExpansionNotInstalled');
          }
          return StreetScrapReduction(
            state: {...state, 'chapter': 5},
            result: const {'chapter': 5},
          );
        },
      );
      if (mounted) widget.onChanged();
    } on Object catch (error) {
      if (mounted) {
        setState(
          () => _error = _friendlyError(
            error,
            'orders.operation.enterChapterFive',
          ),
        );
      }
    }
  }

  StreetScrapInventory get _inventory {
    final raw = widget.session.snapshot.state['inventory'];
    if (raw == null) {
      return widget.inventoryCatalog.emptyInventory(
        grids: streetScrapGridSpecsForState(widget.session.snapshot.state),
      );
    }
    if (raw is! Map) throw const FormatException('拾荒物品資料格式錯誤。');
    return widget.inventoryCatalog.inventoryFromJson(
      grids: streetScrapGridSpecsForState(widget.session.snapshot.state),
      json: Map<String, Object?>.from(raw),
    );
  }

  List<StreetScrapOrderRequirement> _group(StreetScrapOrder order) {
    final index = (_groupSelection[order.id] ?? 0).clamp(
      0,
      order.requirementGroups.length - 1,
    );
    return order.requirementGroups[index];
  }

  Map<String, int> _requiredCounts(StreetScrapOrder order) {
    final result = <String, int>{};
    for (final requirement in _group(order)) {
      result.update(
        requirement.itemId,
        (count) => count + requirement.quantity,
        ifAbsent: () => requirement.quantity,
      );
    }
    return result;
  }

  List<String> _selectedContainerIds(
    StreetScrapOrder order,
    List<StreetScrapObject> containers,
  ) {
    final required = _requiredCounts(
      order,
    ).values.fold<int>(0, (a, b) => a + b);
    if (required <= 1) {
      final selected =
          _containerSelection[order.id] ?? containers.firstOrNull?.instanceId;
      return selected == null ? const [] : [selected];
    }
    final selection = _containerMultiSelection[order.id] ?? const <String>{};
    final availableIds = containers.map((item) => item.instanceId).toSet();
    return selection.where(availableIds.contains).toList(growable: false);
  }

  Map<String, int> _selectedContainerCounts(
    StreetScrapOrder order,
    List<StreetScrapObject> containers,
  ) {
    final inventory = _inventory;
    final counts = <String, int>{};
    for (final instanceId in _selectedContainerIds(order, containers)) {
      final item = inventory.objects[instanceId];
      final contentItemId = item?.containerState['contentItemId'];
      if (contentItemId is String) {
        counts.update(contentItemId, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    return counts;
  }

  Map<String, int> _selectedCounts(StreetScrapOrder order) {
    final selected = _itemSelection[order.id] ?? const <String>{};
    final result = <String, int>{};
    for (final id in selected) {
      final item = _inventory.objects[id];
      if (item != null) {
        result.update(item.itemId, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    return result;
  }

  bool _sameCounts(Map<String, int> left, Map<String, int> right) =>
      left.length == right.length &&
      left.entries.every((entry) => right[entry.key] == entry.value);

  List<StreetScrapObject> _backpackItems() {
    final inventory = _inventory;
    return inventory.objects.values
        .where(
          (item) => inventory.placements[item.instanceId]?.gridId == 'backpack',
        )
        .toList(growable: false);
  }

  List<StreetScrapObject> _matchingContainers(StreetScrapOrder order) {
    final inventory = _inventory;
    final acceptedContentItems = _group(
      order,
    ).map((requirement) => requirement.itemId).toSet();
    return inventory.objects.values
        .where((item) {
          return inventory.placements[item.instanceId]?.gridId == 'backpack' &&
              (order.containerItemId == null ||
                  item.itemId == order.containerItemId) &&
              item.containerContents.isEmpty &&
              acceptedContentItems.contains(
                item.containerState['contentItemId'],
              ) &&
              !order.rejectedItems.contains(
                item.containerState['contentItemId'],
              );
        })
        .toList(growable: false);
  }

  Widget _buildContainerCheckbox({
    required StreetScrapOrder order,
    required StreetScrapObject container,
    required int index,
    required Set<String> selectedIds,
    required int requiredCount,
    required bool enabled,
    required StreetScrapLocalizations strings,
  }) {
    final contentItemId = container.containerState['contentItemId']! as String;
    final contentQuality =
        container.containerState['contentQuality'] as int? ?? container.quality;
    return CheckboxListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(
        strings.text(
          'orders.containerOption',
          arguments: {
            'name': strings.itemName(container.itemId),
            'contents': strings.itemName(contentItemId),
            'quality': strings.itemQuality(contentQuality),
            'number': '${index + 1}',
          },
        ),
      ),
      value: selectedIds.contains(container.instanceId),
      onChanged: enabled
          ? (selected) => setState(() {
              final next = Set<String>.of(
                _containerMultiSelection[order.id] ?? selectedIds,
              );
              if (selected == true) {
                if (next.length < requiredCount) next.add(container.instanceId);
              } else {
                next.remove(container.instanceId);
              }
              _containerMultiSelection[order.id] = next;
            })
          : null,
    );
  }

  Future<void> _deliver(StreetScrapOrder order) async {
    final strings = StreetScrapLocalizations.of(context);
    final selectedItems = _itemSelection[order.id] ?? const <String>{};
    final matchingContainers = _matchingContainers(order);
    final selectedContainerIds = _selectedContainerIds(
      order,
      matchingContainers,
    );
    final selectedContainer = selectedContainerIds.length == 1
        ? selectedContainerIds.single
        : null;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          strings.text(
            'orders.confirmTitle',
            arguments: {'order': _orderName(strings, order.id)},
          ),
        ),
        content: Text(
          strings.text(
            order.consumeContainer
                ? 'orders.confirmConsume'
                : order.returnContainer
                ? 'orders.confirmReturn'
                : 'orders.confirmItems',
            arguments: {
              'count': order.consumeContainer || order.returnContainer
                  ? '${order.rewardQuantity}'
                  : '${selectedItems.length}',
              'containers': '${selectedContainerIds.length}',
              'reward': '${order.rewardQuantity}',
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.text('orders.cancelDelivery')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.text('orders.confirmDelivery')),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() {
      _busyOrders.add(order.id);
      _error = null;
    });
    try {
      final result = await deliverStreetScrapOrder(
        session: widget.session,
        commandId: 'order-${order.id}-${DateTime.now().microsecondsSinceEpoch}',
        expectedRevision: widget.session.snapshot.revision,
        orderCatalog: widget.orderCatalog,
        orderId: order.id,
        inventoryCatalog: widget.inventoryCatalog,
        grids: streetScrapGridSpecsForState(widget.session.snapshot.state),
        itemInstanceIds: order.returnContainer || order.consumeContainer
            ? const []
            : selectedItems.toList(),
        containerInstanceId: selectedContainer,
        containerInstanceIds:
            order.returnContainer && selectedContainerIds.length > 1
            ? selectedContainerIds
            : const [],
      );
      widget.onSound?.call(StreetScrapAudioCue.success);
      if (!mounted) return;
      final resultData = Map<String, Object?>.from(result.result! as Map);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            strings.text(
              'orders.successDelivery',
              arguments: {'count': '${resultData['rewardQuantity']}'},
            ),
          ),
        ),
      );
      setState(() {
        _itemSelection.remove(order.id);
        _containerSelection.remove(order.id);
        _containerMultiSelection.remove(order.id);
      });
      widget.onChanged();
    } on Object catch (error) {
      if (mounted) {
        setState(
          () => _error = _friendlyError(error, 'orders.operation.delivery'),
        );
      }
    } finally {
      if (mounted) setState(() => _busyOrders.remove(order.id));
    }
  }

  Future<void> _accept(StreetScrapOrder order) async {
    setState(() {
      _busyOrders.add(order.id);
      _error = null;
    });
    try {
      await acceptStreetScrapOrder(
        session: widget.session,
        commandId:
            'accept-${order.id}-${DateTime.now().microsecondsSinceEpoch}',
        expectedRevision: widget.session.snapshot.revision,
        orderCatalog: widget.orderCatalog,
        orderId: order.id,
      );
      widget.onSound?.call(StreetScrapAudioCue.tap);
      if (mounted) widget.onChanged();
    } on Object catch (error) {
      if (mounted) {
        setState(
          () => _error = _friendlyError(error, 'orders.operation.acceptance'),
        );
      }
    } finally {
      if (mounted) setState(() => _busyOrders.remove(order.id));
    }
  }

  Future<void> _replaceCycleOrder(StreetScrapOrder order) async {
    setState(() {
      _busyOrders.add(order.id);
      _error = null;
    });
    try {
      await replaceStreetScrapCycleOrder(
        session: widget.session,
        commandId:
            'replace-cycle-${order.id}-${DateTime.now().microsecondsSinceEpoch}',
        expectedRevision: widget.session.snapshot.revision,
        orderCatalog: widget.orderCatalog,
        orderId: order.id,
      );
      widget.onSound?.call(StreetScrapAudioCue.tap);
      if (!mounted) return;
      setState(() {
        _itemSelection.remove(order.id);
        _containerSelection.remove(order.id);
        _containerMultiSelection.remove(order.id);
        _groupSelection.remove(order.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            StreetScrapLocalizations.of(
              context,
            ).text('orders.successReplacement'),
          ),
        ),
      );
      widget.onChanged();
    } on Object catch (error) {
      if (mounted) {
        setState(
          () => _error = _friendlyError(error, 'orders.operation.replacement'),
        );
      }
    } finally {
      if (mounted) setState(() => _busyOrders.remove(order.id));
    }
  }

  List<StreetScrapObject> _eligibleOrderItems(
    StreetScrapOrder order,
    int acceptedAtRevision,
  ) {
    final items = _backpackItems().where(
      (item) =>
          order.acceptedItems.contains(item.itemId) &&
          !order.rejectedItems.contains(item.itemId),
    );
    if (order.requiredSource == null) return items.toList(growable: false);
    return items
        .where(
          (item) =>
              item.source == order.requiredSource &&
              item.acquiredRevision != null &&
              item.acquiredRevision! > acceptedAtRevision,
        )
        .toList(growable: false);
  }

  Widget _orderCard(StreetScrapOrder order, int chapter, Map tasks) {
    final strings = StreetScrapLocalizations.of(context);
    final completedByTutorial =
        order.oncePerTutorial != null && tasks[order.oncePerTutorial] == true;
    final rawCompletedGroups =
        widget.session.snapshot.state['completedOrderGroups'];
    final rawCompletedOrderIds =
        rawCompletedGroups is Map && order.completionGroupId != null
        ? rawCompletedGroups[order.completionGroupId]
        : null;
    final completedByGroup =
        rawCompletedOrderIds is List && rawCompletedOrderIds.contains(order.id);
    final completed = completedByTutorial || completedByGroup;
    final group = _group(order);
    final requiredCounts = _requiredCounts(order);
    final selectedItems = _itemSelection[order.id] ?? <String>{};
    final rawContexts = widget.session.snapshot.state['acceptedOrderContexts'];
    final acceptedContexts = rawContexts is Map
        ? rawContexts
        : const <Object?, Object?>{};
    final rawAcceptance = acceptedContexts[order.id];
    final acceptedAtRevision =
        rawAcceptance is Map && rawAcceptance['acceptedAtRevision'] is int
        ? rawAcceptance['acceptedAtRevision'] as int
        : -1;
    final orderAccepted = !order.requiresAcceptance || acceptedAtRevision >= 0;
    final eligibleOrderItems = _eligibleOrderItems(order, acceptedAtRevision);
    final containers = order.returnContainer || order.consumeContainer
        ? _matchingContainers(order)
        : const <StreetScrapObject>[];
    final selectedContainerIds = _selectedContainerIds(order, containers);
    final selectedContainer = selectedContainerIds.length == 1
        ? selectedContainerIds.single
        : null;
    final canDeliver =
        !completed &&
        !widget.session.isReadOnly &&
        !_busyOrders.contains(order.id) &&
        orderAccepted &&
        (order.returnContainer || order.consumeContainer
            ? selectedContainerIds.isNotEmpty &&
                  selectedContainerIds.length ==
                      _requiredCounts(
                        order,
                      ).values.fold<int>(0, (a, b) => a + b) &&
                  selectedContainerIds.toSet().length ==
                      selectedContainerIds.length &&
                  selectedContainerIds.every(
                    (id) => containers.any((item) => item.instanceId == id),
                  ) &&
                  _sameCounts(
                    _selectedContainerCounts(order, containers),
                    requiredCounts,
                  )
            : _sameCounts(_selectedCounts(order), requiredCounts));
    return Card(
      key: ValueKey('street-scrap-order-${order.id}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _orderName(strings, order.id),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Semantics(
                  label: strings.text(
                    'orders.reward',
                    arguments: {'count': '${order.rewardQuantity}'},
                  ),
                  child: ExcludeSemantics(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.confirmation_number_outlined,
                          size: 18,
                        ),
                        const SizedBox(width: 2),
                        Text('${order.rewardQuantity}'),
                      ],
                    ),
                  ),
                ),
                if (order.countsTowardCycle)
                  IconButton(
                    key: Key('street-scrap-replace-order-${order.id}'),
                    tooltip: strings.text(
                      _busyOrders.contains(order.id)
                          ? 'orders.replacing'
                          : 'orders.replace',
                    ),
                    onPressed:
                        !widget.session.isReadOnly &&
                            !_busyOrders.contains(order.id) &&
                            canReplaceStreetScrapCycleOrder(
                              widget.session.snapshot.state,
                              widget.orderCatalog,
                            )
                        ? () => _replaceCycleOrder(order)
                        : null,
                    icon: const Icon(Icons.autorenew_rounded),
                  ),
              ],
            ),
            Text(
              strings.text(
                'orders.phaseShort',
                arguments: {'phase': '${order.phase}'},
              ),
            ),
            if (completed)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Semantics(
                  label: strings.text('orders.tutorialCompleted'),
                  child: ExcludeSemantics(
                    child: Row(
                      children: [
                        Icon(
                          Icons.task_alt_rounded,
                          color: Theme.of(context).colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text(strings.text('orders.tutorialCompleted')),
                      ],
                    ),
                  ),
                ),
              )
            else ...[
              if (order.requiresAcceptance && !orderAccepted)
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton(
                    onPressed:
                        widget.session.isReadOnly ||
                            _busyOrders.contains(order.id)
                        ? null
                        : () => _accept(order),
                    child: Text(
                      strings.text(
                        _busyOrders.contains(order.id)
                            ? 'orders.accepting'
                            : 'orders.accept',
                      ),
                    ),
                  ),
                ),
              if (order.requiresAcceptance && orderAccepted)
                Text(strings.text('orders.accepted')),
              if (order.requiredSource != null)
                Text(
                  strings.text(
                    'orders.requiredSource',
                    arguments: {
                      'source': _orderSource(strings, order.requiredSource!),
                    },
                  ),
                ),
              if (order.requiredRecipes.isNotEmpty)
                Text(
                  strings.text(
                    'orders.requiredRecipes',
                    arguments: {
                      'recipes': order.requiredRecipes
                          .map((id) => _recipeName(strings, id))
                          .join(', '),
                    },
                  ),
                ),
              if (order.requirementGroups.length > 1)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 1040
                        ? 4
                        : constraints.maxWidth >= 760
                        ? 3
                        : 2;
                    // A compact image board: two rows on phones, three on
                    // tablets, and two on wide desktop layouts. Each page stays
                    // fully visible without a nested vertical scroll view.
                    final rows = columns == 3 ? 3 : 2;
                    final pageSize = columns * rows;
                    final pageCount =
                        (order.requirementGroups.length / pageSize).ceil();
                    final page = (_requirementPage[order.id] ?? 0).clamp(
                      0,
                      pageCount - 1,
                    );
                    final selectedIndex = (_groupSelection[order.id] ?? 0)
                        .clamp(0, order.requirementGroups.length - 1);
                    return Column(
                      children: [
                        GridView.builder(
                          key: Key('street-scrap-order-options-${order.id}'),
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount:
                              (order.requirementGroups.length - page * pageSize)
                                  .clamp(0, pageSize),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                mainAxisExtent:
                                    164 +
                                    (MediaQuery.textScalerOf(context).scale(1) -
                                                1)
                                            .clamp(0.0, 3.0) *
                                        28,
                              ),
                          itemBuilder: (context, index) {
                            final optionIndex = page * pageSize + index;
                            return _OrderRequirementCard(
                              key: Key(
                                'street-scrap-order-option-${order.id}-$optionIndex',
                              ),
                              requirements:
                                  order.requirementGroups[optionIndex],
                              availableCounts: {
                                for (final requirement
                                    in order.requirementGroups[optionIndex])
                                  requirement.itemId: eligibleOrderItems
                                      .where(
                                        (item) =>
                                            item.itemId == requirement.itemId,
                                      )
                                      .length,
                              },
                              strings: strings,
                              selected: selectedIndex == optionIndex,
                              enabled:
                                  !completed && !_busyOrders.contains(order.id),
                              woodBoardSpriteBytes: widget.woodBoardSpriteBytes,
                              threadSpoolSpriteBytes:
                                  widget.threadSpoolSpriteBytes,
                              materialAtlasBytes: widget.materialAtlasBytes,
                              toolAtlasBytes: widget.toolAtlasBytes,
                              materialPackArtBytes: widget.materialPackArtBytes,
                              mineralPackArtBytes: widget.mineralPackArtBytes,
                              woodChipBundleArtBytes:
                                  widget.woodChipBundleArtBytes,
                              onTap: () {
                                if (completed ||
                                    _busyOrders.contains(order.id)) {
                                  return;
                                }
                                setState(() {
                                  _groupSelection[order.id] = optionIndex;
                                  _requirementPage[order.id] = page;
                                  _itemSelection.remove(order.id);
                                  _containerSelection.remove(order.id);
                                  _containerMultiSelection.remove(order.id);
                                });
                              },
                            );
                          },
                        ),
                        if (pageCount > 1)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                tooltip: strings.text('board.previousPage'),
                                onPressed: page == 0
                                    ? null
                                    : () => setState(
                                        () => _requirementPage[order.id] =
                                            page - 1,
                                      ),
                                icon: const Icon(Icons.chevron_left_rounded),
                              ),
                              Text(
                                strings.text(
                                  'board.pageCount',
                                  arguments: {
                                    'current': '${page + 1}',
                                    'total': '$pageCount',
                                  },
                                ),
                              ),
                              IconButton(
                                tooltip: strings.text('board.nextPage'),
                                onPressed: page + 1 >= pageCount
                                    ? null
                                    : () => setState(
                                        () => _requirementPage[order.id] =
                                            page + 1,
                                      ),
                                icon: const Icon(Icons.chevron_right_rounded),
                              ),
                            ],
                          ),
                      ],
                    );
                  },
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final tileWidth = (constraints.maxWidth / group.length)
                        .clamp(78.0, 120.0)
                        .toDouble();
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final requirement in group)
                            SizedBox(
                              key: ValueKey(
                                'street-scrap-order-material-${order.id}-${requirement.itemId}',
                              ),
                              width: tileWidth,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      StreetScrapItemSprite(
                                        itemId: requirement.itemId,
                                        source: 'order:requirement',
                                        size: 68,
                                        visualScale: 1.22,
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
                                      ),
                                      Positioned(
                                        right: -3,
                                        bottom: -2,
                                        child: _OrderQuantityBadge(
                                          quantity: requirement.quantity,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    strings.itemName(requirement.itemId),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelSmall,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              if (order.returnContainer || order.consumeContainer)
                if (containers.isEmpty)
                  Text(
                    strings.text(
                      order.acceptedItems.contains('meal.shared')
                          ? 'orders.noPreparedMeal'
                          : 'orders.noMealContainers',
                    ),
                  )
                else if (_requiredCounts(
                      order,
                    ).values.fold<int>(0, (a, b) => a + b) <=
                    1)
                  RadioGroup<String>(
                    groupValue:
                        selectedContainer ?? containers.first.instanceId,
                    onChanged: (value) {
                      if (value == null ||
                          completed ||
                          _busyOrders.contains(order.id)) {
                        return;
                      }
                      setState(() => _containerSelection[order.id] = value);
                    },
                    child: Column(
                      children: containers
                          .asMap()
                          .entries
                          .map((entry) {
                            final item = entry.value;
                            final contentItemId =
                                item.containerState['contentItemId']! as String;
                            final contentQuality =
                                item.containerState['contentQuality'] as int? ??
                                item.quality;
                            return RadioListTile<String>(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                strings.text(
                                  'orders.containerOption',
                                  arguments: {
                                    'name': strings.itemName(item.itemId),
                                    'contents': strings.itemName(contentItemId),
                                    'quality': strings.itemQuality(
                                      contentQuality,
                                    ),
                                    'number': '${entry.key + 1}',
                                  },
                                ),
                              ),
                              value: item.instanceId,
                              enabled:
                                  !completed && !_busyOrders.contains(order.id),
                            );
                          })
                          .toList(growable: false),
                    ),
                  )
                else ...[
                  for (final entry in containers.asMap().entries)
                    _buildContainerCheckbox(
                      order: order,
                      container: entry.value,
                      index: entry.key,
                      selectedIds: selectedContainerIds.toSet(),
                      requiredCount: _requiredCounts(
                        order,
                      ).values.fold<int>(0, (a, b) => a + b),
                      enabled: !completed && !_busyOrders.contains(order.id),
                      strings: strings,
                    ),
                  Text(
                    strings.text(
                      'orders.selectedCount',
                      arguments: {
                        'selected': '${selectedContainerIds.length}',
                        'required':
                            '${_requiredCounts(order).values.fold<int>(0, (a, b) => a + b)}',
                      },
                    ),
                  ),
                ]
              else ...[
                for (final entry in requiredCounts.entries)
                  ..._eligibleOrderItems(order, acceptedAtRevision)
                      .where((item) => item.itemId == entry.key)
                      .toList(growable: false)
                      .asMap()
                      .entries
                      .map((indexedItem) {
                        final index = indexedItem.key;
                        final item = indexedItem.value;
                        final accessibleItemLabel = strings.text(
                          'orders.itemOption',
                          arguments: {
                            'name': strings.itemName(item.itemId),
                            'quality': strings.itemQuality(item.quality),
                            'number': '${index + 1}',
                          },
                        );
                        return CheckboxListTile(
                          key: ValueKey(
                            'street-scrap-order-item-choice-${order.id}-${item.instanceId}',
                          ),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Semantics(
                            label: accessibleItemLabel,
                            excludeSemantics: true,
                            child: Text(
                              strings.itemName(item.itemId),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          subtitle: Text(
                            strings.itemQuality(item.quality),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          secondary: SizedBox(
                            width: 52,
                            height: 52,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Center(
                                  child: ExcludeSemantics(
                                    child: StreetScrapItemSprite(
                                      itemId: item.itemId,
                                      source: item.source,
                                      size: 48,
                                      visualScale: 1.12,
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
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: CircleAvatar(
                                    radius: 10,
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer,
                                    child: Text(
                                      '${index + 1}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelSmall,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          value: selectedItems.contains(item.instanceId),
                          onChanged:
                              completed ||
                                  !orderAccepted ||
                                  _busyOrders.contains(order.id)
                              ? null
                              : (selected) => setState(() {
                                  final next = Set<String>.of(
                                    _itemSelection[order.id] ??
                                        const <String>{},
                                  );
                                  if (selected == true) {
                                    final count = next
                                        .where(
                                          (id) =>
                                              _inventory.objects[id]?.itemId ==
                                              entry.key,
                                        )
                                        .length;
                                    if (count < entry.value) {
                                      next.add(item.instanceId);
                                    }
                                  } else {
                                    next.remove(item.instanceId);
                                  }
                                  _itemSelection[order.id] = next;
                                }),
                        );
                      }),
                Text(
                  strings.text(
                    'orders.selectedCount',
                    arguments: {
                      'selected': '${selectedItems.length}',
                      'required':
                          '${requiredCounts.values.fold<int>(0, (a, b) => a + b)}',
                    },
                  ),
                ),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonal(
                  onPressed: canDeliver ? () => _deliver(order) : null,
                  child: Text(
                    strings.text(
                      _busyOrders.contains(order.id)
                          ? 'orders.delivering'
                          : 'orders.deliver',
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = StreetScrapLocalizations.of(context);
    final chapter = widget.session.snapshot.state['chapter'] as int? ?? 0;
    final tasks = widget.session.snapshot.state['tutorialTasks'];
    if (tasks != null && tasks is! Map) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(strings.text('orders.error.tutorialStateMalformed')),
        ),
      );
    }
    final taskMap = tasks is Map ? tasks : const <Object?, Object?>{};
    try {
      validateStreetScrapOrderCompletionState(widget.session.snapshot.state);
    } on FormatException {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            strings.text('orders.error.orderCompletionStateMalformed'),
          ),
        ),
      );
    }
    final q501Orders =
        widget.orderCatalog.completionGroups['q5.01'] ?? const <String>{};
    final rawCompletedGroups =
        widget.session.snapshot.state['completedOrderGroups'];
    final rawQ501Completed = rawCompletedGroups is Map
        ? rawCompletedGroups['q5.01']
        : null;
    final q501Completed = rawQ501Completed is List
        ? rawQ501Completed
              .whereType<String>()
              .toSet()
              .intersection(q501Orders)
              .length
        : 0;
    late final Set<String> activeCycleIds;
    try {
      activeCycleIds = activeStreetScrapCycleOrderIds(
        widget.session.snapshot.state,
        widget.orderCatalog,
      ).toSet();
    } on Object {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(strings.text('orders.error.cycleStateMalformed')),
        ),
      );
    }
    final chapterOrders = widget.orderCatalog.orders.values
        .where((order) => order.phase <= chapter && !order.countsTowardCycle)
        .toList(growable: false);
    final cycleOrders = widget.orderCatalog.orders.values
        .where(
          (order) =>
              order.phase <= chapter &&
              order.countsTowardCycle &&
              activeCycleIds.contains(order.id),
        )
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.text('orders.title'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (chapter == 4 && taskMap['q4.03'] == true) ...[
          const SizedBox(height: 8),
          if (widget.chapter5Installed)
            FilledButton.icon(
              key: const Key('street-scrap-enter-chapter-5'),
              onPressed: widget.session.isReadOnly ? null : _enterChapterFive,
              icon: const Icon(Icons.explore_outlined),
              label: Text(strings.text('orders.enterChapterFive')),
            )
          else
            OutlinedButton.icon(
              key: const Key('street-scrap-get-chapter-5'),
              onPressed: widget.onOpenLibrary,
              icon: const Icon(Icons.download_outlined),
              label: Text(strings.text('orders.installChapterFive')),
            ),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            Chip(
              avatar: const Icon(Icons.autorenew_rounded, size: 18),
              label: Text(strings.text('orders.cycleSlots')),
              visualDensity: VisualDensity.compact,
            ),
            Chip(
              avatar: const Icon(Icons.task_alt_rounded, size: 18),
              label: Text(
                strings.text(
                  'orders.cycleProgress',
                  arguments: {
                    'count':
                        '${widget.session.snapshot.state['completedCycleOrders'] ?? 0}',
                  },
                ),
              ),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        if (chapter >= 5 && q501Orders.isNotEmpty)
          Text(
            strings.text(
              'orders.neighborhoodProgress',
              arguments: {
                'done': '$q501Completed',
                'total': '${q501Orders.length}',
              },
            ),
          ),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (chapterOrders.isEmpty && cycleOrders.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(strings.text('orders.none')),
            ),
          )
        else ...[
          if (chapterOrders.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              strings.text('orders.chapterSection'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            ...chapterOrders.map(
              (order) => _orderCard(order, chapter, taskMap),
            ),
          ],
          if (cycleOrders.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              strings.text('orders.cycleSection'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            ...cycleOrders.map((order) => _orderCard(order, chapter, taskMap)),
          ],
        ],
      ],
    );
  }
}
