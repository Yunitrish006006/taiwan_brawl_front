import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'street_scrap_item_sprite.dart';
import 'street_scrap_localizations.dart';
import 'street_scrap_search_scene.dart';

/// First playable slice of the search-scene loop.
///
/// The scene is generated from a seed, while the renderer keeps positions
/// normalized so the same variant can fit phones and tablets. Persistence and
/// the real trailer upgrade table can be connected after this interaction is
/// accepted in playtesting.
class StreetScrapSearchScenePage extends StatefulWidget {
  const StreetScrapSearchScenePage({
    super.key,
    this.seed = 183921,
    this.woodBoardSpriteBytes,
    this.threadSpoolSpriteBytes,
    this.materialAtlasBytes,
    this.toolAtlasBytes,
    this.materialPackArtBytes,
    this.mineralPackSpriteBytes,
    this.woodChipBundleSpriteBytes,
  });

  final int seed;
  final Uint8List? woodBoardSpriteBytes;
  final Uint8List? threadSpoolSpriteBytes;
  final Uint8List? materialAtlasBytes;
  final Uint8List? toolAtlasBytes;
  final Uint8List? materialPackArtBytes;
  final Uint8List? mineralPackSpriteBytes;
  final Uint8List? woodChipBundleSpriteBytes;

  @override
  State<StreetScrapSearchScenePage> createState() =>
      _StreetScrapSearchScenePageState();
}

