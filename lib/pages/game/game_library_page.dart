import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../game_modules/game_module_library_extensions.dart';
import '../../game_modules/game_module_manifest.dart';
import '../../services/game_library_controller.dart';
import '../../services/game_resource_library_service.dart';
import '../../services/locale_provider.dart';

class GameLibraryPage extends StatelessWidget {
  const GameLibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<GameLibraryController>();
    final resourceService = context.watch<GameResourceLibraryService?>();
    final t = context.watch<LocaleProvider>().translation;
    final platform = currentGamePlatform;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.text('Game Library')),
        actions: [
          IconButton(
            tooltip: t.text('Refresh game catalog'),
            onPressed: resourceService == null
                ? null
                : () async {
                    try {
                      await resourceService.refreshCatalog();
                    } on Object catch (error, stackTrace) {
                      _logGameLibraryFailure(
                        'refresh-catalog',
                        error,
                        stackTrace,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              t.text(
                                'Could not refresh the game catalog. Check your connection and try again.',
                              ),
                            ),
                          ),
                        );
                      }
                    }
                  },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: !library.isInitialized
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  t.text(
                    'Choose which games to show in your library. Game code is delivered with app updates; optional content packs can be downloaded separately.',
                  ),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                if (!library.canInstallRemoteResources)
                  MaterialBanner(
                    leading: const Icon(Icons.cloud_off_outlined),
                    content: Text(
                      t.text(
                        'The saved game catalog has expired. You can still use and remove installed content; refresh the catalog before downloading or updating packs.',
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: resourceService == null
                            ? null
                            : () async {
                                try {
                                  await resourceService.refreshCatalog();
                                } on Object catch (error, stackTrace) {
                                  _logGameLibraryFailure(
                                    'refresh-catalog',
                                    error,
                                    stackTrace,
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          t.text(
                                            'Could not refresh the game catalog. Check your connection and try again.',
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                        child: Text(t.text('Refresh catalog')),
                      ),
                    ],
                  ),
                for (final module in library.manifests)
                  _moduleCard(
                    context,
                    library,
                    resourceService,
                    module,
                    platform,
                    t,
                  ),
              ],
            ),
    );
  }

  Widget _moduleCard(
    BuildContext context,
    GameLibraryController library,
    GameResourceLibraryService? resourceService,
    GameModuleManifest module,
    GamePlatform? platform,
    Map<String, String> t,
  ) {
    final supported = platform != null && module.platforms.contains(platform);
    final selected = library.isModuleEnabled(module.moduleId);
    final resources = platform == null
        ? const <GameResourceManifest>[]
        : module.resources
              .where((resource) => resource.platforms.contains(platform))
              .toList(growable: false);
    return Card(
      child: Column(
        children: [
          SwitchListTile.adaptive(
            secondary: const Icon(Icons.sports_esports_outlined),
            title: Text(t.text(module.displayName)),
            subtitle: Text(
              '${t.text(module.description)}\n'
              '${t.text('Version')}: ${module.packageVersion} · '
              '${resources.length} ${t.text('optional resource packs')}'
              '${supported ? '' : '\n${t.text('Unavailable on this platform')}'}',
            ),
            value: selected,
            onChanged: selected || supported
                ? (enabled) async {
                    if (enabled && !supported) return;
                    try {
                      await library.setModuleEnabled(module.moduleId, enabled);
                    } on Object catch (error, stackTrace) {
                      _logGameLibraryFailure(
                        'toggle-module:${module.moduleId}',
                        error,
                        stackTrace,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              t.text(
                                'Could not update the game library. Please try again.',
                              ),
                            ),
                          ),
                        );
                      }
                    }
                  }
                : null,
          ),
          if (supported &&
              gameModuleLibraryExtensions.containsKey(module.moduleId))
            gameModuleLibraryExtensions[module.moduleId]!(context),
          for (final resource in resources)
            ListTile(
              dense: true,
              leading: const Icon(Icons.download_for_offline_outlined),
              title: Text(
                t.text(resource.displayNameKey ?? resource.resourceId),
              ),
              subtitle: _resourceSubtitle(
                library,
                module.moduleId,
                resource,
                t,
              ),
              trailing: _resourceAction(
                context,
                library,
                resourceService,
                module.moduleId,
                resource,
                t,
              ),
            ),
        ],
      ),
    );
  }

  Widget _resourceSubtitle(
    GameLibraryController library,
    String moduleId,
    GameResourceManifest resource,
    Map<String, String> t,
  ) {
    final record = library.resourceRecord(moduleId, resource.resourceId);
    final description = resource.descriptionKey == null
        ? null
        : t.text(resource.descriptionKey!);
    final kindLabel = switch (resource.kind) {
      GameResourceKind.gameplayData => t.text('Gameplay content'),
      GameResourceKind.presentation => t.text('Visual assets'),
      GameResourceKind.localization => t.text('Language pack'),
    };
    final impactLabel = t.text(
      resource.affectsGameplay ? 'Affects gameplay' : 'Visuals only',
    );
    final metadata = <String>[
      kindLabel,
      'v${resource.version}',
      impactLabel,
      '${t.text('Package size')}: ${_formatPackageSize(resource.byteLength, t)}',
    ];
    final isInstalled = record?.status == GameResourceInstallStatus.installed;
    if (library.isResourceUpdateAvailable(moduleId, resource)) {
      metadata.add(
        '${t.text('Update available')}: ${record!.version} → ${resource.version}',
      );
    } else if (record != null) {
      metadata.add(t.text('resource.status.${record.status.name}'));
    } else {
      metadata.add(t.text('Not installed'));
    }
    if (!isInstalled && resource.downloadUrl == null) {
      metadata.add(
        t.text('Download unavailable: signed package not published'),
      );
    }
    return Text([?description, metadata.join(' · ')].join('\n'));
  }

  Widget? _resourceAction(
    BuildContext context,
    GameLibraryController library,
    GameResourceLibraryService? service,
    String moduleId,
    GameResourceManifest resource,
    Map<String, String> t,
  ) {
    final record = library.resourceRecord(moduleId, resource.resourceId);
    final installed = record?.status == GameResourceInstallStatus.installed;
    final updateAvailable = library.isResourceUpdateAvailable(
      moduleId,
      resource,
    );
    final removing = record?.status == GameResourceInstallStatus.removing;
    if (service == null) return null;
    if (updateAvailable) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Update resource',
            onPressed:
                resource.downloadUrl == null ||
                    !library.canInstallRemoteResources
                ? null
                : () => _runResourceAction(
                    context,
                    () => service.install(moduleId, resource.resourceId),
                    t: t,
                    operationLabel: '$moduleId/${resource.resourceId}',
                  ),
            icon: const Icon(Icons.system_update_alt),
          ),
          IconButton(
            tooltip: 'Remove download',
            onPressed: () => _runResourceAction(
              context,
              () => service.remove(moduleId, resource.resourceId),
              t: t,
              operationLabel: '$moduleId/${resource.resourceId}',
            ),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      );
    }
    return IconButton(
      tooltip: installed
          ? 'Remove download'
          : removing
          ? 'Retry resource removal'
          : resource.downloadUrl == null
          ? 'Download unavailable: signed package not published'
          : 'Download resource',
      onPressed:
          installed ||
              removing ||
              (resource.downloadUrl != null &&
                  library.canInstallRemoteResources)
          ? () => _runResourceAction(
              context,
              () => installed || removing
                  ? service.remove(moduleId, resource.resourceId)
                  : service.install(moduleId, resource.resourceId),
              t: t,
              operationLabel: '$moduleId/${resource.resourceId}',
            )
          : null,
      icon: Icon(installed || removing ? Icons.delete_outline : Icons.download),
    );
  }

  Future<void> _runResourceAction(
    BuildContext context,
    Future<void> Function() action, {
    required Map<String, String> t,
    String? operationLabel,
  }) async {
    try {
      await action();
    } on Object catch (error, stackTrace) {
      _logGameLibraryFailure(
        'resource:${operationLabel ?? 'unknown'}',
        error,
        stackTrace,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t.text(
                'Resource action failed. Reload the app, refresh the game catalog, then try again.',
              ),
            ),
          ),
        );
      }
    }
  }
}

void _logGameLibraryFailure(
  String operation,
  Object error,
  StackTrace stackTrace,
) {
  if (!kDebugMode) return;
  debugPrint('Game library operation failed ($operation): $error\n$stackTrace');
}

String _formatPackageSize(int? byteLength, Map<String, String> t) {
  if (byteLength == null || byteLength < 0) {
    return t.text('Not specified');
  }
  if (byteLength < 1000) return '$byteLength B';

  const units = ['KB', 'MB', 'GB', 'TB'];
  var size = byteLength / 1000;
  var unitIndex = 0;
  while (size >= 1000 && unitIndex < units.length - 1) {
    size /= 1000;
    unitIndex++;
  }
  final precision = size < 10 ? 1 : 0;
  final formatted = size.toStringAsFixed(precision);
  final trimmed = formatted.endsWith('.0')
      ? formatted.substring(0, formatted.length - 2)
      : formatted;
  return '$trimmed ${units[unitIndex]}';
}
