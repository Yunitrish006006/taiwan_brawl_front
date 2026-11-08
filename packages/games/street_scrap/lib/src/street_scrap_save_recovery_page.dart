import 'package:flutter/material.dart';

import 'street_scrap_progress.dart';
import 'street_scrap_localizations.dart';

class StreetScrapSaveRecoveryPage extends StatelessWidget {
  const StreetScrapSaveRecoveryPage({
    super.key,
    required this.report,
    required this.supportedRulesetVersion,
    this.canRestore = true,
    required this.onRestore,
  });

  final StreetScrapRecoveryReport report;
  final int supportedRulesetVersion;
  final bool canRestore;
  final Future<void> Function(StreetScrapRecoveryCandidate candidate) onRestore;

  @override
  Widget build(BuildContext context) {
    final strings = StreetScrapLocalizations.of(context);
    final backups = report.candidates.where(
      (candidate) => !candidate.isCurrent,
    );
    return Scaffold(
      appBar: AppBar(title: Text(strings.text('recovery.title'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.restore_page_outlined, size: 52),
          const SizedBox(height: 12),
          Text(
            report.currentSnapshotIsDamaged
                ? strings.text('recovery.damaged')
                : strings.text('recovery.healthy'),
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            strings.text('recovery.preserveNotice'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          if (!report.currentSnapshotIsDamaged)
            ListTile(
              leading: Icon(Icons.info_outline),
              title: Text(strings.text('recovery.healthyStatus')),
            ),
          if (report.currentSnapshotIsDamaged && !backups.isNotEmpty)
            ListTile(
              leading: Icon(Icons.error_outline),
              title: Text(strings.text('recovery.none')),
            ),
          for (final candidate in backups)
            Card(
              child: ListTile(
                leading: const Icon(Icons.history),
                title: Text(
                  strings.text(
                    'recovery.revision',
                    arguments: {'revision': '${candidate.snapshot.revision}'},
                  ),
                ),
                subtitle: Text(
                  '${strings.text('recovery.savedAt', arguments: {'time': '${candidate.snapshot.savedAt.toLocal()}'})}\n'
                  '${strings.text('recovery.ruleset', arguments: {'version': '${candidate.snapshot.rulesetVersion}', 'unsupported': candidate.snapshot.rulesetVersion == supportedRulesetVersion ? '' : strings.text('recovery.unsupported')})}',
                ),
                isThreeLine: true,
                trailing: FilledButton.tonal(
                  onPressed:
                      canRestore &&
                          report.currentSnapshotIsDamaged &&
                          candidate.snapshot.rulesetVersion ==
                              supportedRulesetVersion
                      ? () => _confirmRestore(context, candidate)
                      : null,
                  child: Text(strings.text('recovery.choose')),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmRestore(
    BuildContext context,
    StreetScrapRecoveryCandidate candidate,
  ) async {
    final strings = StreetScrapLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.text('recovery.confirmTitle')),
        content: Text(
          strings.text(
            'recovery.confirmBody',
            arguments: {
              'revision': '${candidate.snapshot.revision}',
              'time': '${candidate.snapshot.savedAt.toLocal()}',
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.text('recovery.reviewAgain')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(strings.text('recovery.restore')),
          ),
        ],
      ),
    );
    if (confirmed == true) await onRestore(candidate);
  }
}
