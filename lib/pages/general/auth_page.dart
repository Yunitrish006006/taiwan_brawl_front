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
        _googleErrorMessage = 'Google 登入初始化失敗: $e';
      });
    }
  }

  void _handleGoogleAuthenticationError(Object error) {
    if (!mounted) return;
    setState(() {
      _isGoogleSigningIn = false;
    });
    showAppSnackBar(context, 'Google 登入錯誤: $error');
  }

  Future<void> _handleGoogleAuthentication(GoogleSignInAccount user) async {
    if (_isGoogleSigningIn || !mounted) {
      return;
    }

    final auth = context.read<AuthService>();
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _isGoogleSigningIn = true;
    });

    try {
      final idToken = user.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Google 沒有回傳可用的登入憑證')),
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
      showAppSnackBar(context, 'Google 登入錯誤: $e');
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
                      t['登入說明'] ?? '登入說明',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t['Taiwan Brawl Portal 使用 Google 帳號登入，登入後會用安全 Cookie 維持 session。'] ??
                          'Taiwan Brawl Portal 使用 Google 帳號登入，登入後會用安全 Cookie 維持 session。',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      t['• 自動恢復登入狀態與個人偏好'] ?? '• 自動恢復登入狀態與個人偏好',
                      style: theme.textTheme.bodyMedium,
                    ),
                    Text(
                      t['• 直接使用 /api/me 驗證目前 session'] ??
                          '• 直接使用 /api/me 驗證目前 session',
                      style: theme.textTheme.bodyMedium,
                    ),
                    Text(
                      t['• 不再提供舊版帳密與註冊入口'] ?? '• 不再提供舊版帳密與註冊入口',
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
                            t['使用 Google 帳號登入'] ?? '使用 Google 帳號登入',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            t['登入後即可繼續使用首頁與遊戲頁面。'] ?? '登入後即可繼續使用首頁與遊戲頁面。',
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
                                  t['Google 登入目前先只支援網頁版'] ??
                                      'Google 登入目前先只支援網頁版',
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
                                      t['Google 登入目前無法使用'] ?? 'Google 登入目前無法使用',
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
                                  t['Google 登入載入中...'] ?? 'Google 登入載入中...',
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
                              t['正在驗證 Google 登入...'] ?? '正在驗證 Google 登入...',
                              textAlign: TextAlign.center,
                            ),
                          ],
                          const SizedBox(height: 12),
                          Text(
                            t['登入後會以安全 Cookie 維持 session'] ??
                                '登入後會以安全 Cookie 維持 session',
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
