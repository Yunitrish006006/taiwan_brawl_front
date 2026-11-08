import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'street_scrap_expedition.dart';
import 'street_scrap_renewable_supplies.dart';
import 'street_scrap_fishing.dart';
import 'street_scrap_progress.dart';
import 'street_scrap_inventory.dart';
import 'street_scrap_crafting.dart';
import 'street_scrap_orders.dart';
import 'street_scrap_woodworking.dart';
import 'street_scrap_inventory_page.dart';
import 'street_scrap_save_recovery_page.dart';
import 'street_scrap_module.dart';
import 'street_scrap_localizations.dart';

class StreetScrapProgressEntryPage extends StatefulWidget {
  const StreetScrapProgressEntryPage({
    super.key,
    required this.session,
    required this.contentInstalled,
    this.chapter5Installed = false,
    required this.readContent,
    this.artInstalled = false,
    this.readArt,
    this.threadSpoolArtInstalled = false,
    this.readThreadSpoolArt,
    this.materialAtlasInstalled = false,
    this.readMaterialAtlas,
    this.toolAtlasInstalled = false,
    this.readToolAtlas,
    this.materialPackArtInstalled = false,
    this.readMaterialPackArt,
    this.mineralPackArtInstalled = false,
    this.readMineralPackArt,
    this.woodChipBundleArtInstalled = false,
    this.readWoodChipBundleArt,
    this.fishingSceneArtInstalled = false,
    this.readFishingSceneArt,
    this.protagonistArtInstalled = false,
    this.readProtagonistArt,
    required this.onOpenLibrary,
  });

  final StreetScrapSession session;
  final bool contentInstalled;
  final bool chapter5Installed;
  final Future<Uint8List?> Function() readContent;
  final bool artInstalled;
  final Future<Uint8List?> Function()? readArt;
  final bool threadSpoolArtInstalled;
  final Future<Uint8List?> Function()? readThreadSpoolArt;
  final bool materialAtlasInstalled;
  final Future<Uint8List?> Function()? readMaterialAtlas;
  final bool toolAtlasInstalled;
  final Future<Uint8List?> Function()? readToolAtlas;
  final bool materialPackArtInstalled;
  final Future<Uint8List?> Function()? readMaterialPackArt;
  final bool mineralPackArtInstalled;
  final Future<Uint8List?> Function()? readMineralPackArt;
  final bool woodChipBundleArtInstalled;
  final Future<Uint8List?> Function()? readWoodChipBundleArt;
  final bool fishingSceneArtInstalled;
  final Future<Uint8List?> Function()? readFishingSceneArt;
  final bool protagonistArtInstalled;
  final Future<Uint8List?> Function()? readProtagonistArt;
  final VoidCallback onOpenLibrary;

  @override
  State<StreetScrapProgressEntryPage> createState() =>
      _StreetScrapProgressEntryPageState();
}

