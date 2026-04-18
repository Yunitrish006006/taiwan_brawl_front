import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'constants/app_constants.dart';
import 'constants/locale_catalog.dart';
import 'constants/psn_theme.dart';
import 'pages/admin/card_management_page.dart';
import 'pages/admin/role_management_page.dart';
import 'pages/general/auth_page.dart';
import 'pages/general/splash_page.dart';
import 'pages/home/home_page.dart';
import 'pages/profile/profile_page.dart';
import 'pages/game/archery_game_page.dart';
import 'pages/game/royale_deck_page.dart';
import 'pages/game/royale_lobby_page.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/chat_service.dart';
import 'services/friends_overview_sync_service.dart';
import 'services/locale_provider.dart';
import 'services/notification_service.dart';
import 'services/theme_provider.dart';
import 'services/ui_settings_provider.dart';

final RouteObserver<PageRoute<dynamic>> appRouteObserver =
    RouteObserver<PageRoute<dynamic>>();

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
            '/login': (_) => const AuthPage(),
            '/home': (_) => const HomePage(),
            '/profile': (_) => const ProfilePage(),
            '/admin/cards': (_) => const CardManagementPage(),
            '/admin/roles': (_) => const RoleManagementPage(),
            '/archery': (_) => const ArcheryGamePage(),
            '/royale-deck': (_) => const RoyaleDeckPage(),
            '/royale-lobby': (_) => const RoyaleLobbyPage(),
          },
        );
      },
    );
  }
}
