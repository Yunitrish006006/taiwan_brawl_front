import 'dart:convert';

import 'street_scrap_inventory.dart';
import 'street_scrap_progress.dart';

class StreetScrapRenewableSupply {
  const StreetScrapRenewableSupply({
    required this.itemId,
    required this.phase,
    required this.quantity,
    required this.staminaCost,
  });

  final String itemId;
  final int phase;
  final int quantity;
  final int staminaCost;
}

/// Repeatable, versioned material sources shipped in the content package.
class StreetScrapRenewableSupplyCatalog {
  StreetScrapRenewableSupplyCatalog(
    Iterable<StreetScrapRenewableSupply> supplies,
  ) : supplies = List.unmodifiable(supplies) {
    final ids = <String>{};
    for (final supply in this.supplies) {
      if (supply.itemId.trim().isEmpty ||
          !ids.add(supply.itemId) ||
          supply.phase < 0 ||
          supply.phase > 5 ||
          supply.quantity < 1 ||
          supply.staminaCost < 0) {
        throw const FormatException('Invalid renewable supply catalog.');
      }
    }
  }

  final List<StreetScrapRenewableSupply> supplies;

  factory StreetScrapRenewableSupplyCatalog.fromContentPayload(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map || decoded['renewableSupplies'] is! List) {
      throw const FormatException('Renewable supply content is missing.');
    }
    final rawSupplies = decoded['renewableSupplies'] as List;
    return StreetScrapRenewableSupplyCatalog([
      for (final raw in rawSupplies)
        if (raw is Map &&
            raw['item'] is String &&
            raw['phase'] is int &&
            raw['quantity'] is int &&
            raw['stamina'] is int &&
            raw['repeatable'] == true)
          StreetScrapRenewableSupply(
            itemId: raw['item'] as String,
            phase: raw['phase'] as int,
            quantity: raw['quantity'] as int,
            staminaCost: raw['stamina'] as int,
          )
        else
          throw const FormatException('Malformed renewable supply entry.'),
    ]);
  }

  StreetScrapRenewableSupply? operator [](String itemId) {
    for (final supply in supplies) {
      if (supply.itemId == itemId) return supply;
    }
    return null;
  }

  List<StreetScrapRenewableSupply> availableAt(int chapter) =>
      List.unmodifiable(supplies.where((supply) => supply.phase <= chapter));
}

/// Claims one repeatable fixed source atomically. Liquid supplies go into a
/// selected reusable vessel; grid items are placed in the backpack as distinct
/// instances so source, quality, and acquired revision remain inspectable.
Future<StreetScrapCommandResult> claimStreetScrapRenewableSupply({
  required StreetScrapSession session,
  required String commandId,
  required int expectedRevision,
  required StreetScrapRenewableSupplyCatalog supplyCatalog,
  required StreetScrapInventoryCatalog inventoryCatalog,
  required Map<String, StreetScrapGridSpec> grids,
  required String backpackGridId,
  required String itemId,
  required int maxStamina,
  String? vesselInstanceId,
}) => session.apply(
  commandId: commandId,
  expectedRevision: expectedRevision,
  reduce: (state) {
    final supply = supplyCatalog[itemId];
    if (supply == null) throw StateError('renewableSupplyUnavailable');
    final chapter = state['chapter'] ?? 0;
    if (chapter is! int || chapter < supply.phase) {
      throw StateError('renewableSupplyLocked');
    }
    final stamina = state['stamina'] as int? ?? maxStamina;
    if (maxStamina < 1 ||
        stamina < supply.staminaCost ||
        stamina > maxStamina) {
      throw StateError('insufficientStamina');
    }
    final rawInventory = state['inventory'];
    if (rawInventory is! Map) throw StateError('inventoryMissing');
    final inventory = inventoryCatalog.inventoryFromJson(
      grids: grids,
      json: Map<String, Object?>.from(rawInventory),
    );
    final revision = expectedRevision + 1;
    var next = inventory;
    if (itemId.startsWith('water.')) {
      if (vesselInstanceId == null) {
        throw StateError('renewableSupplyVesselRequired');
      }
      final vessel = inventory.objects[vesselInstanceId];
      if (vessel == null ||
          !const {
            'container.clean',
            'container.clean_jar',
            'container.used_intact',
          }.contains(vessel.itemId) ||
          !inventory.placements.containsKey(vesselInstanceId) ||
          vessel.containerState['cleanliness'] != 'clean' ||
          vessel.containerState['contentItemId'] != null) {
        throw StateError('renewableSupplyCleanVesselRequired');
      }
      next = inventory.withContainerState(vesselInstanceId, {
        'contentItemId': itemId,
        'contentQuality': 55,
        'contentSource': 'supply:renewable:$itemId',
        'contentTraits': const <String, Object?>{},
        'requiresBoiling': const {
          'water.dirty',
          'water.turbid',
        }.contains(itemId),
        'cleanliness': 'utility',
      });
    } else {
      if (!inventoryCatalog.footprints.containsKey(itemId)) {
        throw StateError('renewableSupplyItemNotPlaceable');
      }
      for (var index = 0; index < supply.quantity; index++) {
        final instanceId = 'supply-$commandId-$index';
        if (next.objects.containsKey(instanceId)) {
          throw const FormatException('Duplicate renewable supply identity.');
        }
        final containerState = switch (itemId) {
          'container.clean' ||
          'container.clean_jar' => const {'cleanliness': 'clean'},
          'container.used_intact' => const {'cleanliness': 'soiled'},
          _ => const <String, Object?>{},
        };
        try {
          next = next.addAndPlaceFirstFit(
            inventoryCatalog.createObject(
              instanceId: instanceId,
              itemId: itemId,
              source: 'supply:renewable:$itemId',
              quality: 55,
              traits: const {},
              acquiredRevision: revision,
              containerState: containerState,
            ),
            backpackGridId,
          );
        } on StateError catch (error) {
          if (error.message.toString().startsWith('No fitting space for ')) {
            throw StateError('renewableSupplyNoBackpackSpace');
          }
          rethrow;
        }
      }
    }
    return StreetScrapReduction(
      state: {
        ...state,
        'stamina': stamina - supply.staminaCost,
        'inventory': next.toJson(),
      },
      result: {
        'itemId': itemId,
        'quantity': supply.quantity,
        'staminaCost': supply.staminaCost,
        ...?vesselInstanceId == null
            ? null
            : {'vesselInstanceId': vesselInstanceId},
      },
    );
  },
);
