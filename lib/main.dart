import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'constants/app_constants.dart';
import 'pages/admin/card_management_page.dart';
import 'pages/admin/role_management_page.dart';
import 'pages/general/auth_page.dart';
import 'pages/general/splash_page.dart';
import 'pages/home/home_page.dart';
import 'pages/profile/profile_page.dart';
import 'pages/game/archery_game_page.dart';
import 'pages/game/royale_deck_page.dart';
import 'pages/game/royale_lobby_page.dart';
import 'pages/social/friends_page.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/friends_overview_sync_service.dart';
import 'services/theme_provider.dart';
import 'services/ui_settings_provider.dart';
import 'services/locale_provider.dart';

final RouteObserver<PageRoute<dynamic>> appRouteObserver =
    RouteObserver<PageRoute<dynamic>>();

void main() {
  final apiClient = ApiClient();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService(apiClient)),
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
            provider.syncFromUser(auth.user);
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<AuthService, UiSettingsProvider>(
          create: (_) => UiSettingsProvider(),
          update: (_, auth, uiSettingsProvider) {
            final provider = uiSettingsProvider ?? UiSettingsProvider();
            provider.syncFromUser(auth.user);
            return provider;
          },
        ),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
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
          theme: ThemeData(
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF007A78),
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF007A78),
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
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
            '/friends': (_) => const FriendsPage(),
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