class _StreetScrapProgressEntryPageState
    extends State<StreetScrapProgressEntryPage> {
  bool _loading = true;
  Object? _loadError;
  StreetScrapRecoveryReport? _recoveryReport;
  StreetScrapInventoryCatalog? _catalog;
  StreetScrapRecipeCatalog? _recipeCatalog;
  StreetScrapExpeditionRules? _expeditionRules;
  StreetScrapFishingRules? _fishingRules;
  StreetScrapOrderCatalog? _orderCatalog;
  StreetScrapToolRepairCatalog? _repairCatalog;
  StreetScrapRenewableSupplyCatalog? _renewableSupplyCatalog;
  int _maxStamina = 60;
  Uint8List? _woodBoardSpriteBytes;
  Uint8List? _threadSpoolSpriteBytes;
  Uint8List? _materialAtlasBytes;
  Uint8List? _toolAtlasBytes;
  Uint8List? _materialPackArtBytes;
  Uint8List? _mineralPackArtBytes;
  Uint8List? _woodChipBundleArtBytes;
  Uint8List? _fishingSceneArtBytes;
  StreetScrapProtagonistArt? _protagonistArt;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant StreetScrapProgressEntryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session == widget.session) return;
    _loading = true;
    _loadError = null;
    _recoveryReport = null;
    _catalog = null;
    _recipeCatalog = null;
    _expeditionRules = null;
    _fishingRules = null;
    _orderCatalog = null;
    _repairCatalog = null;
    _renewableSupplyCatalog = null;
    _woodBoardSpriteBytes = null;
    _threadSpoolSpriteBytes = null;
    _materialAtlasBytes = null;
    _toolAtlasBytes = null;
    _mineralPackArtBytes = null;
    _woodChipBundleArtBytes = null;
    _fishingSceneArtBytes = null;
    _protagonistArt = null;
    unawaited(_closePreviousAndLoad(oldWidget.session));
  }

  @override
  void dispose() {
    unawaited(widget.session.close());
    super.dispose();
  }

  Future<void> _load() async {
    try {
      await widget.session.load();
      StreetScrapInventoryCatalog? catalog;
      StreetScrapRecipeCatalog? recipeCatalog;
      StreetScrapExpeditionRules? expeditionRules;
      StreetScrapFishingRules? fishingRules;
      StreetScrapOrderCatalog? orderCatalog;
      StreetScrapToolRepairCatalog? repairCatalog;
      StreetScrapRenewableSupplyCatalog? renewableSupplyCatalog;
      var maxStamina = 60;
      Uint8List? woodBoardSpriteBytes;
      Uint8List? threadSpoolSpriteBytes;
      Uint8List? materialAtlasBytes;
      Uint8List? toolAtlasBytes;
      Uint8List? materialPackArtBytes;
      Uint8List? mineralPackArtBytes;
      Uint8List? woodChipBundleArtBytes;
      Uint8List? fishingSceneArtBytes;
      StreetScrapProtagonistArt? protagonistArt;
      if (widget.artInstalled && widget.readArt != null) {
        try {
          woodBoardSpriteBytes = await widget.readArt!();
          if (woodBoardSpriteBytes != null) {
            await validateStreetScrapArtBytes(woodBoardSpriteBytes);
          }
        } on Object {
          // Broken optional art falls back to the built-in material silhouettes;
          // it never blocks gameplay or invalidates a save.
          woodBoardSpriteBytes = null;
        }
      }
      if (widget.threadSpoolArtInstalled && widget.readThreadSpoolArt != null) {
        try {
          threadSpoolSpriteBytes = await widget.readThreadSpoolArt!();
          if (threadSpoolSpriteBytes != null) {
            await validateStreetScrapArtBytes(threadSpoolSpriteBytes);
          }
        } on Object {
          threadSpoolSpriteBytes = null;
        }
      }
      if (widget.materialAtlasInstalled && widget.readMaterialAtlas != null) {
        try {
          materialAtlasBytes = await widget.readMaterialAtlas!();
          if (materialAtlasBytes != null) {
            await validateStreetScrapMaterialAtlasBytes(materialAtlasBytes);
          }
        } on Object {
          materialAtlasBytes = null;
        }
      }
      if (widget.toolAtlasInstalled && widget.readToolAtlas != null) {
        try {
          toolAtlasBytes = await widget.readToolAtlas!();
          if (toolAtlasBytes != null) {
            await validateStreetScrapToolAtlasBytes(toolAtlasBytes);
          }
        } on Object {
          toolAtlasBytes = null;
        }
      }
      if (widget.materialPackArtInstalled &&
          widget.readMaterialPackArt != null) {
        try {
          materialPackArtBytes = await widget.readMaterialPackArt!();
          if (materialPackArtBytes != null) {
            await validateStreetScrapMaterialPackArtBytes(materialPackArtBytes);
          }
        } on Object {
          materialPackArtBytes = null;
        }
      }
      if (widget.mineralPackArtInstalled && widget.readMineralPackArt != null) {
        try {
          mineralPackArtBytes = await widget.readMineralPackArt!();
          if (mineralPackArtBytes != null) {
            await validateStreetScrapArtBytes(mineralPackArtBytes);
          }
        } on Object {
          mineralPackArtBytes = null;
        }
      }
      if (widget.woodChipBundleArtInstalled &&
          widget.readWoodChipBundleArt != null) {
        try {
          woodChipBundleArtBytes = await widget.readWoodChipBundleArt!();
          if (woodChipBundleArtBytes != null) {
            await validateStreetScrapArtBytes(woodChipBundleArtBytes);
          }
        } on Object {
          woodChipBundleArtBytes = null;
        }
      }
      if (widget.fishingSceneArtInstalled &&
          widget.readFishingSceneArt != null) {
        try {
          fishingSceneArtBytes = await widget.readFishingSceneArt!();
          if (fishingSceneArtBytes != null) {
            await validateStreetScrapFishingSceneArtBytes(fishingSceneArtBytes);
          }
        } on Object {
          fishingSceneArtBytes = null;
        }
      }
      if (widget.protagonistArtInstalled && widget.readProtagonistArt != null) {
        try {
          final payload = await widget.readProtagonistArt!();
          if (payload != null) {
            protagonistArt = StreetScrapProtagonistArt.fromPayload(payload);
          }
        } on Object {
          // Optional character artwork falls back to the lightweight painter.
          protagonistArt = null;
        }
      }
      if (widget.contentInstalled) {
        try {
          final bytes = await widget.readContent();
          if (bytes == null) throw StateError('已安裝內容在本機快取中不存在。');
          final source = utf8.decode(bytes, allowMalformed: false);
          catalog = StreetScrapInventoryCatalog.fromContentPayload(source);
          recipeCatalog = StreetScrapRecipeCatalog.fromContentPayload(source);
          final payload = jsonDecode(source) as Map<String, dynamic>;
          expeditionRules = StreetScrapExpeditionRules.fromJson(
            Map<String, Object?>.from(payload['scavenging'] as Map),
          );
          fishingRules = StreetScrapFishingRules.fromJson(
            Map<String, Object?>.from(payload['fishing'] as Map),
          );
          orderCatalog = StreetScrapOrderCatalog.fromContentPayload(source);
          repairCatalog = StreetScrapToolRepairCatalog.fromContentPayload(
            source,
          );
          renewableSupplyCatalog =
              StreetScrapRenewableSupplyCatalog.fromContentPayload(source);
          maxStamina = (payload['limits'] as Map)['staminaMax'] as int;
        } on Object {
          // Content activation is all-or-nothing: never expose a partially
          // parsed inventory or expedition contract when recipe validation
          // fails later in the same payload.
          catalog = null;
          recipeCatalog = null;
          expeditionRules = null;
          fishingRules = null;
          orderCatalog = null;
          repairCatalog = null;
          renewableSupplyCatalog = null;
        }
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = null;
        _recoveryReport = null;
        _catalog = catalog;
        _recipeCatalog = recipeCatalog;
        _expeditionRules = expeditionRules;
        _fishingRules = fishingRules;
        _orderCatalog = orderCatalog;
        _repairCatalog = repairCatalog;
        _renewableSupplyCatalog = renewableSupplyCatalog;
        _maxStamina = maxStamina;
        _woodBoardSpriteBytes = woodBoardSpriteBytes;
        _threadSpoolSpriteBytes = threadSpoolSpriteBytes;
        _materialAtlasBytes = materialAtlasBytes;
        _toolAtlasBytes = toolAtlasBytes;
        _materialPackArtBytes = materialPackArtBytes;
        _mineralPackArtBytes = mineralPackArtBytes;
        _woodChipBundleArtBytes = woodChipBundleArtBytes;
        _fishingSceneArtBytes = fishingSceneArtBytes;
        _protagonistArt = protagonistArt;
      });
    } on Object catch (error) {
      StreetScrapRecoveryReport? report;
      try {
        report = await widget.session.inspectRecovery();
      } on Object {
        // The failure screen remains safe even if recovery metadata is damaged.
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error;
        _recoveryReport = report;
      });
    }
  }

  Future<void> _closePreviousAndLoad(StreetScrapSession previous) async {
    await previous.close();
    if (mounted) await _load();
  }

  Future<void> _restore(StreetScrapRecoveryCandidate candidate) async {
    final report = _recoveryReport;
    if (report == null) return;
    setState(() => _loading = true);
    try {
      await widget.session.restoreBackup(
        backupRevision: candidate.snapshot.revision,
        expectedStorageToken: report.storageToken,
      );
      if (mounted) await _load();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = StreetScrapLocalizations.of(context);
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(strings.text('game.title'))),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final report = _recoveryReport;
    if (_loadError != null && report?.currentSnapshotIsDamaged == true) {
      return StreetScrapSaveRecoveryPage(
        report: report!,
        supportedRulesetVersion: widget.session.rulesetVersion,
        canRestore: !widget.session.isReadOnly,
        onRestore: _restore,
      );
    }
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: Text(strings.text('game.title'))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 16),
                Text(strings.text('entry.saveLoadFailed')),
                const SizedBox(height: 8),
                Text(
                  strings.text('entry.saveLoadAdvice'),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: widget.onOpenLibrary,
                  child: Text(strings.text('entry.backToLibrary')),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final snapshot = widget.session.snapshot;
    if (widget.contentInstalled && _catalog == null) {
      return Scaffold(
        appBar: AppBar(title: Text(strings.text('game.title'))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_outlined, size: 48),
                const SizedBox(height: 12),
                Text(strings.text('entry.contentLoadFailed')),
                const SizedBox(height: 8),
                Text(
                  strings.text('entry.contentLoadAdvice'),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: widget.onOpenLibrary,
                  child: Text(strings.text('entry.backToLibrary')),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_catalog case final catalog?) {
      final rules = _expeditionRules;
      if (rules == null) {
        return Scaffold(
          appBar: AppBar(title: Text(strings.text('game.title'))),
          body: Center(child: Text(strings.text('entry.rulesLoadFailed'))),
        );
      }
      return Scaffold(
        appBar: AppBar(title: Text(strings.text('game.title'))),
        body: StreetScrapInventoryPage(
          initiallyShowMaterialGallery: true,
          session: widget.session,
          catalog: catalog,
          recipeCatalog: _recipeCatalog!,
          expeditionRules: rules,
          repairCatalog: _repairCatalog!,
          renewableSupplies: _renewableSupplyCatalog!,
          fishingRules: _fishingRules!,
          orderCatalog: _orderCatalog!,
          maxStamina: _maxStamina,
          chapter5Installed: widget.chapter5Installed,
          woodBoardSpriteBytes: _woodBoardSpriteBytes,
          threadSpoolSpriteBytes: _threadSpoolSpriteBytes,
          materialAtlasBytes: _materialAtlasBytes,
          toolAtlasBytes: _toolAtlasBytes,
          materialPackArtBytes: _materialPackArtBytes,
          mineralPackArtBytes: _mineralPackArtBytes,
          woodChipBundleArtBytes: _woodChipBundleArtBytes,
          fishingSceneArtBytes: _fishingSceneArtBytes,
          protagonistArt: _protagonistArt,
          onOpenLibrary: widget.onOpenLibrary,
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(strings.text('game.title'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(Icons.recycling_outlined, size: 56),
              const SizedBox(height: 16),
              Text(
                strings.text('entry.loaded'),
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                snapshot.revision == 0 && snapshot.state.isEmpty
                    ? strings.text('entry.noProgress')
                    : strings.text(
                        'entry.progressVersion',
                        arguments: {
                          'revision': '${snapshot.revision}',
                          'savedAt': '${snapshot.savedAt.toLocal()}',
                        },
                      ),
                textAlign: TextAlign.center,
              ),
              if (widget.session.isReadOnly) ...[
                const SizedBox(height: 12),
                ListTile(
                  leading: Icon(Icons.lock_outline),
                  title: Text(strings.text('entry.readOnlyTitle')),
                  subtitle: Text(strings.text('entry.readOnlyBody')),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                strings.text('entry.contentNotInstalled'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: widget.onOpenLibrary,
                icon: const Icon(Icons.inventory_2_outlined),
                label: Text(strings.text('entry.openLibrary')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
