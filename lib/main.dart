import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

import 'constants/app_constants.dart';
import 'constants/app_theme_catalog.dart';
import 'constants/locale_catalog.dart';
import 'config/app_configuration.dart';
import 'game_modules/bundled_game_catalog.dart';
import 'game_modules/game_resource_migrations.dart';
import 'game_modules/mini_royale_game_contract.dart';
import 'game_modules/mini_royale_platform_adapters.dart';
import 'game_modules/game_module_routes.dart';
// 以下頁面只在第一次導航時才下載對應的 JS chunk
import 'pages/admin/card_management_page.dart' deferred as card_management;
import 'pages/admin/role_management_page.dart' deferred as role_management;
import 'pages/general/auth_page.dart' deferred as auth_page;
import 'pages/general/splash_page.dart';
import 'pages/home/home_page.dart';
import 'pages/profile/profile_page.dart' deferred as profile_page;
import 'package:taiwan_brawl_game_mini_royale/taiwan_brawl_game_mini_royale.dart'
    as mini_royale;
import 'pages/game/game_library_page.dart';
import 'services/ad_service.dart';
import 'services/admin_service.dart';
import 'services/admin_remote_source.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/auth_remote_source.dart';
import 'services/chat_service_factory.dart';
import 'services/friends_overview_sync_service.dart';
import 'services/friends_service.dart';
import 'services/friends_remote_source.dart';
import 'services/game_library_controller.dart';
import 'services/game_library_store.dart';
import 'services/game_resource_catalog_source.dart';
import 'services/game_resource_content_store.dart';
import 'services/game_resource_installer.dart';
import 'services/game_resource_library_service.dart';
import 'services/legacy_chat_remote_source.dart';
import 'services/legacy_installation_store.dart';
import 'services/local_chat_repository.dart';
import 'services/locale_provider.dart';
import 'services/messaging_core_service.dart';
import 'services/messaging_runtime_bootstrap.dart';
import 'services/messaging_transport_factory.dart';
import 'services/notification_service.dart';
import 'services/notification_remote_source.dart';
import 'services/pending_notification_source.dart';
import 'services/llm_bot_service.dart';
import 'services/llm_bot_remote_source.dart';
import 'services/platform_credential_store.dart';
import 'services/peer_trust_service.dart';
import 'services/preview_runtime.dart';
import 'services/royale_service.dart';
import 'services/royale_remote_source.dart';
import 'services/storage_runtime.dart';
import 'services/taiwan_brawl_profile_service.dart';
import 'services/theme_provider.dart';
import 'services/ui_settings_provider.dart';

final RouteObserver<PageRoute<dynamic>> appRouteObserver =
    RouteObserver<PageRoute<dynamic>>();

/// 通用的延遲載入包裝器。
/// 第一次建立時呼叫 [loadLibrary]，下載對應的 JS chunk；
/// 載入完成前顯示 loading indicator。
class _DeferredWidget extends StatefulWidget {
  const _DeferredWidget({required this.loadLibrary, required this.builder});

  final Future<void> Function() loadLibrary;
  final WidgetBuilder builder;

  @override
  State<_DeferredWidget> createState() => _DeferredWidgetState();
}

class _DeferredWidgetState extends State<_DeferredWidget> {
  late final Future<void> _loading;

