import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/friends_models.dart';
import '../../services/couples_service.dart';
import '../../services/locale_provider.dart';
import '../../widgets/couples_text.dart';
import '../../services/device_time_zone.dart';
import '../../services/couple_widget_controller.dart';
import '../../services/couple_widget_bridge.dart';
import '../../widgets/couple_widget_appearance_picker.dart';

/// Couples are visible only through the current account's scoped service.
class CouplesPage extends StatefulWidget {
  const CouplesPage({super.key, required this.friends});
  final List<SocialUser> friends;
  @override
  State<CouplesPage> createState() => _CouplesPageState();
}

class _CouplesPageState extends State<CouplesPage> {
  bool _busy = false;
  String _text(String key, [Map<String, String> values = const {}]) =>
      couplesText(context, key, values);
  int? _openingAccount;
  bool _initialized = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _openingAccount = context.read<CouplesService>().accountId;
      _initialized = true;
    }
  }

  String? _error;
  final _operations = <String, String>{};
  final _draftDates = <String, DateTime>{};
  String _operation(String key) => _operations.putIfAbsent(key, () {
    final bytes = List.generate(16, (_) => Random.secure().nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  });
  String _name(int id) =>
      widget.friends.where((f) => f.userId == id).firstOrNull?.name ??
      _text('couples.friendName', {'id': '$id'});

  Future<void> _run(String key, Future<dynamic> Function(String) action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action(_operation(key));
      _operations.remove(key);
    } catch (_) {
      if (mounted) setState(() => _error = 'couples.failed');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(_text('couples.confirmTitle')),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(_text('couples.cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(_text('couples.confirm')),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _date(CouplesService service, {int? target}) async {
    final account = service.accountId;
    final relation = service.snapshot?.relationship;
    final draftKey = target == null
        ? 'relationship:${relation?.id}'
        : 'invite:$target';
    final today = DateUtils.dateOnly(DateTime.now());
    final draft =
        _draftDates[draftKey] ??
        (target == null && relation != null
            ? DateTime.parse(relation.startedOn)
            : today);
    final picked = await showDatePicker(
      context: context,
      initialDate: draft.isAfter(today) ? today : draft,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked == null || !mounted || service.accountId != account) return;
    _draftDates[draftKey] = picked;
    final zone = await _zone();
    if (zone == null || !mounted || service.accountId != account) return;
    final date =
        '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    if (target != null) {
      await _run(
        'invite:$target:$date:$zone',
        (op) => service.sendRequest(
          targetUserId: target,
          startedOn: date,
          timeZone: zone,
          operationId: op,
        ),
      );
    } else if (relation != null) {
      await _run(
        'date:${relation.id}:${relation.version}:$date:$zone',
        (op) => service.proposeDate(
          relation.id,
          startedOn: date,
          timeZone: zone,
          expectedVersion: relation.version,
          operationId: op,
        ),
      );
    }
  }

  Future<String?> _zone() async {
    try {
      return await deviceTimeZone();
    } catch (_) {
      if (mounted) setState(() => _error = 'couples.zoneFailed');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleProvider?>();
    final service = context.watch<CouplesService>();
    final widgetState = context.watch<CoupleWidgetController?>();
    if (service.accountId != _openingAccount) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(_text('couples.accountChanged'))),
      );
    }
    final data = service.snapshot;
    final relation = data?.relationship;
    final writable =
        !_busy &&
        data != null &&
        !service.isStale &&
        !service.lastRefreshFailed &&
        service.accountId != null;
    Widget button(String label, VoidCallback action) =>
        TextButton(onPressed: writable ? action : null, child: Text(label));
    return Scaffold(
      appBar: AppBar(title: Text(_text('couples.title'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_busy) const LinearProgressIndicator(),
          if (NativeCoupleWidgetBridge.supported &&
              defaultTargetPlatform == TargetPlatform.android)
            Text(_text('couples.widgetAddHelp')),
          if (NativeCoupleWidgetBridge.supported &&
              defaultTargetPlatform == TargetPlatform.iOS)
            Text(_text('couples.widgetAddHelpIos')),
          if (service.sessionExpired) Text(_text('couples.expired')),
          if (_error != null)
            Text(
              _text(_error!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (service.isStale || service.lastRefreshFailed)
            Text(_text('couples.stale')),
          if (service.cacheWriteFailed) Text(_text('couples.cacheFailed')),
          if (NativeCoupleWidgetBridge.supported)
            ExpansionTile(
              title: Text(_text('couples.appearance')),
              children: [
                CoupleWidgetAppearancePicker(
                  days: relation?.dayCount(DateTime.now()),
                  partnerName: relation?.partnerName,
                ),
              ],
            ),
          if (widgetState?.failed == true) Text(_text('couples.widgetFailed')),
          TextButton(
            onPressed: _busy
                ? null
                : () => _run('refresh', (_) => service.refresh()),
            child: Text(_text('couples.refresh')),
          ),
          if (data == null) Text(_text('couples.loading')),
          if (relation != null) ...[
            Text(
              _text('couples.withName', {
                'name': relation.partnerName ?? _name(relation.partnerUserId),
              }),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              _text('couples.dayCount', {
                'days': '${relation.dayCount(DateTime.now())}',
              }),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(_text('couples.firstDay', {'date': relation.startedOn})),
            Text(_text('couples.privacy')),
            button(_text('couples.propose'), () => _date(service)),
            button(_text('couples.end'), () async {
              final account = service.accountId;
              if (await _confirm(_text('couples.endConfirm')) &&
                  service.accountId == account) {
                await _run(
                  'end:${relation.id}',
                  (op) => service.endRelationship(relation.id, operationId: op),
                );
              }
            }),
          ] else if (data != null) ...[
            Text(_text('couples.inviteIntro')),
            for (final friend in widget.friends)
              ListTile(
                title: Text(friend.name),
                trailing: button(
                  _text('couples.invite'),
                  () => _date(service, target: friend.userId),
                ),
              ),
          ],
          if (data != null) ...[
            for (final request in data.incomingRequests)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _text('couples.incoming', {
                          'name': _name(request.requesterUserId),
                        }),
                      ),
                      Text(
                        _text('couples.firstDay', {'date': request.startedOn}),
                      ),
                      Wrap(
                        children: [
                          button(_text('couples.accept'), () async {
                            final account = service.accountId;
                            final zone = await _zone();
                            if (zone != null && service.accountId == account) {
                              await _run(
                                'accept:${request.id}:$zone',
                                (op) => service.acceptRequest(
                                  request.id,
                                  timeZone: zone,
                                  operationId: op,
                                ),
                              );
                            }
                          }),
                          button(
                            _text('couples.reject'),
                            () => _run(
                              'reject:${request.id}',
                              (op) => service.rejectRequest(
                                request.id,
                                operationId: op,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            for (final request in data.outgoingRequests)
              ListTile(
                title: Text(
                  _text('couples.outgoing', {
                    'name': _name(request.recipientUserId),
                  }),
                ),
                subtitle: Text(
                  _text('couples.inviteDate', {'date': request.startedOn}),
                ),
                trailing: button(
                  _text('couples.withdraw'),
                  () => _run(
                    'cancel:${request.id}',
                    (op) => service.cancelRequest(request.id, operationId: op),
                  ),
                ),
              ),
            if (data.dateProposal case final proposal?) ...[
              Text(_text('couples.pendingDate', {'date': proposal.startedOn})),
              if (proposal.requesterUserId == service.accountId)
                button(
                  _text('couples.withdrawDate'),
                  () => _run(
                    'cancel-date:${proposal.id}',
                    (op) => service.cancelDate(proposal.id, operationId: op),
                  ),
                )
              else
                Wrap(
                  children: [
                    button(_text('couples.acceptDate'), () async {
                      final account = service.accountId;
                      final zone = await _zone();
                      if (zone != null && service.accountId == account) {
                        await _run(
                          'accept-date:${proposal.id}:$zone',
                          (op) => service.acceptDate(
                            proposal.id,
                            timeZone: zone,
                            operationId: op,
                          ),
                        );
                      }
                    }),
                    button(
                      _text('couples.rejectDate'),
                      () => _run(
                        'reject-date:${proposal.id}',
                        (op) =>
                            service.rejectDate(proposal.id, operationId: op),
                      ),
                    ),
                  ],
                ),
            ],
          ],
        ],
      ),
    );
  }
}
