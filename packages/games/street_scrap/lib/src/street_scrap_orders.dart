import 'dart:collection';
import 'dart:convert';

import 'street_scrap_inventory.dart';
import 'street_scrap_module.dart';
import 'street_scrap_progress.dart';
import 'street_scrap_chapter5.dart';

bool _sameCounts(Map<String, int> left, Map<String, int> right) =>
    left.length == right.length &&
    left.entries.every((entry) => right[entry.key] == entry.value);

class StreetScrapOrderRequirement {
  const StreetScrapOrderRequirement({
    required this.itemId,
    required this.quantity,
  });

  final String itemId;
  final int quantity;
}

/// Content-backed order contract. `acceptedItems` is the compact form for
/// single-material alternatives; requirement groups express multi-item
/// alternatives such as one whole fish or two portions of fish meat.
class StreetScrapOrder {
  StreetScrapOrder({
    required this.id,
    required this.phase,
    required List<String> acceptedItems,
    required List<String> rejectedItems,
    required List<List<StreetScrapOrderRequirement>> requirementGroups,
    required this.quantity,
    required this.rewardCurrency,
    required this.rewardQuantity,
    required this.countsTowardCycle,
    required this.returnContainer,
    required this.consumeContainer,
    this.containerItemId,
    this.returnedContainerCleanliness,
    this.requiresTutorial,
    this.oncePerTutorial,
    this.completionGroupId,
    this.requiresAcceptance = false,
    this.requiredSource,
    List<String> requiredRecipes = const [],
  }) : acceptedItems = List.unmodifiable(acceptedItems),
       rejectedItems = List.unmodifiable(rejectedItems),
       requirementGroups = List.unmodifiable(
         requirementGroups.map(List<StreetScrapOrderRequirement>.unmodifiable),
       ),
       requiredRecipes = List.unmodifiable(requiredRecipes);

  final String id;
  final int phase;
  final List<String> acceptedItems;
  final List<String> rejectedItems;
  final List<List<StreetScrapOrderRequirement>> requirementGroups;
  final int quantity;
  final String rewardCurrency;
  final int rewardQuantity;
  final bool countsTowardCycle;
  final bool returnContainer;
  final bool consumeContainer;
  final String? containerItemId;
  final String? returnedContainerCleanliness;
  final String? requiresTutorial;
  final String? oncePerTutorial;
  final String? completionGroupId;
  final bool requiresAcceptance;
  final String? requiredSource;
  final List<String> requiredRecipes;

