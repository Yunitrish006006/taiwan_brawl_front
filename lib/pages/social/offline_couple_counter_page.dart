import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/offline_couple_counter_service.dart';
import '../../services/locale_provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/couples_text.dart';

class OfflineCoupleCounterEntry extends StatelessWidget {
  const OfflineCoupleCounterEntry({super.key});
  @override
  Widget build(BuildContext context) {
    context.watch<LocaleProvider?>();
    final service = context.watch<OfflineCoupleCounterService?>();
    final auth = context.watch<AuthService?>();
    if (service == null ||
        (auth != null &&
            (auth.identityState != AuthIdentityState.unresolved ||
                auth.isSigningIn)) ||
        !service.allowed ||
        (service.counter == null && !service.failed)) {
      return const SizedBox.shrink();
    }
    return TextButton.icon(
      icon: const Icon(Icons.favorite_outline),
      label: Text(couplesText(context, 'couples.offlineTitle')),
      onPressed: () => Navigator.pushNamed(context, '/couple-offline'),
    );
  }
}

class OfflineCoupleCounterPage extends StatefulWidget {
  const OfflineCoupleCounterPage({super.key});
  @override
  State<OfflineCoupleCounterPage> createState() =>
      _OfflineCoupleCounterPageState();
}

class _OfflineCoupleCounterPageState extends State<OfflineCoupleCounterPage> {
  OfflineCoupleCounterService? _service;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final service = context.read<OfflineCoupleCounterService?>();
    if (!identical(service, _service)) {
      _service?.setVisible(false);
      _service = service;
      _service?.setVisible(true);
    }
  }

  @override
  void dispose() {
    _service?.setVisible(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleProvider?>();
    final service = context.watch<OfflineCoupleCounterService?>();
    final auth = context.watch<AuthService?>();
    final eligible =
        auth == null ||
        (auth.identityState == AuthIdentityState.unresolved &&
            !auth.isSigningIn);
    final counter = service?.allowed == true && eligible
        ? service?.counter
        : null;
    return Scaffold(
      appBar: AppBar(title: Text(couplesText(context, 'couples.offlineTitle'))),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (counter != null) ...[
            Text(
              couplesText(context, 'couples.dayCount', {
                'days': '${service!.days}',
              }),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(couplesText(context, 'couples.offlineNotice')),
          ] else
            Text(
              couplesText(
                context,
                service?.failed == true
                    ? 'couples.offlineReadFailed'
                    : 'couples.offlineUnavailable',
              ),
            ),
          if (service?.allowed == true && eligible)
            TextButton(
              onPressed: () => service!.refresh(),
              child: Text(couplesText(context, 'couples.refresh')),
            ),
        ],
      ),
    );
  }
}
