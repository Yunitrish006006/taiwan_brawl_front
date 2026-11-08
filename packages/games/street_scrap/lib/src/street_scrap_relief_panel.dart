import 'package:flutter/material.dart';

import 'street_scrap_progress.dart';
import 'street_scrap_relief.dart';
import 'street_scrap_localizations.dart';

class StreetScrapReliefPanel extends StatefulWidget {
  const StreetScrapReliefPanel({
    super.key,
    required this.session,
    required this.maxStamina,
    required this.onChanged,
  });

  final StreetScrapSession session;
  final int maxStamina;
  final VoidCallback onChanged;

  @override
  State<StreetScrapReliefPanel> createState() => _StreetScrapReliefPanelState();
}

class _StreetScrapReliefPanelState extends State<StreetScrapReliefPanel> {
  bool _busy = false;
  String? _error;

  StreetScrapReliefProgress get _progress {
    final raw = widget.session.snapshot.state['relief'];
    final stored = raw == null
        ? StreetScrapReliefProgress.start(widget.session.snapshot.savedAt)
        : raw is Map
        ? StreetScrapReliefProgress.fromJson(Map<String, Object?>.from(raw))
        : throw const FormatException('Malformed Street Scrap relief state.');
    return stored.accrue(DateTime.now());
  }

