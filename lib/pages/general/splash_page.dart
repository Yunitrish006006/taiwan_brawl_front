import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';

/// A first frame for the asynchronous composition-root bootstrap.
///
/// `main()` initializes local storage and preview/auth services before the
/// routed app exists. Rendering this shell immediately avoids a white window
/// during cold start; the fully configured app replaces it when ready.
class BootstrapLoadingApp extends StatelessWidget {
  const BootstrapLoadingApp({super.key, this.title = 'Taiwan Brawl'});

  final String title;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: title,
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(title),
            ],
          ),
        ),
      ),
    );
  }
}

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  static const Duration _restoreTimeout = Duration(seconds: 8);
  static const Duration _fallbackToLoginDelay = Duration(seconds: 10);

  Timer? _fallbackTimer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _fallbackTimer = Timer(_fallbackToLoginDelay, () {
      _navigateTo('/login');
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_bootstrap());
    });
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final auth = context.read<AuthService>();
    try {
      await auth.init().timeout(_restoreTimeout);
    } catch (error, stackTrace) {
      debugPrint('Splash bootstrap failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    if (!mounted || _navigated) {
      return;
    }
    _navigateTo(auth.isLoggedIn ? '/home' : '/login');
  }

  void _navigateTo(String routeName) {
    if (!mounted || _navigated) {
      return;
    }

    _navigated = true;
    _fallbackTimer?.cancel();
    Navigator.of(context).pushReplacementNamed(routeName);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