class _StreetScrapSearchScenePageState
    extends State<StreetScrapSearchScenePage> {
  late final StreetScrapSearchVariant _variant =
      StreetScrapSearchVariantGenerator().generate(
        streetScrapCoastalWarehouseSearchScene,
        seed: widget.seed,
      );
  final Set<String> _revealed = <String>{};
  final Set<String> _collected = <String>{};
  String? _selectedPlacementId;
  String? _carriedPlacementId;
  double _stamina = 100;
  double _trailerWeight = 0;
  double _trailerVolume = 0;
  double _playerX = 0.5;
  String? _feedback;

  StreetScrapSearchItemSpec _itemFor(String itemId) =>
      streetScrapCoastalWarehouseSearchScene.items.firstWhere(
        (item) => item.itemId == itemId,
      );

  StreetScrapSearchPlacement? get _selected => _variant.placements
      .where((placement) => placement.id == _selectedPlacementId)
      .firstOrNull;

  void _tapPlacement(StreetScrapSearchPlacement placement) {
    if (_collected.contains(placement.id) || _carriedPlacementId != null) {
      return;
    }
    final strings = StreetScrapLocalizations.of(context);
    if (!_isNearPlayer(placement)) {
      setState(() => _feedback = strings.text('search.tooFar'));
      return;
    }
    if (placement.concealment != StreetScrapSearchConcealment.visible &&
        !_revealed.contains(placement.id)) {
      setState(() {
        _revealed.add(placement.id);
        _stamina = (_stamina - 1.5).clamp(0, 100);
        _feedback = strings.text('search.revealed');
      });
      return;
    }
    setState(() {
      _selectedPlacementId = placement.id;
      _feedback = strings.text(
        'search.selected',
        arguments: {'item': strings.itemName(placement.itemId)},
      );
    });
  }

  void _pickUpSelected() {
    final placement = _selected;
    if (placement == null || _carriedPlacementId != null) return;
    final item = _itemFor(placement.itemId);
    final strings = StreetScrapLocalizations.of(context);
    final cost = 4 + item.weight * 2;
    if (_stamina < cost) {
      setState(() => _feedback = strings.text('search.notEnoughStamina'));
      return;
    }
    setState(() {
      _stamina -= cost;
      _carriedPlacementId = placement.id;
      _selectedPlacementId = null;
      _feedback = strings.text(
        'search.carrying',
        arguments: {'item': strings.itemName(item.itemId)},
      );
    });
  }

  void _returnToTrailer() {
    final placement = _variant.placements
        .where((candidate) => candidate.id == _carriedPlacementId)
        .firstOrNull;
    if (placement == null) return;
    final item = _itemFor(placement.itemId);
    final strings = StreetScrapLocalizations.of(context);
    if (_trailerWeight + item.weight > 12 ||
        _trailerVolume + item.volume > 16) {
      setState(() => _feedback = strings.text('search.trailerFull'));
      return;
    }
    setState(() {
      _trailerWeight += item.weight;
      _trailerVolume += item.volume;
      _collected.add(placement.id);
      _carriedPlacementId = null;
      _feedback = strings.text('search.stored');
    });
  }

  void _movePlayer(double delta, double worldWidth) {
    setState(() {
      _playerX = (_playerX + delta / worldWidth).clamp(0.05, 0.95);
    });
  }

  bool _isNearPlayer(StreetScrapSearchPlacement placement) {
    final itemCenter = placement.x + placement.width / 2;
    return (itemCenter - _playerX).abs() <= 0.16;
  }

  @override
  Widget build(BuildContext context) {
    final strings = StreetScrapLocalizations.of(context);
    final carried = _carriedPlacementId == null
        ? null
        : _variant.placements
              .where((placement) => placement.id == _carriedPlacementId)
              .firstOrNull;
    final carriedItem = carried == null ? null : _itemFor(carried.itemId);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.text('search.title')),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: Text(
                strings.text(
                  'search.stamina',
                  arguments: {'value': _stamina.round().toString()},
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Keep the authored 16:9 world intact. Portrait uses a
                  // camera window and horizontal movement instead of
                  // cropping the scene or regenerating item positions.
                  final worldWidth = max(
                    constraints.maxWidth,
                    constraints.maxHeight * 16 / 9,
                  );
                  final cameraX =
                      (_playerX * worldWidth - constraints.maxWidth / 2).clamp(
                        0.0,
                        worldWidth - constraints.maxWidth,
                      );
                  return GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragUpdate: (details) =>
                        _movePlayer(details.delta.dx, worldWidth),
                    child: ClipRect(
                      child: Transform.translate(
                        offset: Offset(-cameraX, 0),
                        child: SizedBox(
                          width: worldWidth,
                          height: constraints.maxHeight,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.asset(
                                'packages/taiwan_brawl_game_street_scrap/assets/search/coastal_warehouse_v1.png',
                                fit: BoxFit.fill,
                                filterQuality: FilterQuality.none,
                              ),
                              for (final placement
                                  in (_variant.placements.toList()
                                    ..sort((a, b) => a.y.compareTo(b.y))))
                                if (!_collected.contains(placement.id))
                                  Positioned(
                                    left: placement.x * worldWidth,
                                    top: placement.y * constraints.maxHeight,
                                    width: placement.width * worldWidth,
                                    height:
                                        placement.height *
                                        constraints.maxHeight,
                                    child: _PlacementMarker(
                                      placement: placement,
                                      revealed: _revealed.contains(
                                        placement.id,
                                      ),
                                      item: _itemFor(placement.itemId),
                                      onTap: () => _tapPlacement(placement),
                                      materialAtlasBytes:
                                          widget.materialAtlasBytes,
                                      woodBoardSpriteBytes:
                                          widget.woodBoardSpriteBytes,
                                      threadSpoolSpriteBytes:
                                          widget.threadSpoolSpriteBytes,
                                      toolAtlasBytes: widget.toolAtlasBytes,
                                      materialPackArtBytes:
                                          widget.materialPackArtBytes,
                                      mineralPackSpriteBytes:
                                          widget.mineralPackSpriteBytes,
                                      woodChipBundleSpriteBytes:
                                          widget.woodChipBundleSpriteBytes,
                                    ),
                                  ),
                              Positioned(
                                left: _playerX * worldWidth - 24,
                                top: constraints.maxHeight * 0.76,
                                child: const IgnorePointer(
                                  child: _SearchPlayerMarker(),
                                ),
                              ),
                              if (carriedItem != null)
                                Positioned(
                                  left: _playerX * worldWidth - 36,
                                  top: constraints.maxHeight * 0.67,
                                  child: IgnorePointer(
                                    child: StreetScrapItemSprite(
                                      itemId: carriedItem.itemId,
                                      source: 'search-carried',
                                      size: 72,
                                      visualScale: 1.1,
                                      materialAtlasBytes:
                                          widget.materialAtlasBytes,
                                      woodBoardSpriteBytes:
                                          widget.woodBoardSpriteBytes,
                                      threadSpoolSpriteBytes:
                                          widget.threadSpoolSpriteBytes,
                                      toolAtlasBytes: widget.toolAtlasBytes,
                                      materialPackArtBytes:
                                          widget.materialPackArtBytes,
                                      mineralPackSpriteBytes:
                                          widget.mineralPackSpriteBytes,
                                      woodChipBundleSpriteBytes:
                                          widget.woodChipBundleSpriteBytes,
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
            Material(
              color: Theme.of(context).colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      strings.text(
                        'search.trailer',
                        arguments: {
                          'weight': _trailerWeight.toStringAsFixed(1),
                          'volume': _trailerVolume.toStringAsFixed(1),
                        },
                      ),
                    ),
                    if (carriedItem != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          strings.text(
                            'search.inHands',
                            arguments: {
                              'item': strings.itemName(carriedItem.itemId),
                            },
                          ),
                        ),
                      ),
                    if (_feedback != null)
                      Text(
                        _feedback!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    const SizedBox(height: 6),
                    FilledButton.icon(
                      onPressed: carriedItem == null ? null : _returnToTrailer,
                      icon: const Icon(Icons.local_shipping_outlined),
                      label: Text(strings.text('search.returnToTrailer')),
                    ),
                    if (_selected != null)
                      OutlinedButton.icon(
                        onPressed: _pickUpSelected,
                        icon: const Icon(Icons.back_hand_outlined),
                        label: Text(strings.text('search.pickUp')),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchPlayerMarker extends StatelessWidget {
  const _SearchPlayerMarker();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primary,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 2),
      boxShadow: const [
        BoxShadow(color: Colors.black45, blurRadius: 5, offset: Offset(0, 2)),
      ],
    ),
    child: const SizedBox(width: 48, height: 48),
  );
}

class _PlacementMarker extends StatelessWidget {
  const _PlacementMarker({
    required this.placement,
    required this.revealed,
    required this.item,
    required this.onTap,
    this.materialAtlasBytes,
    this.woodBoardSpriteBytes,
    this.threadSpoolSpriteBytes,
    this.toolAtlasBytes,
    this.materialPackArtBytes,
    this.mineralPackSpriteBytes,
    this.woodChipBundleSpriteBytes,
  });

  final StreetScrapSearchPlacement placement;
  final bool revealed;
  final StreetScrapSearchItemSpec item;
  final VoidCallback onTap;
  final Uint8List? materialAtlasBytes;
  final Uint8List? woodBoardSpriteBytes;
  final Uint8List? threadSpoolSpriteBytes;
  final Uint8List? toolAtlasBytes;
  final Uint8List? materialPackArtBytes;
  final Uint8List? mineralPackSpriteBytes;
  final Uint8List? woodChipBundleSpriteBytes;

  @override
  Widget build(BuildContext context) {
    final strings = StreetScrapLocalizations.of(context);
    final isRevealed =
        placement.concealment == StreetScrapSearchConcealment.visible ||
        revealed;
    return Semantics(
      button: true,
      label: isRevealed
          ? strings.itemName(item.itemId)
          : strings.text('search.hiddenSpot'),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Transform.rotate(
          angle: placement.rotation,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              boxShadow: isRevealed
                  ? const [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 5,
                        offset: Offset(1, 2),
                      ),
                    ]
                  : const [],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (isRevealed)
                  LayoutBuilder(
                    builder: (context, constraints) => Center(
                      child: StreetScrapItemSprite(
                        itemId: item.itemId,
                        source: 'search',
                        size: constraints.biggest.shortestSide.clamp(
                          24.0,
                          128.0,
                        ),
                        visualScale: 1.05,
                        materialAtlasBytes: materialAtlasBytes,
                        woodBoardSpriteBytes: woodBoardSpriteBytes,
                        threadSpoolSpriteBytes: threadSpoolSpriteBytes,
                        toolAtlasBytes: toolAtlasBytes,
                        materialPackArtBytes: materialPackArtBytes,
                        mineralPackSpriteBytes: mineralPackSpriteBytes,
                        woodChipBundleSpriteBytes: woodChipBundleSpriteBytes,
                      ),
                    ),
                  ),
                if (!isRevealed ||
                    placement.concealment !=
                        StreetScrapSearchConcealment.visible)
                  Positioned.fill(
                    child: _SearchEnvironmentCover(
                      zoneId: placement.zoneId,
                      concealment: placement.concealment,
                      revealed: isRevealed,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchEnvironmentCover extends StatelessWidget {
  const _SearchEnvironmentCover({
    required this.zoneId,
    required this.concealment,
    required this.revealed,
  });

  final String zoneId;
  final StreetScrapSearchConcealment concealment;
  final bool revealed;

  @override
  Widget build(BuildContext context) {
    final environment = zoneId.contains('soil')
        ? _SearchCoverEnvironment.soil
        : zoneId.contains('tarp')
        ? _SearchCoverEnvironment.tarp
        : zoneId.contains('shelf') || zoneId.contains('crate')
        ? _SearchCoverEnvironment.crate
        : _SearchCoverEnvironment.grass;
    final asset = switch (environment) {
      _SearchCoverEnvironment.soil =>
        'packages/taiwan_brawl_game_street_scrap/assets/search/soil_cover_v1.png',
      _SearchCoverEnvironment.grass =>
        'packages/taiwan_brawl_game_street_scrap/assets/search/grass_cover_v1.png',
      _SearchCoverEnvironment.tarp =>
        'packages/taiwan_brawl_game_street_scrap/assets/search/tarp_cover_v1.png',
      _SearchCoverEnvironment.crate =>
        'packages/taiwan_brawl_game_street_scrap/assets/search/crate_cover_v1.png',
    };
    final partial =
        revealed && concealment != StreetScrapSearchConcealment.fullyBuried;
    final alignment =
        environment == _SearchCoverEnvironment.soil ||
            environment == _SearchCoverEnvironment.grass
        ? Alignment.bottomCenter
        : Alignment.topCenter;
    return IgnorePointer(
      child: ClipRect(
        child: FractionallySizedBox(
          heightFactor: partial ? 0.58 : 1,
          alignment: alignment,
          child: Image.asset(
            asset,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.none,
          ),
        ),
      ),
    );
  }
}

enum _SearchCoverEnvironment { soil, grass, tarp, crate }