  Future<void> _claim() async {
    final strings = StreetScrapLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await claimStreetScrapRelief(
        session: widget.session,
        commandId: 'relief-claim-${DateTime.now().microsecondsSinceEpoch}',
        expectedRevision: widget.session.snapshot.revision,
        now: DateTime.now(),
        maxStamina: widget.maxStamina,
      );
      if (!mounted) return;
      final data = Map<String, Object?>.from(result.result! as Map);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            strings.text(
              'relief.claimSuccess',
              arguments: {
                'restored': '${data['actualRestored']}',
                'count': '${data['reliefClaims']}',
              },
            ),
          ),
        ),
      );
      widget.onChanged();
    } on Object catch (error) {
      if (mounted) {
        setState(
          () => _error = switch (error) {
            StateError(:final message) when message == 'staminaFull' =>
              strings.text('relief.claimFull'),
            StateError(:final message) when message == 'noReliefClaims' =>
              strings.text('relief.noClaims'),
            _ => strings.text('relief.claimFailed'),
          },
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _claimChapterSupply() async {
    final strings = StreetScrapLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await claimStreetScrapChapterSupply(
        session: widget.session,
        commandId: 'chapter-supply-${DateTime.now().microsecondsSinceEpoch}',
        expectedRevision: widget.session.snapshot.revision,
        maxStamina: widget.maxStamina,
      );
      if (!mounted) return;
      final data = Map<String, Object?>.from(result.result! as Map);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            strings.text(
              'relief.supplySuccess',
              arguments: {
                'restored': '${data['actualRestored']}',
                'remaining': '${data['remainingSupply']}',
              },
            ),
          ),
        ),
      );
      widget.onChanged();
    } on Object catch (_) {
      if (mounted) setState(() => _error = strings.text('relief.supplyFailed'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finishReliefTransition() async {
    final strings = StreetScrapLocalizations.of(context);
    final acknowledged =
        widget.session.snapshot.state['reliefStopWarningAcknowledged'] == true;
    if (!acknowledged) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(strings.text('relief.stopTitle')),
          content: Text(strings.text('relief.stopBody')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(strings.text('relief.notNow')),
            ),
            FilledButton(
              key: const Key('street-scrap-confirm-relief-stop'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(strings.text('relief.confirmStop')),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!acknowledged) {
        await acknowledgeStreetScrapReliefStop(
          session: widget.session,
          commandId:
              'acknowledge-relief-stop-${DateTime.now().microsecondsSinceEpoch}',
          expectedRevision: widget.session.snapshot.revision,
        );
      }
      final result = await finishStreetScrapRelief(
        session: widget.session,
        commandId: 'finish-relief-${DateTime.now().microsecondsSinceEpoch}',
        expectedRevision: widget.session.snapshot.revision,
        now: DateTime.now(),
      );
      if (!mounted) return;
      final data = Map<String, Object?>.from(result.result! as Map);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            strings.text(
              'relief.stopSuccess',
              arguments: {
                'count': '${data['reliefClaims']}',
                'supply': '${data['chapterSupplyGranted']}',
              },
            ),
          ),
        ),
      );
      widget.onChanged();
    } on Object catch (_) {
      if (mounted) setState(() => _error = strings.text('relief.stopFailed'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = StreetScrapLocalizations.of(context);
    final progress = _progress;
    final stamina =
        widget.session.snapshot.state['stamina'] as int? ?? widget.maxStamina;
    final availableDetails = strings.text(
      progress.ended ? 'relief.ended' : 'relief.available',
      arguments: {
        'visible': '${progress.visibleClaims}',
        'reserve': progress.reserveClaims > 0
            ? strings.text(
                'relief.reserve',
                arguments: {'count': '${progress.reserveClaims}'},
              )
            : '',
        'amount': '$streetScrapReliefRestoreAmount',
        'count': '${progress.totalClaims}',
        'balance':
            '${widget.session.snapshot.state['chapterSupplyBalance'] ?? 0}',
      },
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.text('relief.title'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Semantics(
              key: const Key('street-scrap-relief-summary'),
              label: availableDetails,
              child: ExcludeSemantics(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _ReliefMetric(
                      key: const Key('street-scrap-relief-metric-visible'),
                      icon: Icons.lunch_dining_outlined,
                      value: '${progress.visibleClaims}',
                      tooltip: availableDetails,
                    ),
                    if (progress.reserveClaims > 0)
                      _ReliefMetric(
                        key: const Key('street-scrap-relief-metric-reserve'),
                        icon: Icons.inventory_2_outlined,
                        value: '+${progress.reserveClaims}',
                        tooltip: availableDetails,
                      ),
                    if (!progress.ended)
                      _ReliefMetric(
                        key: const Key('street-scrap-relief-metric-restore'),
                        icon: Icons.bolt_rounded,
                        value: '$streetScrapReliefRestoreAmount',
                        tooltip: availableDetails,
                      )
                    else
                      _ReliefMetric(
                        key: const Key('street-scrap-relief-metric-supply'),
                        icon: Icons.card_giftcard_outlined,
                        value:
                            '${widget.session.snapshot.state['chapterSupplyBalance'] ?? 0}',
                        tooltip: availableDetails,
                      ),
                    if (!progress.ended)
                      _ReliefMetric(
                        key: const Key('street-scrap-relief-metric-interval'),
                        icon: Icons.schedule_rounded,
                        value: '24h',
                        tooltip: availableDetails,
                      ),
                  ],
                ),
              ),
            ),
            if (progress.ended) ...[
              const SizedBox(height: 4),
              Semantics(
                label: availableDetails,
                child: ExcludeSemantics(
                  child: Chip(
                    avatar: const Icon(Icons.pause_circle_outline_rounded),
                    label: Text(strings.text('relief.endedShort')),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ] else if ((widget.session.snapshot.state['chapter'] as int? ??
                        0) >=
                    4 &&
                (widget.session.snapshot.state['tutorialTasks']
                        as Map?)?['q5.02'] !=
                    true)
              Semantics(
                label: strings.text('relief.stopWillHappen'),
                child: Tooltip(
                  message: strings.text('relief.stopWillHappen'),
                  child: Chip(
                    avatar: const Icon(Icons.info_outline_rounded),
                    label: Text(strings.text('relief.stopWillHappenShort')),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            if (!progress.ended &&
                (widget.session.snapshot.state['chapter'] as int? ?? 0) >= 5 &&
                (widget.session.snapshot.state['tutorialTasks']
                        as Map?)?['q5.02'] ==
                    true) ...[
              const SizedBox(height: 6),
              Semantics(
                label: strings.text('relief.stopPrompt'),
                child: Tooltip(
                  message: strings.text('relief.stopPrompt'),
                  child: Chip(
                    avatar: const Icon(Icons.home_work_outlined),
                    label: Text(strings.text('relief.stopPromptShort')),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  key: const Key('street-scrap-finish-relief-transition'),
                  onPressed: _busy || widget.session.isReadOnly
                      ? null
                      : _finishReliefTransition,
                  label: Text(
                    _busy
                        ? strings.text('relief.processing')
                        : widget
                                  .session
                                  .snapshot
                                  .state['reliefStopWarningAcknowledged'] ==
                              true
                        ? strings.text('relief.finishAndClaim')
                        : strings.text('relief.reviewOptions'),
                  ),
                  icon: const Icon(Icons.home_work_outlined),
                ),
              ),
            ],
            if (progress.clockRollbackEvents > 0)
              Text(
                strings.text(
                  'relief.rollback',
                  arguments: {'count': '${progress.clockRollbackEvents}'},
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (_error != null) ...[
              const SizedBox(height: 4),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed:
                    _busy ||
                        widget.session.isReadOnly ||
                        widget.session.snapshot.state['relief'] == null ||
                        stamina >= widget.maxStamina ||
                        progress.totalClaims == 0
                    ? null
                    : _claim,
                label: Text(
                  _busy
                      ? strings.text('relief.claiming')
                      : progress.ended
                      ? strings.text('relief.claimReserved')
                      : strings.text('relief.claim'),
                ),
                icon: const Icon(Icons.lunch_dining_outlined),
              ),
            ),
            if (progress.ended &&
                (widget.session.snapshot.state['chapterSupplyBalance']
                            as int? ??
                        0) >
                    0)
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed:
                      _busy ||
                          widget.session.isReadOnly ||
                          stamina >= widget.maxStamina
                      ? null
                      : _claimChapterSupply,
                  label: Text(strings.text('relief.claimSupply')),
                  icon: const Icon(Icons.card_giftcard_outlined),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReliefMetric extends StatelessWidget {
  const _ReliefMetric({
    super.key,
    required this.icon,
    required this.value,
    required this.tooltip,
  });

  final IconData icon;
  final String value;
  final String tooltip;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Chip(
      avatar: Icon(icon),
      label: Text(value),
      visualDensity: VisualDensity.compact,
    ),
  );
}
