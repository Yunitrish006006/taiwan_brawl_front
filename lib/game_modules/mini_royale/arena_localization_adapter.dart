import 'package:taiwan_brawl_game_mini_royale/taiwan_brawl_game_mini_royale.dart';

import '../../services/locale_provider.dart';

/// App adapter that exposes shared locale settings through the game-owned port.
class GameMiniRoyaleLocalizationAdapter extends MiniRoyaleLocalizationPort {
  GameMiniRoyaleLocalizationAdapter(this._localeProvider) {
    _localeProvider.addListener(_notifyChanged);
  }

  final LocaleProvider _localeProvider;

  @override
  String get locale => _localeProvider.locale;

  @override
  String text(String key) => _localeProvider.translation.text(key);

  void _notifyChanged() => notifyListeners();

  @override
  void dispose() {
    _localeProvider.removeListener(_notifyChanged);
    super.dispose();
  }
}