  factory StreetScrapOrder.fromJson(
    Map value, {
    required Set<String> itemIds,
    Set<String> recipeIds = const {},
  }) {
    final id = value['id'];
    final phase = value['phase'];
    final accepted = value['acceptedItems'];
    final rejected = value['rejectedItems'] ?? const [];
    final rawGroups = value['requirementGroups'];
    final reward = value['reward'];
    final quantity = value['quantity'] ?? 1;
    final countsTowardCycle = value['countsTowardCycle'];
    final returnContainer = value['returnContainer'] ?? false;
    final consumeContainer = value['consumeContainer'] ?? false;
    final containerItemId = value['containerItemId'];
    final cleanliness = value['returnedContainerCleanliness'];
    final requires = value['requiresTutorial'];
    final once = value['oncePerTutorial'];
    final completionGroupId = value['completionGroupId'];
    final requiresAcceptance = value['requiresAcceptance'] ?? false;
    final requiredSource = value['requiredSource'];
    final requiredRecipes = value['requiredRecipes'] ?? const [];
    if (id is! String ||
        id.trim().isEmpty ||
        phase is! int ||
        phase < 0 ||
        phase > 5 ||
        accepted is! List ||
        accepted.any((item) => item is! String || !itemIds.contains(item)) ||
        rejected is! List ||
        rejected.any((item) => item is! String || !itemIds.contains(item)) ||
        accepted.toSet().length != accepted.length ||
        rejected.toSet().length != rejected.length ||
        accepted.toSet().intersection(rejected.toSet()).isNotEmpty ||
        quantity is! int ||
        quantity < 1 ||
        reward is! Map ||
        reward['currency'] != 'exchangeTickets' ||
        reward['quantity'] is! int ||
        reward['quantity'] < 1 ||
        countsTowardCycle is! bool ||
        returnContainer is! bool ||
        consumeContainer is! bool ||
        (containerItemId != null &&
            (containerItemId is! String ||
                !itemIds.contains(containerItemId))) ||
        (returnContainer && consumeContainer) ||
        (consumeContainer && containerItemId == null) ||
        (containerItemId != null && !returnContainer && !consumeContainer) ||
        (consumeContainer && quantity != 1) ||
        (returnContainer && cleanliness != 'soiled') ||
        (!returnContainer && cleanliness != null) ||
        (requires != null &&
            (requires is! String || requires.trim().isEmpty)) ||
        (once != null && (once is! String || once.trim().isEmpty)) ||
        (completionGroupId != null &&
            (completionGroupId is! String ||
                completionGroupId.trim().isEmpty)) ||
        requiresAcceptance is! bool ||
        (requiredSource != null &&
            (requiredSource is! String || requiredSource.trim().isEmpty)) ||
        requiredRecipes is! List ||
        requiredRecipes.any(
          (recipe) => recipe is! String || !recipeIds.contains(recipe),
        ) ||
        requiredRecipes.toSet().length != requiredRecipes.length ||
        ((requiredSource != null || requiredRecipes.isNotEmpty) &&
            !requiresAcceptance) ||
        (rawGroups != null &&
            (rawGroups is! List ||
                rawGroups.isEmpty ||
                rawGroups.any(
                  (group) =>
                      group is! List ||
                      group.isEmpty ||
                      group.any(
                        (entry) =>
                            entry is! Map ||
                            entry['item'] is! String ||
                            !itemIds.contains(entry['item']) ||
                            !accepted.contains(entry['item']) ||
                            entry['quantity'] is! int ||
                            entry['quantity'] < 1,
                      ),
                ))) ||
        (returnContainer &&
            rawGroups is List &&
            rawGroups.any(
              (group) =>
                  group is! List ||
                  group.fold<int>(
                        0,
                        (sum, entry) =>
                            sum + ((entry as Map)['quantity'] as int),
                      ) !=
                      quantity,
            )) ||
        (accepted.isEmpty && rawGroups == null)) {
      throw const FormatException('Malformed Street Scrap order.');
    }
    final requirementGroups = rawGroups == null
        ? [
            for (final item in accepted)
              [
                StreetScrapOrderRequirement(
                  itemId: item as String,
                  quantity: quantity,
                ),
              ],
          ]
        : [
            for (final group in rawGroups as List)
              [
                for (final entry in group as List)
                  StreetScrapOrderRequirement(
                    itemId: (entry as Map)['item'] as String,
                    quantity: entry['quantity'] as int,
                  ),
              ],
          ];
    return StreetScrapOrder(
      id: id,
      phase: phase,
      acceptedItems: accepted.cast<String>(),
      rejectedItems: rejected.cast<String>(),
      requirementGroups: requirementGroups,
      quantity: quantity,
      rewardCurrency: 'exchangeTickets',
      rewardQuantity: reward['quantity'] as int,
      countsTowardCycle: countsTowardCycle,
      returnContainer: returnContainer,
      consumeContainer: consumeContainer,
      containerItemId: containerItemId as String?,
      returnedContainerCleanliness: cleanliness as String?,
      requiresTutorial: requires as String?,
      oncePerTutorial: once as String?,
      completionGroupId: completionGroupId as String?,
      requiresAcceptance: requiresAcceptance,
      requiredSource: requiredSource as String?,
      requiredRecipes: requiredRecipes.cast<String>(),
    );
  }
}

class StreetScrapOrderCatalog {
  StreetScrapOrderCatalog._(Map<String, StreetScrapOrder> orders)
    : orders = UnmodifiableMapView(orders);

