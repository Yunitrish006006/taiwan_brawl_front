import 'package:flutter/material.dart';

import 'street_scrap_inventory.dart';
import 'street_scrap_localizations.dart';
import 'street_scrap_item_sprite.dart';
import 'street_scrap_progress.dart';
import 'street_scrap_renewable_supplies.dart';
import 'street_scrap_water.dart';

class StreetScrapRenewableSuppliesPanel extends StatefulWidget {
  const StreetScrapRenewableSuppliesPanel({
    super.key,
    required this.session,
    required this.catalog,
    required this.inventoryCatalog,
    required this.grids,
    required this.maxStamina,
    this.onChanged,
    this.onOrganize,
  });

  final StreetScrapSession session;
  final StreetScrapRenewableSupplyCatalog catalog;
  final StreetScrapInventoryCatalog inventoryCatalog;
  final Map<String, StreetScrapGridSpec> grids;
  final int maxStamina;
  final VoidCallback? onChanged;
  final VoidCallback? onOrganize;

  @override
  State<StreetScrapRenewableSuppliesPanel> createState() =>
      _StreetScrapRenewableSuppliesPanelState();
}

class _StreetScrapRenewableSuppliesPanelState
    extends State<StreetScrapRenewableSuppliesPanel> {
  String? _busyItemId;

  List<StreetScrapObject> _washableVessels() {
    final rawInventory = widget.session.snapshot.state['inventory'];
    if (rawInventory is! Map) return const [];
    final inventory = widget.inventoryCatalog.inventoryFromJson(
      grids: widget.grids,
      json: Map<String, Object?>.from(rawInventory),
    );
    return inventory.objects.values
        .where(
          (item) =>
              const {
                'container.clean',
                'container.clean_jar',
                'container.used_intact',
              }.contains(item.itemId) &&
              inventory.placements.containsKey(item.instanceId) &&
              item.containerState['contentItemId'] == null &&
              item.containerState['cleanliness'] != 'clean',
        )
        .toList(growable: false);
  }

  List<StreetScrapObject> _refillableVessels() {
    final rawInventory = widget.session.snapshot.state['inventory'];
    if (rawInventory is! Map) return const [];
    final inventory = widget.inventoryCatalog.inventoryFromJson(
      grids: widget.grids,
      json: Map<String, Object?>.from(rawInventory),
    );
    return inventory.objects.values
        .where(
          (item) =>
              const {
                'container.clean',
                'container.clean_jar',
                'container.used_intact',
              }.contains(item.itemId) &&
              inventory.placements.containsKey(item.instanceId) &&
              item.containerState['contentItemId'] == null &&
              item.containerState['cleanliness'] == 'clean',
        )
        .toList(growable: false);
  }

  Future<void> _fillFilteredAtPublicRefill(StreetScrapObject vessel) async {
    if (_busyItemId != null) return;
    final strings = StreetScrapLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.text('supplies.fillTitle')),
        content: Text(
          strings.text('supplies.fillBody', arguments: {'stamina': '2'}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.text('craft.dialog.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.text('supplies.fillAction')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busyItemId = vessel.instanceId);
    try {
      await fillStreetScrapVessel(
        session: widget.session,
        commandId:
            'public-refill-fill-${vessel.instanceId}-${widget.session.snapshot.revision}',
        expectedRevision: widget.session.snapshot.revision,
        catalog: widget.inventoryCatalog,
        grids: widget.grids,
        vesselId: vessel.instanceId,
        sourceId: 'public-refill',
        maxStamina: widget.maxStamina,
      );
      widget.onChanged?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.text('supplies.fillComplete'))),
        );
      }
    } on StateError catch (error) {
      final key = switch (error.message) {
        'insufficientStamina' => 'supplies.error.stamina',
        'cleanEmptyVesselRequired' => 'supplies.error.vessel',
        'vesselMissing' || 'vesselNotPlaced' => 'supplies.error.vessel',
        _ => 'supplies.error.generic',
      };
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(strings.text(key))));
      }
    } finally {
      if (mounted) setState(() => _busyItemId = null);
    }
  }

  Future<void> _washAtPublicRefill(StreetScrapObject vessel) async {
    if (_busyItemId != null) return;
    final strings = StreetScrapLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.text('supplies.washTitle')),
        content: Text(
          strings.text('supplies.washBody', arguments: {'stamina': '2'}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.text('craft.dialog.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.text('supplies.washAction')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busyItemId = vessel.instanceId);
    try {
      await washStreetScrapVesselAtPublicRefill(
        session: widget.session,
        commandId:
            'public-refill-wash-${vessel.instanceId}-${widget.session.snapshot.revision}',
        expectedRevision: widget.session.snapshot.revision,
        catalog: widget.inventoryCatalog,
        grids: widget.grids,
        vesselId: vessel.instanceId,
        maxStamina: widget.maxStamina,
      );
      widget.onChanged?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.text('supplies.washComplete'))),
        );
      }
    } on StateError catch (error) {
      final key = switch (error.message) {
        'insufficientStamina' => 'supplies.error.stamina',
        'vesselAlreadyClean' => 'supplies.error.alreadyClean',
        'vesselNotEmpty' => 'supplies.error.notEmpty',
        'vesselNotPlaced' || 'vesselMissing' => 'supplies.error.vessel',
        _ => 'supplies.error.generic',
      };
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(strings.text(key))));
      }
    } finally {
      if (mounted) setState(() => _busyItemId = null);
    }
  }

  Future<String?> _chooseVessel(StreetScrapLocalizations strings) async {
    final rawInventory = widget.session.snapshot.state['inventory'];
    if (rawInventory is! Map) return null;
    final inventory = widget.inventoryCatalog.inventoryFromJson(
      grids: widget.grids,
      json: Map<String, Object?>.from(rawInventory),
    );
    final vessels = inventory.objects.values
        .where((item) {
          return const {
                'container.clean',
                'container.clean_jar',
                'container.used_intact',
              }.contains(item.itemId) &&
              item.containerState['cleanliness'] == 'clean' &&
              item.containerState['contentItemId'] == null &&
              inventory.placements.containsKey(item.instanceId);
        })
        .toList(growable: false);
    if (vessels.isEmpty || !mounted) return null;
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.text('supplies.chooseVessel')),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final vessel in vessels)
                ListTile(
                  key: ValueKey('renewable-vessel-${vessel.instanceId}'),
                  title: Text(strings.itemName(vessel.itemId)),
                  subtitle: Text(vessel.instanceId),
                  onTap: () => Navigator.pop(context, vessel.instanceId),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(strings.text('craft.dialog.cancel')),
          ),
        ],
      ),
    );
  }

  Future<void> _claim(StreetScrapRenewableSupply supply) async {
    if (_busyItemId != null) return;
    final strings = StreetScrapLocalizations.of(context);
    String? vesselId;
    if (supply.itemId.startsWith('water.')) {
      vesselId = await _chooseVessel(strings);
      if (vesselId == null || !mounted) return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.text('supplies.confirmTitle')),
        content: Text(
          strings.text(
            'supplies.confirmBody',
            arguments: {
              'item': strings.itemName(supply.itemId),
              'quantity': '${supply.quantity}',
              'stamina': '${supply.staminaCost}',
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.text('craft.dialog.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.text('supplies.claim')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busyItemId = supply.itemId);
    try {
      await claimStreetScrapRenewableSupply(
        session: widget.session,
        commandId:
            'renewable-${supply.itemId}-${widget.session.snapshot.revision}',
        expectedRevision: widget.session.snapshot.revision,
        supplyCatalog: widget.catalog,
        inventoryCatalog: widget.inventoryCatalog,
        grids: widget.grids,
        backpackGridId: 'backpack',
        itemId: supply.itemId,
        maxStamina: widget.maxStamina,
        vesselInstanceId: vesselId,
      );
      widget.onChanged?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              strings.text(
                'supplies.claimed',
                arguments: {
                  'item': strings.itemName(supply.itemId),
                  'quantity': '${supply.quantity}',
                },
              ),
            ),
          ),
        );
      }
    } on Object catch (error) {
      final key = switch (error.toString()) {
        'Bad state: insufficientStamina' => 'supplies.error.stamina',
        'Bad state: renewableSupplyNoBackpackSpace' =>
          'supplies.error.backpackSpace',
        'Bad state: renewableSupplyCleanVesselRequired' =>
          'supplies.error.vessel',
        'Bad state: renewableSupplyVesselRequired' => 'supplies.error.vessel',
        'Bad state: renewableSupplyLocked' => 'supplies.error.locked',
        _ => 'supplies.error.generic',
      };
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(strings.text(key)),
            action:
                key == 'supplies.error.backpackSpace' &&
                    widget.onOrganize != null
                ? SnackBarAction(
                    label: strings.text('supplies.organize'),
                    onPressed: widget.onOrganize!,
                  )
                : null,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busyItemId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = StreetScrapLocalizations.of(context);
    final state = widget.session.snapshot.state;
    final chapter = state['chapter'] is int ? state['chapter']! as int : 0;
    final stamina = state['stamina'] is int
        ? state['stamina']! as int
        : widget.maxStamina;
    final available = widget.catalog
        .availableAt(chapter)
        .where((supply) => supply.itemId != 'water.filtered')
        .toList(growable: false);
    final washable = _washableVessels();
    final refillable = _refillableVessels();
    Widget supplyCard(StreetScrapRenewableSupply supply, double width) {
      final canClaim = _busyItemId == null && stamina >= supply.staminaCost;
      return SizedBox(
        width: width,
        child: Card(
          key: ValueKey('renewable-supply-${supply.itemId}'),
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StreetScrapItemSprite(
                  itemId: supply.itemId,
                  source: 'supply:renewable:${supply.itemId}',
                  size: 64,
                  visualScale: 1.12,
                ),
                const SizedBox(height: 4),
                Text(
                  strings.itemName(supply.itemId),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _SupplyMetric(
                      icon: Icons.inventory_2_outlined,
                      value: '×${supply.quantity}',
                      label: strings.text(
                        'supplies.quantitySemantics',
                        arguments: {'quantity': '${supply.quantity}'},
                      ),
                    ),
                    const SizedBox(width: 8),
                    _SupplyMetric(
                      icon: Icons.bolt,
                      value: '${supply.staminaCost}',
                      label: strings.text(
                        'supplies.staminaSemantics',
                        arguments: {'stamina': '${supply.staminaCost}'},
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton.filledTonal(
                      constraints: const BoxConstraints.tightFor(
                        width: 36,
                        height: 36,
                      ),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      key: ValueKey('renewable-supply-action-${supply.itemId}'),
                      tooltip: _busyItemId == supply.itemId
                          ? strings.text('supplies.working')
                          : strings.text('supplies.claim'),
                      onPressed: canClaim ? () => _claim(supply) : null,
                      icon: Icon(
                        _busyItemId == supply.itemId
                            ? Icons.hourglass_top
                            : Icons.add_shopping_cart_outlined,
                        size: 19,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget vesselCard(StreetScrapObject vessel, {required bool wash}) {
      final action = wash
          ? strings.text('supplies.washAction')
          : strings.text('supplies.fillAction');
      final busy = _busyItemId == vessel.instanceId;
      return Semantics(
        label: '${strings.itemName(vessel.itemId)}，$action',
        button: true,
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                StreetScrapItemSprite(
                  itemId: vessel.itemId,
                  source: vessel.source,
                  size: 44,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    strings.itemName(vessel.itemId),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton.filledTonal(
                  key: ValueKey(
                    wash
                        ? 'public-refill-wash-${vessel.instanceId}'
                        : 'public-refill-fill-${vessel.instanceId}',
                  ),
                  constraints: const BoxConstraints.tightFor(
                    width: 36,
                    height: 36,
                  ),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  tooltip: action,
                  onPressed: _busyItemId != null || stamina < 2
                      ? null
                      : () => wash
                            ? _washAtPublicRefill(vessel)
                            : _fillFilteredAtPublicRefill(vessel),
                  icon: Icon(
                    busy
                        ? Icons.hourglass_top
                        : wash
                        ? Icons.cleaning_services_outlined
                        : Icons.water_drop_outlined,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget gridOf<T>(
      List<T> items,
      Widget Function(T item, double width) tile,
    ) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 720
              ? 4
              : constraints.maxWidth >= 470
              ? 3
              : 2;
          const spacing = 8.0;
          final width =
              (constraints.maxWidth - spacing * (columns - 1)) / columns;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [for (final item in items) tile(item, width)],
          );
        },
      );
    }

    return Card(
      child: ExpansionTile(
        key: const Key('street-scrap-renewable-supplies'),
        leading: const Icon(Icons.add_location_alt_outlined),
        title: Text(strings.text('supplies.title')),
        subtitle: Semantics(
          label: strings.text('supplies.repeatable'),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.refresh,
                size: 15,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Text(strings.text('supplies.repeatableShort')),
            ],
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Icon(
                  Icons.water_drop_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(strings.text('supplies.publicRefillTitle')),
                ),
                _SupplyMetric(
                  icon: Icons.bolt,
                  value: '2',
                  label: strings.text(
                    'supplies.staminaSemantics',
                    arguments: const {'stamina': '2'},
                  ),
                ),
              ],
            ),
          ),
          if (refillable.isEmpty && washable.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Semantics(
                label: strings.text('supplies.noWaterVessels'),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(strings.text('supplies.noWaterVessels')),
                    ),
                  ],
                ),
              ),
            ),
          if (refillable.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: gridOf(
                refillable,
                (vessel, _) => vesselCard(vessel, wash: false),
              ),
            ),
          if (washable.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Icon(
                    Icons.cleaning_services_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(strings.text('supplies.publicWashTitle')),
                  ),
                  _SupplyMetric(
                    icon: Icons.bolt,
                    value: '2',
                    label: strings.text(
                      'supplies.staminaSemantics',
                      arguments: const {'stamina': '2'},
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: gridOf(
                washable,
                (vessel, _) => vesselCard(vessel, wash: true),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(strings.text('supplies.availableTitle'))),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: gridOf(available, supplyCard),
          ),
        ],
      ),
    );
  }
}

class _SupplyMetric extends StatelessWidget {
  const _SupplyMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14),
            const SizedBox(width: 3),
            Text(value),
          ],
        ),
      ),
    ),
  );
}
