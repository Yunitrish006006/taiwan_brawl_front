import 'street_scrap_localizations.dart';

/// Player-facing labels for versioned material traits.
///
/// Unknown IDs intentionally fall back to their canonical ID so content added
/// by a newer optional pack is never silently hidden by an older client.
class StreetScrapTraitPresentation {
  const StreetScrapTraitPresentation(this.name, this.effect);

  final String name;
  final String effect;

  static const _ids = {
    'joint_reinforced',
    'joint_skewed',
    'clear',
    'mineral_rich',
    'intact_fibre',
    'frayed',
    'cracked',
    'damp',
    'smooth_metal',
    'rusted',
    'sealed',
    'brittle',
    'even_pulp',
    'rich_ingredient',
    'rough_cut',
    'even_burn',
    'smoky',
  };

  static StreetScrapTraitPresentation forId(
    String id, {
    StreetScrapLocalizations? localizations,
  }) {
    final strings =
        localizations ?? const StreetScrapLocalizations('zh-Hant');
    if (!_ids.contains(id)) {
      return StreetScrapTraitPresentation(
        id,
        strings.text('trait.unknownEffect'),
      );
    }
    return StreetScrapTraitPresentation(
      strings.text('trait.$id.name'),
      strings.text('trait.$id.effect'),
    );
  }

  static List<MapEntry<String, StreetScrapTraitPresentation>> forTraits(
    Map<String, Object?> traits, {
    StreetScrapLocalizations? localizations,
  }) =>
      traits.entries
      .where((entry) => entry.value == true)
      .map(
        (entry) => MapEntry(
          entry.key,
          forId(entry.key, localizations: localizations),
        ),
      )
      .toList()
    ..sort((a, b) => a.key.compareTo(b.key));
}