  factory StreetScrapOrderCatalog.fromOrders(
    Iterable<StreetScrapOrder> source,
  ) {
    final orders = <String, StreetScrapOrder>{};
    for (final order in source) {
      if (orders.containsKey(order.id)) {
        throw FormatException('Duplicate Street Scrap order ${order.id}.');
      }
      orders[order.id] = order;
    }
    if (orders.isEmpty) throw const FormatException('Order catalog is empty.');
    return StreetScrapOrderCatalog._(orders);
  }

  factory StreetScrapOrderCatalog.fromContentPayload(String source) {
    validateStreetScrapContentPayload(source);
    final payload = jsonDecode(source) as Map<String, dynamic>;
    final itemIds = (payload['itemDefinitions'] as List)
        .map((item) => (item as Map)['id'] as String)
        .toSet();
    final rawOrders = payload['orders'];
    if (rawOrders is! List || rawOrders.isEmpty) {
      throw const FormatException('Street Scrap order list is missing.');
    }
    return StreetScrapOrderCatalog.fromOrders(
      rawOrders.map((raw) {
        if (raw is! Map) throw const FormatException('Malformed order.');
        return StreetScrapOrder.fromJson(
          raw,
          itemIds: itemIds,
          recipeIds: (payload['recipes'] as List)
              .map((recipe) => (recipe as Map)['id'] as String)
              .toSet(),
        );
      }),
    );
  }

  final Map<String, StreetScrapOrder> orders;

  Map<String, Set<String>> get completionGroups {
    final groups = <String, Set<String>>{};
    for (final order in orders.values) {
      final groupId = order.completionGroupId;
      if (groupId != null) {
        groups.putIfAbsent(groupId, () => <String>{}).add(order.id);
      }
    }
    return groups;
  }

  StreetScrapOrder? operator [](String id) => orders[id];
}

/// Validates the durable completion history before importing a save or
/// rendering actionable order controls. Unknown order IDs remain valid so
/// history survives compatible content revisions.
void validateStreetScrapOrderCompletionState(Map<String, Object?> state) {
  final rawGroups = state['completedOrderGroups'];
  if (rawGroups == null) return;
  if (rawGroups is! Map) {
    throw const FormatException('Malformed completed order groups.');
  }
  for (final entry in rawGroups.entries) {
    final groupId = entry.key;
    final rawOrderIds = entry.value;
    if (groupId is! String || groupId.isEmpty || rawOrderIds is! List) {
      throw const FormatException('Malformed completed order groups.');
    }
    final seenOrderIds = <String>{};
    for (final rawOrderId in rawOrderIds) {
      if (rawOrderId is! String ||
          rawOrderId.isEmpty ||
          !seenOrderIds.add(rawOrderId)) {
        throw const FormatException('Malformed completed order groups.');
      }
    }
  }
}

/// Returns the two deterministic cycle-order slots for the current chapter.
/// Older saves without this field are upgraded in memory from catalog order;
/// the selected IDs become durable on the next replace or delivery command.
List<String> activeStreetScrapCycleOrderIds(
  Map<String, Object?> state,
  StreetScrapOrderCatalog orderCatalog,
) {
  final chapter = state['chapter'] ?? 0;
  if (chapter is! int || chapter < 0 || chapter > 5) {
    throw StateError('orderChapterMalformed');
  }
  final eligible = orderCatalog.orders.values
      .where((order) => order.countsTowardCycle && order.phase <= chapter)
      .map((order) => order.id)
      .toList(growable: false);
  final raw = state['activeCycleOrderIds'];
  if (raw != null &&
      (raw is! List || raw.any((id) => id is! String) || raw.length > 2)) {
    throw StateError('cycleOrderSlotsMalformed');
  }
  final slots = <String>[];
  if (raw is List) {
    for (final id in raw.cast<String>()) {
      if (eligible.contains(id) && !slots.contains(id)) slots.add(id);
    }
  }
  for (final id in eligible) {
    if (slots.length == 2) break;
    if (!slots.contains(id)) slots.add(id);
  }
  return List.unmodifiable(slots);
}

