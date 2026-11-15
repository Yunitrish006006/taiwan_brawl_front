import 'package:taiwan_brawl_game_mini_royale/taiwan_brawl_game_mini_royale.dart'
    as mini_royale;

import '../../services/locale_provider.dart';

/// App adapter that exposes shared locale settings through the game-owned port.
class GameMiniRoyaleLocalizationAdapter
    extends mini_royale.MiniRoyaleLocalizationPort {
  GameMiniRoyaleLocalizationAdapter(this._localeProvider) {
    _localeProvider.addListener(_notifyChanged);
  }

  final LocaleProvider _localeProvider;

  @override
  String get locale => _localeProvider.locale;

  @override
  String text(String key) => mini_royale.MiniRoyaleLocalizations.fromLocale(
    _localeProvider.locale,
  ).text(key);

  void _notifyChanged() => notifyListeners();

  @override
  void dispose() {
    _localeProvider.removeListener(_notifyChanged);
    super.dispose();
  }
}
