import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'constants/app_constants.dart';
import 'constants/locale_catalog.dart';
import 'constants/psn_theme.dart';
// 以下頁面只在第一次導航時才下載對應的 JS chunk
import 'pages/admin/card_management_page.dart' deferred as card_management;
import 'pages/admin/role_management_page.dart' deferred as role_management;
import 'pages/general/auth_page.dart' deferred as auth_page;
import 'pages/general/splash_page.dart';
import 'pages/home/home_page.dart';
import 'pages/profile/profile_page.dart' deferred as profile_page;
import 'pages/game/archery_game_page.dart' deferred as archery_page;
import 'pages/game/royale_deck_page.dart' deferred as royale_deck_page;
import 'pages/game/royale_lobby_page.dart' deferred as royale_lobby_page;
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/chat_service.dart';
import 'services/friends_overview_sync_service.dart';
import 'services/locale_provider.dart';
import 'services/notification_service.dart';
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
  await ChatService.initHive();
  final apiClient = ApiClient();
  final notificationService = NotificationService(apiClient);
  await notificationService.initialize();
  runApp(
    MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: apiClient),
        ChangeNotifierProvider(create: (_) => AuthService(apiClient)),
        ChangeNotifierProxyProvider<AuthService, NotificationService>(
          create: (_) => notificationService,
          update: (_, auth, service) {
            final nextService = service ?? notificationService;
            nextService.syncAuth(auth);
            return nextService;
          },
        ),
        ChangeNotifierProxyProvider<AuthService, FriendsOverviewSyncService>(
          create: (_) => FriendsOverviewSyncService(apiClient),
          update: (_, auth, friendsSyncService) {
            final service =
                friendsSyncService ?? FriendsOverviewSyncService(apiClient);
            service.syncAuth(auth);
            return service;
          },
        ),
        ChangeNotifierProxyProvider<AuthService, ThemeProvider>(
          create: (_) => ThemeProvider(),
          update: (_, auth, themeProvider) {
            final provider = themeProvider ?? ThemeProvider();
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

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, UiSettingsProvider>(
      builder: (context, themeProvider, uiSettings, child) {
        return MaterialApp(
          title: AppConstants.appName,
          navigatorObservers: [appRouteObserver],
          theme: PsnTheme.light(),
          darkTheme: PsnTheme.dark(),
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
            '/archery': (_) => _DeferredWidget(
              loadLibrary: archery_page.loadLibrary,
              builder: (_) => archery_page.ArcheryGamePage(),
            ),
            '/royale-deck': (_) => _DeferredWidget(
              loadLibrary: royale_deck_page.loadLibrary,
              builder: (_) => royale_deck_page.RoyaleDeckPage(),
            ),
            '/royale-lobby': (_) => _DeferredWidget(
              loadLibrary: royale_lobby_page.loadLibrary,
              builder: (_) => royale_lobby_page.RoyaleLobbyPage(),
            ),
          },
        );
      },
    );
  }
}