bool canReplaceStreetScrapCycleOrder(
  Map<String, Object?> state,
  StreetScrapOrderCatalog orderCatalog,
) {
  try {
    final chapter = state['chapter'] ?? 0;
    if (chapter is! int || chapter < 0 || chapter > 5) return false;
    final eligibleCount = orderCatalog.orders.values
        .where((order) => order.countsTowardCycle && order.phase <= chapter)
        .length;
    return eligibleCount >
        activeStreetScrapCycleOrderIds(state, orderCatalog).length;
  } on Object {
    return false;
  }
}

({List<String> orderIds, int cursor}) _cycleOrderReplacement({
  required Map<String, Object?> state,
  required StreetScrapOrderCatalog orderCatalog,
  required String orderId,
}) {
  final slots = activeStreetScrapCycleOrderIds(state, orderCatalog).toList();
  final slotIndex = slots.indexOf(orderId);
  if (slotIndex < 0) throw StateError('cycleOrderNotActive');
  final chapter = state['chapter'] as int? ?? 0;
  final eligible = orderCatalog.orders.values
      .where((order) => order.countsTowardCycle && order.phase <= chapter)
      .map((order) => order.id)
      .toList(growable: false);
  if (eligible.length <= slots.length) {
    throw StateError('cycleOrderNoReplacement');
  }
  final rawCursor = state['cycleOrderRotationCursor'] ?? 0;
  if (rawCursor is! int || rawCursor < 0) {
    throw StateError('cycleOrderCursorMalformed');
  }
  for (var offset = 0; offset < eligible.length; offset++) {
    final index = (rawCursor + offset) % eligible.length;
    final candidate = eligible[index];
    if (slots.contains(candidate)) continue;
    slots[slotIndex] = candidate;
    return (
      orderIds: List.unmodifiable(slots),
      cursor: (index + 1) % eligible.length,
    );
  }
  throw StateError('cycleOrderNoReplacement');
}

Future<StreetScrapCommandResult> replaceStreetScrapCycleOrder({
  required StreetScrapSession session,
  required String commandId,
  required int expectedRevision,
  required StreetScrapOrderCatalog orderCatalog,
  required String orderId,
}) => session.apply(
  commandId: commandId,
  expectedRevision: expectedRevision,
  reduce: (state) {
    final order = orderCatalog[orderId];
    if (order == null || !order.countsTowardCycle) {
      throw StateError('cycleOrderUnavailable');
    }
    final replacement = _cycleOrderReplacement(
      state: state,
      orderCatalog: orderCatalog,
      orderId: orderId,
    );
    final contexts = state['acceptedOrderContexts'];
    if (contexts is Map && contexts.containsKey(orderId)) {
      throw StateError('acceptedCycleOrderCannotBeReplaced');
    }
    return StreetScrapReduction(
      state: {
        ...state,
        'activeCycleOrderIds': replacement.orderIds,
        'cycleOrderRotationCursor': replacement.cursor,
      },
      result: {
        'replacedOrderId': orderId,
        'activeCycleOrderIds': replacement.orderIds,
      },
    );
  },
);

