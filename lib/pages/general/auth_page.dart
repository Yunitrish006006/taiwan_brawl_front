import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_web/web_only.dart' as google_web;
import 'package:provider/provider.dart';

import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/locale_provider.dart';
import '../../constants/app_constants.dart';
import '../../utils/snackbar.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  StreamSubscription<GoogleSignInAuthenticationEvent>? _googleAuthSubscription;
  bool _isGoogleReady = !kIsWeb;
  bool _isGoogleSigningIn = false;
  String? _googleErrorMessage;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      unawaited(_initializeGoogleSignIn());
    }
  }

  @override
  void dispose() {
    _googleAuthSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeGoogleSignIn() async {
    final t = context.read<LocaleProvider>().translation;
    try {
      await _googleSignIn.initialize(
        clientId: AppConstants.googleWebClientId.isEmpty
            ? null
            : AppConstants.googleWebClientId,
      );

      _googleAuthSubscription = _googleSignIn.authenticationEvents.listen((
        event,
      ) {
        if (event is GoogleSignInAuthenticationEventSignIn) {
          unawaited(_handleGoogleAuthentication(event.user));
        }
      }, onError: _handleGoogleAuthenticationError);

      if (!mounted) return;
      setState(() {
        _isGoogleReady = true;
        _googleErrorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isGoogleReady = false;
        _googleErrorMessage =
            '${t.text('Google sign-in initialization failed')}: $e';
      });
    }
  }

  void _handleGoogleAuthenticationError(Object error) {
    final t = context.read<LocaleProvider>().translation;
    if (!mounted) return;
    setState(() {
      _isGoogleSigningIn = false;
    });
    showAppSnackBar(context, '${t.text('Google sign-in error')}: $error');
  }

  Future<void> _handleGoogleAuthentication(GoogleSignInAccount user) async {
    if (_isGoogleSigningIn || !mounted) {
      return;
    }

    final t = context.read<LocaleProvider>().translation;
    final auth = context.read<AuthService>();
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _isGoogleSigningIn = true;
    });

    try {
      final idToken = user.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              t.text('Google sign-in did not return a usable credential'),
            ),
          ),
        );
        return;
      }

      await auth.verifyGoogleToken(idToken);
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.message);
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, '${t.text('Google sign-in error')}: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleSigningIn = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().translation;
    final auth = context.watch<AuthService>();
    final loading = auth.isLoading || _isGoogleSigningIn;
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final frameWidth = (screenWidth < 600 ? screenWidth * 0.85 : 360.0)
        .clamp(220.0, 400.0)
        .toDouble();
    final isSmallScreen = screenWidth < 720;
    final brightness = theme.brightness;
    final googleButtonTheme = brightness == Brightness.dark
        ? google_web.GSIButtonTheme.filledBlack
        : google_web.GSIButtonTheme.outline;

    return Scaffold(
      appBar: AppBar(title: Text(AppConstants.appName)),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 12 : 20),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.text('Login Guide'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t.text(
                        'Taiwan Brawl Portal uses Google sign-in and keeps your session with a secure cookie.',
                      ),
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      t.text(
                        'Automatically restore your login state and personal preferences',
                      ),
                      style: theme.textTheme.bodyMedium,
                    ),
                    Text(
                      t.text('Verify the current session directly via /api/me'),
                      style: theme.textTheme.bodyMedium,
                    ),
                    Text(
                      t.text(
                        'Legacy username/password login and registration are no longer available',
                      ),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withValues(
                          alpha: 0.86,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.shadow.withValues(
                              alpha: 0.08,
                            ),
                            blurRadius: 28,
                            offset: const Offset(0, 14),
                          ),
                        ],
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.45,
                          ),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            t.text('Sign in with Google'),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            t.text(
                              'Sign in to continue to the portal and game pages.',
                            ),
                            style: theme.textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          if (!kIsWeb)
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: OutlinedButton.icon(
                                onPressed: null,
                                icon: const Icon(
                                  Icons.desktop_windows_outlined,
                                ),
                                label: Text(
                                  t.text(
                                    'Google sign-in is currently available on web only',
                                  ),
                                ),
                              ),
                            )
                          else if (_googleErrorMessage != null)
                            Column(
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: OutlinedButton.icon(
                                    onPressed: null,
                                    icon: const Icon(Icons.error_outline),
                                    label: Text(
                                      t.text(
                                        'Google sign-in is currently unavailable',
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _googleErrorMessage!,
                                  style: TextStyle(
                                    color: theme.colorScheme.error,
                                    fontSize: 13,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            )
                          else if (!_isGoogleReady)
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: OutlinedButton(
                                onPressed: null,
                                child: Text(
                                  t.text('Google sign-in is loading...'),
                                ),
                              ),
                            )
                          else
                            IgnorePointer(
                              ignoring: loading,
                              child: Opacity(
                                opacity: loading ? 0.7 : 1,
                                child: SizedBox(
                                  height: 56,
                                  child: Center(
                                    child: google_web.renderButton(
                                      configuration:
                                          google_web.GSIButtonConfiguration(
                                            theme: googleButtonTheme,
                                            text: google_web
                                                .GSIButtonText
                                                .signinWith,
                                            size:
                                                google_web.GSIButtonSize.large,
                                            shape: google_web
                                                .GSIButtonShape
                                                .rectangular,
                                            minimumWidth: frameWidth,
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          if (loading) ...[
                            const SizedBox(height: 12),
                            Text(
                              t.text('Verifying Google sign-in...'),
                              textAlign: TextAlign.center,
                            ),
                          ],
                          const SizedBox(height: 12),
                          Text(
                            t.text(
                              'Your session will be kept with a secure cookie after login',
                            ),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