  @override
  void initState() {
    super.initState();
    _loading = widget.loadLibrary();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loading,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('Failed to load page')),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return widget.builder(context);
      },
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const configuration = AppConfiguration.environment;
  if (configuration.previewMode) {
    final preview = await PreviewRuntime.create(configuration);
    final catalogSource = GameResourceCatalogSource(
      preview.apiClient,
      trustedKeys: _trustedGameCatalogKeys(),
    );
    final gameLibrary = GameLibraryController(
      catalog: bundledGameCatalog,
      store: HiveGameLibraryStore(),
      cachedCatalogVerifier: catalogSource.verifyCachedEnvelope,
    );
    await gameLibrary.initialize();
    _runPreviewApp(configuration, preview, gameLibrary);
    return;
  }
  await AdService.initialize();
  await HiveStorageRuntime().initialize();
  final credentials = PlatformCredentialStore();
  final apiClient = ApiClient(
    credentials: credentials,
    configuration: configuration,
  );
  final catalogSource = GameResourceCatalogSource(
    apiClient,
    trustedKeys: _trustedGameCatalogKeys(),
  );
  final gameLibrary = GameLibraryController(
    catalog: bundledGameCatalog,
    store: HiveGameLibraryStore(),
    cachedCatalogVerifier: catalogSource.verifyCachedEnvelope,
  );
  await gameLibrary.initialize();
  final messagingRuntime = await restoreMessagingRuntime(credentials);
  final peerTrust = PeerTrustService(credentials: credentials);
  final remoteAuthenticator =
      configuration.peerVerificationEnabled &&
          messagingRuntime.deviceIdentity != null
      ? peerTrust.remoteAuthenticator(local: messagingRuntime.deviceIdentity!)
      : null;
  final legacyChatStore = LocalChatRepository();
  final legacyChatRemoteSource = ServerLegacyChatRemoteSource(apiClient);
  final legacyInstallationStore = HiveLegacyInstallationStore();
  final adminRemoteSource = ServerAdminRemoteSource(apiClient);
  final authRemoteSource = ServerAuthRemoteSource(apiClient);
  final friendsRemoteSource = ServerFriendsRemoteSource(apiClient);
  final llmBotRemoteSource = ServerLlmBotRemoteSource(apiClient);
  final royaleRemoteSource = ServerRoyaleRemoteSource(apiClient);
  final notificationRemoteSource = ServerNotificationRemoteSource(apiClient);
  final pendingNotificationSource = ServerPendingNotificationSource(apiClient);
  final battleAnimationCacheService = mini_royale.BattleAnimationCacheService(
    store: HiveBattleAnimationCacheStore(),
    remoteSource: HttpBattleAnimationRemoteSource(),
  );
  await battleAnimationCacheService.initialize();
  final notificationService = NotificationService(
    apiClient,
    localRepository: legacyChatStore,
    messagingCore: messagingRuntime.core,
    credentials: credentials,
    legacyInstallationStore: legacyInstallationStore,
    remoteAuthenticator: remoteAuthenticator,
    remoteSource: notificationRemoteSource,
    pendingNotificationSource: pendingNotificationSource,
  );
  await notificationService.initialize();
  final messagingTransportFactory = MessagingTransportFactory(
    apiClient,
    p2pEnabled: configuration.p2pChatEnabled,
    syncCursorStoreFactory: messagingRuntime.syncCursorStore == null
        ? null
        : ({required selfId, required friendId}) =>
              messagingRuntime.syncCursorStore!,
  );
  final chatServiceFactory = ChatServiceFactory(
    apiClient: apiClient,
    messagingCore: messagingRuntime.core,
    authenticator: messagingRuntime.deviceIdentity == null
        ? null
        : DeviceEventAuthenticator(
            localIdentity: messagingRuntime.deviceIdentity!,
          ),
    remoteAuthenticator: remoteAuthenticator,
    deviceId: messagingRuntime.deviceIdentity?.deviceId,
    localRepository: legacyChatStore,
    remoteSource: legacyChatRemoteSource,
    transportFactory: messagingTransportFactory.create,
    manualSignaling: ManualPeerSignaling(),
    manualTransportFactory: messagingTransportFactory.createP2P,
  );
  runApp(
    MultiProvider(
      providers: [
        Provider<AppConfiguration>.value(value: configuration),
        ChangeNotifierProvider<GameLibraryController>.value(value: gameLibrary),
        Provider<ApiClient>.value(value: apiClient),
        Provider<GameResourceLibraryService>(
          create: (_) =>
              _createGameResourceLibraryService(gameLibrary, apiClient),
        ),
        Provider<AdminService>(
          create: (_) =>
              AdminService(apiClient, remoteSource: adminRemoteSource),
        ),
        Provider<LlmBotService>(
          create: (_) => LlmBotService(
            apiClient,
            remoteSource: llmBotRemoteSource,
            configuration: configuration,
          ),
        ),
        Provider<RoyaleService>(
          create: (_) => RoyaleService(
            apiClient,
            remoteSource: royaleRemoteSource,
            configuration: configuration,
            gameContractProvider: () => miniRoyaleGameContractFor(gameLibrary),
          ),
        ),
        Provider<MiniRoyaleService>(
          create: (context) => context.read<RoyaleService>(),
        ),
        Provider<FriendsService>(
          create: (_) => FriendsService(
            apiClient,
            remoteSource: friendsRemoteSource,
            configuration: configuration,
          ),
        ),
        Provider<MessagingStorageStatus>.value(
          value: messagingRuntime.core.storageStatus,
        ),
        Provider<MessagingTransportFactory>(
          create: (_) => messagingTransportFactory,
        ),
        Provider<ChatServiceFactory>.value(value: chatServiceFactory),
        Provider<MessagingCoreService>(
          create: (_) => messagingRuntime.core,
          dispose: (_, service) => service.dispose(),
        ),
        Provider<DeviceIdentity?>.value(value: messagingRuntime.deviceIdentity),
        Provider<PeerTrustService>.value(value: peerTrust),
        ChangeNotifierProvider<mini_royale.BattleAnimationCacheService>.value(
          value: battleAnimationCacheService,
        ),
        ChangeNotifierProvider(
          create: (_) => AuthService(
            apiClient,
            remoteSource: authRemoteSource,
            configuration: configuration,
          ),
        ),
        ChangeNotifierProxyProvider<AuthService, NotificationService>(
          create: (_) => notificationService,
          update: (_, auth, service) {
            final nextService = service ?? notificationService;
            nextService.syncAuth(auth);
            return nextService;
          },
        ),
        ChangeNotifierProxyProvider<AuthService, FriendsOverviewSyncService>(
          create: (context) =>
              FriendsOverviewSyncService(context.read<FriendsService>()),
          update: (context, auth, friendsSyncService) {
            final service =
                friendsSyncService ??
                FriendsOverviewSyncService(context.read<FriendsService>());
            service.syncAuth(auth);
            return service;
          },
        ),
        ChangeNotifierProxyProvider<AuthService, ThemeProvider>(
          create: (_) => ThemeProvider(
            defaultThemeId: defaultAppThemeId,
            themes: taiwanBrawlThemes,
          ),
          update: (_, auth, themeProvider) {
            final provider =
                themeProvider ??
                ThemeProvider(
                  defaultThemeId: defaultAppThemeId,
                  themes: taiwanBrawlThemes,
                );
            provider.syncForUser(
              auth.user?.id,
              themeMode: auth.user?.themeMode,
            );
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<AuthService, UiSettingsProvider>(
          create: (_) => UiSettingsProvider(),
          update: (_, auth, uiSettingsProvider) {
            final provider = uiSettingsProvider ?? UiSettingsProvider();
            provider.syncForUser(
              auth.user?.id,
              fontScale: auth.user?.fontSizeScale,
            );
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<AuthService, TaiwanBrawlProfileService>(
          create: (ctx) => TaiwanBrawlProfileService(ctx.read<AuthService>()),
          update: (_, auth, prev) => prev ?? TaiwanBrawlProfileService(auth),
        ),
        ChangeNotifierProxyProvider<AuthService, LocaleProvider>(
          create: (_) => LocaleProvider(
            defaultLocale: defaultLocaleCode,
            translationResolver: translationForLocale,
          ),
          update: (_, auth, localeProvider) {
            final provider =
                localeProvider ??
                LocaleProvider(
                  defaultLocale: defaultLocaleCode,
                  translationResolver: translationForLocale,
                );
            provider.syncForUser(auth.user?.id, locale: auth.user?.locale);
            return provider;
          },
        ),
      ],
      child: const MainApp(),
    ),
  );
}

void _runPreviewApp(
  AppConfiguration configuration,
  PreviewRuntime preview,
  GameLibraryController gameLibrary,
) {
  runApp(
    MultiProvider(
      providers: [
        Provider<AppConfiguration>.value(value: configuration),
        ChangeNotifierProvider<GameLibraryController>.value(value: gameLibrary),
        Provider<ApiClient>.value(value: preview.apiClient),
        Provider<GameResourceLibraryService>(
          create: (_) =>
              _createGameResourceLibraryService(gameLibrary, preview.apiClient),
        ),
        Provider<PlatformCredentialStore>.value(value: preview.credentials),
        Provider<AdminService>(
          create: (_) => AdminService(
            preview.apiClient,
            remoteSource: preview.adminRemoteSource,
          ),
        ),
        Provider<LlmBotService>(
          create: (_) => LlmBotService(
            preview.apiClient,
            remoteSource: preview.llmBotRemoteSource,
            configuration: configuration,
          ),
        ),
        Provider<RoyaleService>(
          create: (_) => RoyaleService(
            preview.apiClient,
            remoteSource: preview.royaleRemoteSource,
            configuration: configuration,
            gameContractProvider: () => miniRoyaleGameContractFor(gameLibrary),
          ),
        ),
        Provider<MiniRoyaleService>(
          create: (context) => context.read<RoyaleService>(),
        ),
        Provider<FriendsService>(
          create: (_) => FriendsService(
            preview.apiClient,
            remoteSource: preview.friendsRemoteSource,
            configuration: configuration,
          ),
        ),
        Provider<MessagingStorageStatus>.value(
          value: preview.messagingRuntime.core.storageStatus,
        ),
        Provider<ChatServiceFactory>.value(value: preview.chatServiceFactory),
        Provider<MessagingCoreService>.value(
          value: preview.messagingRuntime.core,
        ),
        Provider<DeviceIdentity?>.value(
          value: preview.messagingRuntime.deviceIdentity,
        ),
        Provider<PeerTrustService>.value(value: preview.peerTrust),
        ChangeNotifierProvider<mini_royale.BattleAnimationCacheService>.value(
          value: preview.battleAnimationCacheService,
        ),
        ChangeNotifierProvider<AuthService>.value(value: preview.authService),
        ChangeNotifierProxyProvider<AuthService, NotificationService>(
          create: (_) => preview.notificationService,
          update: (_, auth, service) {
            final nextService = service ?? preview.notificationService;
            nextService.syncAuth(auth);
            return nextService;
          },
        ),
        ChangeNotifierProxyProvider<AuthService, FriendsOverviewSyncService>(
          create: (context) =>
              FriendsOverviewSyncService(context.read<FriendsService>()),
          update: (context, auth, service) {
            final next =
                service ??
                FriendsOverviewSyncService(context.read<FriendsService>());
            next.syncAuth(auth);
            return next;
          },
        ),
        ChangeNotifierProxyProvider<AuthService, ThemeProvider>(
          create: (_) => ThemeProvider(
            defaultThemeId: defaultAppThemeId,
            themes: taiwanBrawlThemes,
          ),
          update: (_, auth, provider) {
            final next =
                provider ??
                ThemeProvider(
                  defaultThemeId: defaultAppThemeId,
                  themes: taiwanBrawlThemes,
                );
            next.syncForUser(auth.user?.id, themeMode: auth.user?.themeMode);
            return next;
          },
        ),
        ChangeNotifierProxyProvider<AuthService, UiSettingsProvider>(
          create: (_) => UiSettingsProvider(),
          update: (_, auth, provider) {
            final next = provider ?? UiSettingsProvider();
            next.syncForUser(
              auth.user?.id,
              fontScale: auth.user?.fontSizeScale,
            );
            return next;
          },
        ),
        ChangeNotifierProxyProvider<AuthService, TaiwanBrawlProfileService>(
          create: (context) =>
              TaiwanBrawlProfileService(context.read<AuthService>()),
          update: (_, auth, previous) =>
              previous ?? TaiwanBrawlProfileService(auth),
        ),
        ChangeNotifierProxyProvider<AuthService, LocaleProvider>(
          create: (_) => LocaleProvider(
            defaultLocale: defaultLocaleCode,
            translationResolver: translationForLocale,
          ),
          update: (_, auth, provider) {
            final next =
                provider ??
                LocaleProvider(
                  defaultLocale: defaultLocaleCode,
                  translationResolver: translationForLocale,
                );
            next.syncForUser(auth.user?.id, locale: auth.user?.locale);
            return next;
          },
        ),
      ],
      child: const MainApp(initialRoute: '/home'),
    ),
  );
}

GameResourceLibraryService _createGameResourceLibraryService(
  GameLibraryController controller,
  ApiClient apiClient,
) {
  final contentStore = HiveGameResourceContentStore();
  return GameResourceLibraryService(
    controller: controller,
    catalogSource: GameResourceCatalogSource(
      apiClient,
      trustedKeys: _trustedGameCatalogKeys(),
    ),
    resourceMigrations: gameResourceMigrations,
    contentStore: contentStore,
    // Release builds must inject publisher public keys through a reviewed,
    // versioned trust configuration. Unknown keys intentionally fail closed.
    installer: GameResourceInstaller(
      controller: controller,
      contentStore: contentStore,
      signatureVerifier: Ed25519GameResourceSignatureVerifier(
        _trustedGameResourceKeys(),
      ),
    ),
  );
}

Map<String, List<int>> _trustedGameResourceKeys() {
  const encoded = String.fromEnvironment(
    'GAME_RESOURCE_PUBLIC_KEYS',
    defaultValue: '{}',
  );
  try {
    final decoded = jsonDecode(encoded);
    if (decoded is! Map<String, dynamic>) return const {};
    return {
      for (final entry in decoded.entries)
        if (entry.value is String)
          entry.key: base64Url.decode(
            base64Url.normalize(entry.value as String),
          ),
    };
  } on Object {
    // Invalid deployment configuration leaves the trust set empty; the
    // installer then rejects every signer rather than weakening verification.
    return const {};
  }
}

Map<String, GameCatalogTrustKey> _trustedGameCatalogKeys() {
  const encoded = String.fromEnvironment(
    'GAME_CATALOG_TRUST_KEYS',
    defaultValue: '{}',
  );
  try {
    final decoded = jsonDecode(encoded);
    if (decoded is! Map<String, dynamic>) return const {};
    final keys = <String, GameCatalogTrustKey>{};
    for (final entry in decoded.entries) {
      if (entry.value is! Map) continue;
      final value = Map<String, dynamic>.from(entry.value as Map);
      if (value['publisher'] is! String || value['publicKey'] is! String) {
        continue;
      }
      final bytes = base64Url.decode(
        base64Url.normalize(value['publicKey'] as String),
      );
      if (bytes.length == 32) {
        keys[entry.key] = GameCatalogTrustKey(
          publisher: value['publisher'] as String,
          publicKey: bytes,
        );
      }
    }
    return Map.unmodifiable(keys);
  } on Object {
    // Invalid deployment configuration leaves the trust set empty.
    return const {};
  }
}

class MainApp extends StatelessWidget {
  const MainApp({super.key, this.initialRoute = '/'});

  final String initialRoute;

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, UiSettingsProvider>(
      builder: (context, themeProvider, uiSettings, child) {
        return MaterialApp(
          title: AppConstants.appName,
          initialRoute: initialRoute,
          navigatorObservers: [appRouteObserver],
          theme: themeProvider.lightTheme,
          darkTheme: themeProvider.darkTheme,
          themeMode: themeProvider.themeMode,
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(uiSettings.fontScale)),
              child: child!,
            );
          },
          routes: {
            '/': (_) => const SplashPage(),
            '/login': (_) => _DeferredWidget(
              loadLibrary: auth_page.loadLibrary,
              builder: (_) => auth_page.AuthPage(),
            ),
            '/home': (_) => const HomePage(),
            '/game-library': (_) => const GameLibraryPage(),
            '/profile': (_) => _DeferredWidget(
              loadLibrary: profile_page.loadLibrary,
              builder: (_) => profile_page.ProfilePage(),
            ),
            '/admin/cards': (_) => _DeferredWidget(
              loadLibrary: card_management.loadLibrary,
              builder: (_) => card_management.CardManagementPage(),
            ),
            '/admin/roles': (_) => _DeferredWidget(
              loadLibrary: role_management.loadLibrary,
              builder: (_) => role_management.RoleManagementPage(),
            ),
            ...gameModuleRoutes,
          },
        );
      },
    );
  }
}