/// Executes an order from selected backpack items. A return-container order
/// accepts one eligible item stored in the same reusable vessel. It either
/// returns that vessel in place or consumes a declared package vessel.
Future<StreetScrapCommandResult> acceptStreetScrapOrder({
  required StreetScrapSession session,
  required String commandId,
  required int expectedRevision,
  required StreetScrapOrderCatalog orderCatalog,
  required String orderId,
}) => session.apply(
  commandId: commandId,
  expectedRevision: expectedRevision,
  reduce: (state) {
    final order = orderCatalog[orderId];
    if (order == null || !order.requiresAcceptance) {
      throw StateError('orderAcceptanceUnavailable');
    }
    final chapter = state['chapter'] ?? 0;
    if (chapter is! int || chapter < order.phase) {
      throw StateError('orderLocked');
    }
    if (order.countsTowardCycle &&
        !activeStreetScrapCycleOrderIds(
          state,
          orderCatalog,
        ).contains(order.id)) {
      throw StateError('cycleOrderNotActive');
    }
    final rawContexts =
        state['acceptedOrderContexts'] ?? const <String, Object?>{};
    if (rawContexts is! Map) throw StateError('orderAcceptanceStateMalformed');
    final contexts = Map<String, Object?>.from(rawContexts);
    if (contexts.containsKey(orderId)) throw StateError('orderAlreadyAccepted');
    final rawCounts =
        state['recipeCompletionCounts'] ?? const <String, Object?>{};
    if (rawCounts is! Map ||
        rawCounts.values.any((count) => count is! int || count < 0)) {
      throw StateError('recipeCompletionStateMalformed');
    }
    contexts[orderId] = {
      'acceptedAtRevision': expectedRevision + 1,
      'recipeCompletionBaseline': Map<String, Object?>.from(rawCounts),
    };
    return StreetScrapReduction(
      state: {...state, 'acceptedOrderContexts': contexts},
      result: {'orderId': orderId, 'accepted': true},
    );
  },
);

