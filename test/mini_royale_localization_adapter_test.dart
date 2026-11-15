import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl/game_modules/mini_royale/arena_localization_adapter.dart';
import 'package:taiwan_brawl/services/locale_provider.dart';

void main() {
  test('game localization adapter forwards locale, text, and changes', () {
    final provider = LocaleProvider(
      defaultLocale: 'en',
      translationResolver: (_) => const {},
    );
    final adapter = GameMiniRoyaleLocalizationAdapter(provider);
    var notifications = 0;
    adapter.addListener(() => notifications++);

    expect(adapter.locale, 'en');
    expect(adapter.text('Mini Royale Lobby'), 'Taiwan Brawl Lobby');
    expect(adapter.text('missing key'), 'missing key');

    provider.setLocale('ja');

    expect(adapter.locale, 'ja');
    expect(adapter.text('Mini Royale Lobby'), 'ゴーストアイランド乱闘 ルームロビー');
    expect(notifications, 1);

    adapter.dispose();
    provider.setLocale('en');
    expect(notifications, 1);
    provider.dispose();
  });
}
