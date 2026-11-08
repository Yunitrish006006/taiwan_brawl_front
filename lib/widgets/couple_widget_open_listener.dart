import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

/// A widget intent contains no account or relationship data. Wait until the
/// normal auth bootstrap settles, then open a route which verifies again.
class CoupleWidgetOpenListener extends StatefulWidget {
  const CoupleWidgetOpenListener({
    super.key,
    required this.navigatorKey,
    required this.child,
  });
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  @override
  State<CoupleWidgetOpenListener> createState() =>
      _CoupleWidgetOpenListenerState();
}

class _CoupleWidgetOpenListenerState extends State<CoupleWidgetOpenListener>
    with WidgetsBindingObserver {
  static const _channel = MethodChannel('taiwan_brawl/couple_widget_open');
  bool _pending = false, _scheduled = false, _loginShown = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'open') await _consume();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_consume()));
  }

  Future<void> _consume() async {
    try {
      final requested =
          await _channel.invokeMethod<bool>('consumeOpen') ?? false;
      if (!mounted) return;
      if (requested) {
        _pending = true;
        _loginShown = false;
      }
      _schedule();
    } on PlatformException {
      /* A later resume can retry. */
    } on MissingPluginException {
      /* Preview/test hosts may omit the native channel. */
    }
  }

  void _schedule() {
    if (_scheduled || !_pending || !mounted) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || !_pending) return;
      final auth = context.read<AuthService>();
      if (!auth.hasInitialized) return;
      final navigator = widget.navigatorKey.currentState;
      if (navigator == null) return;
      if (!auth.isLoggedIn) {
        if (!_loginShown) {
          _loginShown = true;
          navigator.pushNamedAndRemoveUntil('/login', (_) => false);
        }
      } else {
        _pending = false;
        navigator.pushNamed('/couple-widget');
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_consume());
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AuthService>();
    _schedule();
    return widget.child;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _channel.setMethodCallHandler(null);
    super.dispose();
  }
}