Future<StreetScrapCommandResult> deliverStreetScrapOrder({
  required StreetScrapSession session,
  required String commandId,
  required int expectedRevision,
  required StreetScrapOrderCatalog orderCatalog,
  required String orderId,
  required StreetScrapInventoryCatalog inventoryCatalog,
  required Map<String, StreetScrapGridSpec> grids,
  List<String> itemInstanceIds = const [],
  String? containerInstanceId,
  List<String> containerInstanceIds = const [],
}) => session.apply(
  commandId: commandId,
  expectedRevision: expectedRevision,
  reduce: (state) {
    final order = orderCatalog[orderId];
    if (order == null) throw StateError('orderUnavailable');
    final chapter = state['chapter'] ?? 0;
    if (chapter is! int || chapter < order.phase) {
      throw StateError('orderLocked');
    }
    if (order.countsTowardCycle &&
        !activeStreetScrapCycleOrderIds(
          state,
          orderCatalog,
        ).contains(order.id)) {
      throw StateError('cycleOrderNotActive');
    }
    final tasksValue = state['tutorialTasks'] ?? const <String, Object?>{};
    if (tasksValue is! Map) throw StateError('tutorialStateMalformed');
    final tasks = Map<String, Object?>.from(tasksValue);
    final rawContexts =
        state['acceptedOrderContexts'] ?? const <String, Object?>{};
    if (rawContexts is! Map) throw StateError('orderAcceptanceStateMalformed');
    final contexts = Map<String, Object?>.from(rawContexts);
    Map<String, Object?>? acceptance;
    if (order.requiresAcceptance) {
      final rawAcceptance = contexts[orderId];
      if (rawAcceptance is! Map ||
          rawAcceptance['acceptedAtRevision'] is! int ||
          rawAcceptance['recipeCompletionBaseline'] is! Map) {
        throw StateError('orderNotAccepted');
      }
      acceptance = Map<String, Object?>.from(rawAcceptance);
    }
    if (order.requiresTutorial != null &&
        tasks[order.requiresTutorial] != true) {
      throw StateError('orderTutorialLocked');
    }
    if (order.oncePerTutorial != null && tasks[order.oncePerTutorial] == true) {
      throw StateError('orderAlreadyCompleted');
    }
    final completionGroupId = order.completionGroupId;
    if (completionGroupId != null) {
      final rawGroups =
          state['completedOrderGroups'] ?? const <String, Object?>{};
      if (rawGroups is! Map) {
        throw StateError('orderCompletionStateMalformed');
      }
      final rawCompleted = rawGroups[completionGroupId] ?? const <String>[];
      if (rawCompleted is! List || rawCompleted.any((id) => id is! String)) {
        throw StateError('orderCompletionStateMalformed');
      }
      if (rawCompleted.contains(orderId)) {
        throw StateError('orderAlreadyCompleted');
      }
    }
    final rawInventory = state['inventory'];
    if (rawInventory is! Map) throw StateError('inventoryMissing');
    final inventory = inventoryCatalog.inventoryFromJson(
      grids: grids,
      json: Map<String, Object?>.from(rawInventory),
    );

    String deliveredItemId;
    final deliveredItemIds = <String>[];
    final deliveredContainerIds = <String>[];
    StreetScrapInventory nextInventory;
    if (order.returnContainer || order.consumeContainer) {
      final selectedContainerIds = containerInstanceIds.isNotEmpty
          ? containerInstanceIds
          : containerInstanceId == null
          ? const <String>[]
          : [containerInstanceId];
      if (selectedContainerIds.isEmpty ||
          itemInstanceIds.isNotEmpty ||
          selectedContainerIds.toSet().length != selectedContainerIds.length ||
          (containerInstanceId != null && containerInstanceIds.isNotEmpty)) {
        throw StateError('orderSelectionInvalid');
      }
      final selectedVessels = selectedContainerIds
          .map((instanceId) {
            final vessel = inventory.objects[instanceId];
            if (vessel == null ||
                inventory.placements[instanceId]?.gridId != 'backpack' ||
                vessel.containerContents.isNotEmpty ||
                (order.containerItemId != null &&
                    vessel.itemId != order.containerItemId)) {
              throw StateError('orderContainerMissing');
            }
            final contentItemId = vessel.containerState['contentItemId'];
            if (contentItemId is! String ||
                !order.acceptedItems.contains(contentItemId) ||
                order.rejectedItems.contains(contentItemId)) {
              throw StateError('orderItemNotAccepted');
            }
            return (
              instanceId: instanceId,
              vessel: vessel,
              contentItemId: contentItemId,
            );
          })
          .toList(growable: false);
      final selectedContentCounts = <String, int>{};
      for (final selection in selectedVessels) {
        selectedContentCounts.update(
          selection.contentItemId,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
      if (!order.requirementGroups.any((group) {
        final requiredCounts = <String, int>{};
        for (final requirement in group) {
          requiredCounts.update(
            requirement.itemId,
            (count) => count + requirement.quantity,
            ifAbsent: () => requirement.quantity,
          );
        }
        return _sameCounts(selectedContentCounts, requiredCounts);
      })) {
        throw StateError('orderItemNotAccepted');
      }
      deliveredItemId = selectedVessels.first.contentItemId;
      deliveredItemIds.addAll(
        selectedVessels.map((selection) => selection.contentItemId),
      );
      deliveredContainerIds.addAll(selectedContainerIds);
      if (order.returnContainer) {
        nextInventory = inventory;
        for (final selection in selectedVessels) {
          nextInventory = nextInventory
              .withContainerState(selection.instanceId, {
                'cleanliness': order.returnedContainerCleanliness,
                'lastContentItemId': selection.contentItemId,
                'lastContentQuality':
                    selection.vessel.containerState['contentQuality'] ??
                    selection.vessel.quality,
              });
        }
      } else {
        nextInventory = inventory.consumeFromGrid(
          selectedContainerIds,
          'backpack',
        );
      }
    } else {
      if (containerInstanceId != null ||
          itemInstanceIds.toSet().length != itemInstanceIds.length) {
        throw StateError('orderSelectionInvalid');
      }
      final selected = itemInstanceIds
          .map((instanceId) {
            final item = inventory.objects[instanceId];
            final placement = inventory.placements[instanceId];
            if (item == null ||
                placement?.gridId != 'backpack' ||
                item.containerContents.isNotEmpty) {
              throw StateError('orderItemMissing');
            }
            return item;
          })
          .toList(growable: false);
      if (order.requiredSource != null) {
        final acceptedAtRevision = acceptance!['acceptedAtRevision'] as int;
        if (selected.any(
          (item) =>
              item.source != order.requiredSource ||
              item.acquiredRevision == null ||
              item.acquiredRevision! <= acceptedAtRevision,
        )) {
          throw StateError('orderSourceEventRequired');
        }
      }
      if (order.requiredRecipes.isNotEmpty) {
        final rawCounts =
            state['recipeCompletionCounts'] ?? const <String, Object?>{};
        final baseline = acceptance!['recipeCompletionBaseline'];
        if (rawCounts is! Map || baseline is! Map) {
          throw StateError('recipeCompletionStateMalformed');
        }
        for (final recipeId in order.requiredRecipes) {
          final count = rawCounts[recipeId] ?? 0;
          final before = baseline[recipeId] ?? 0;
          if (count is! int || before is! int || count <= before) {
            throw StateError('orderRecipeEventRequired');
          }
        }
      }
      deliveredItemId = selected.first.itemId;
      deliveredItemIds.addAll(selected.map((item) => item.itemId));
      final selectedCounts = <String, int>{};
      for (final item in selected) {
        selectedCounts.update(
          item.itemId,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
      final validRequirement = order.requirementGroups.any((group) {
        final requiredCounts = <String, int>{};
        for (final requirement in group) {
          requiredCounts.update(
            requirement.itemId,
            (count) => count + requirement.quantity,
            ifAbsent: () => requirement.quantity,
          );
        }
        return _sameCounts(selectedCounts, requiredCounts);
      });
      if (!validRequirement ||
          selected.any((item) => order.rejectedItems.contains(item.itemId))) {
        throw StateError('orderItemNotAccepted');
      }
      nextInventory = inventory.consumeFromGrid(itemInstanceIds, 'backpack');
    }

    final balance = state[order.rewardCurrency] ?? 0;
    if (balance is! int || balance < 0) throw StateError('invalidOrderBalance');
    if (order.oncePerTutorial != null) tasks[order.oncePerTutorial!] = true;
    Map<String, Object?>? completedGroups;
    if (completionGroupId != null) {
      final rawGroups =
          state['completedOrderGroups'] ?? const <String, Object?>{};
      if (rawGroups is! Map) throw StateError('orderCompletionStateMalformed');
      final nextCompletedGroups = Map<String, Object?>.from(rawGroups);
      final rawCompleted =
          nextCompletedGroups[completionGroupId] ?? const <String>[];
      if (rawCompleted is! List || rawCompleted.any((id) => id is! String)) {
        throw StateError('orderCompletionStateMalformed');
      }
      final completedIds = rawCompleted.cast<String>().toSet()..add(order.id);
      final knownOrderIds = orderCatalog.completionGroups[completionGroupId];
      if (knownOrderIds == null || !knownOrderIds.contains(order.id)) {
        throw StateError('orderCompletionGroupInvalid');
      }
      nextCompletedGroups[completionGroupId] = completedIds.toList()..sort();
      completedGroups = nextCompletedGroups;
      if (completedIds.containsAll(knownOrderIds)) {
        tasks[completionGroupId] = true;
      }
    }
    final nextState = <String, Object?>{
      ...state,
      order.rewardCurrency: balance + order.rewardQuantity,
      'inventory': nextInventory.toJson(),
      'tutorialTasks': tasks,
      'completedOrderGroups': ?completedGroups,
    };
    if (acceptance != null) {
      contexts.remove(orderId);
      nextState['acceptedOrderContexts'] = contexts;
    }
    if (order.countsTowardCycle) {
      final completed = state['completedCycleOrders'] ?? 0;
      if (completed is! int || completed < 0) {
        throw StateError('invalidCompletedOrderCount');
      }
      nextState['completedCycleOrders'] = completed + 1;
    }
    updateStreetScrapChapterFiveGoal(nextState);
    return StreetScrapReduction(
      state: nextState,
      result: {
        'orderId': order.id,
        'deliveredItemId': deliveredItemId,
        'deliveredItemIds': deliveredItemIds,
        'containerInstanceIds': deliveredContainerIds,
        'rewardCurrency': order.rewardCurrency,
        'rewardQuantity': order.rewardQuantity,
        'completedCycleOrders': nextState['completedCycleOrders'] ?? 0,
        'returnedContainerInstanceId': ?containerInstanceId,
        if (containerInstanceId != null && order.consumeContainer)
          'consumedContainerInstanceId': containerInstanceId,
      },
    );
  },
);
