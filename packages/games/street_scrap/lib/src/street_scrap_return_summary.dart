import 'package:flutter/material.dart';

import 'street_scrap_localizations.dart';
import 'street_scrap_progress.dart';
import 'street_scrap_relief.dart';

/// A local, read-only resume summary. It never grants rewards or advances time.
class StreetScrapReturnSummary extends StatelessWidget {
  const StreetScrapReturnSummary({
    super.key,
    required this.snapshot,
    required this.maxStamina,
    required this.now,
  });

  final StreetScrapProgressSnapshot snapshot;
  final int maxStamina;
  final DateTime now;

  List<String> _highlights(StreetScrapLocalizations strings) {
    final state = snapshot.state;
    final highlights = <String>[];
    final chapter = state['chapter'];
    highlights.add(
      strings.text(
        'return.chapter',
        arguments: {'phase': '${chapter is int ? chapter : 0}'},
      ),
    );

    final craft = state['craftOperation'];
    if (craft is Map) {
      final answers = craft['answers'];
      highlights.add(
        strings.text(
          'return.craftPending',
          arguments: {'steps': '${answers is List ? answers.length : 0}'},
        ),
      );
    }
    final expedition = state['expedition'];
    if (expedition is Map && expedition['claimed'] != true) {
      final rewards = expedition['pendingRewards'];
      final visited = expedition['visited'];
      if (expedition['returned'] == true) {
        highlights.add(
          strings.text(
            'return.expeditionReturned',
            arguments: {'count': '${rewards is List ? rewards.length : 0}'},
          ),
        );
      } else {
        highlights.add(
          strings.text(
            'return.expeditionActive',
            arguments: {'count': '${visited is List ? visited.length : 0}'},
          ),
        );
      }
    }
    if (state['fishingPendingResult'] != null) {
      highlights.add(strings.text('return.fishingPending'));
    } else if (state['fishingActivity'] != null) {
      highlights.add(strings.text('return.fishingActive'));
    }

    final rawRelief = state['relief'];
    if (rawRelief is Map) {
      try {
        final relief = StreetScrapReliefProgress.fromJson(
          Map<String, Object?>.from(rawRelief),
        ).accrue(now);
        if (relief.visibleClaims > 0) {
          highlights.add(
            strings.text(
              'return.reliefAvailable',
              arguments: {'count': '${relief.visibleClaims}'},
            ),
          );
        }
      } on Object {
        highlights.add(strings.text('return.reliefMalformed'));
      }
    }

    final stamina = state['stamina'];
    if (stamina is int) {
      highlights.add(
        strings.text(
          'return.stamina',
          arguments: {'current': '$stamina', 'maximum': '$maxStamina'},
        ),
      );
    }
    return highlights;
  }

  @override
  Widget build(BuildContext context) {
    final strings = StreetScrapLocalizations.of(context);
    final highlights = _highlights(strings);
    final savedAt = snapshot.savedAt.toLocal();
    final materialLocalizations = MaterialLocalizations.of(context);
    final savedDate = materialLocalizations.formatMediumDate(savedAt);
    final savedTime = materialLocalizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(savedAt),
    );
    final savedAtLabel = '$savedDate $savedTime';
    return Card(
      key: const Key('street-scrap-return-summary'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.text('return.title'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              strings.text(
                'return.savedAt',
                arguments: {'time': savedAtLabel},
              ),
            ),
            const SizedBox(height: 8),
            for (final highlight in highlights)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('• $highlight'),
              ),
          ],
        ),
      ),
    );
  }
}
