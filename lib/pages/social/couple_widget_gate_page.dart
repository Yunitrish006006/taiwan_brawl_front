import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/couples_service.dart';
import '../../services/locale_provider.dart';
import '../../widgets/couples_text.dart';
import 'couples_page.dart';

class CoupleWidgetGatePage extends StatefulWidget {
  const CoupleWidgetGatePage({super.key});
  @override
  State<CoupleWidgetGatePage> createState() => _CoupleWidgetGatePageState();
}

class _CoupleWidgetGatePageState extends State<CoupleWidgetGatePage> {
  bool _busy = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _verify());
  }

  Future<void> _verify() async {
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = context.read<AuthService>();
    final couples = context.read<CouplesService>();
    try {
      await auth.refreshMe();
      if (!mounted) return;
      final account = auth.user?.id;
      if (account == null) {
        setState(
          () => _error = auth.identityState == AuthIdentityState.signedOut
              ? 'couples.expired'
              : 'couples.widgetVerifyFailed',
        );
        return;
      }
      couples.setAccount(account);
      await couples.refresh();
      if (!mounted) return;
      if (auth.user?.id != account || couples.accountId != account) {
        setState(() => _error = 'couples.accountChanged');
        return;
      }
      // Resolve current relationship from the server; never route using an old
      // widget's account/relationship ID or show a cached previous identity.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const CouplesPage(friends: [])),
      );
    } catch (_) {
      if (mounted) setState(() => _error = 'couples.widgetVerifyFailed');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleProvider?>();
    return Scaffold(
      appBar: AppBar(title: Text(couplesText(context, 'couples.title'))),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_busy) const CircularProgressIndicator(),
              if (_error != null) Text(couplesText(context, _error!)),
              if (!_busy)
                TextButton(
                  onPressed: _verify,
                  child: Text(couplesText(context, 'couples.refresh')),
                ),
              if (!_busy && context.watch<AuthService>().user == null)
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                  child: Text(couplesText(context, 'couples.signIn')),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
