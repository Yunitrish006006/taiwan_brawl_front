import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl/game_modules/mini_royale/arena_localization_adapter.dart';
import 'package:taiwan_brawl/services/locale_provider.dart';

void main() {
  test('game localization adapter forwards locale, text, and changes', () {
    final provider = LocaleProvider(
      defaultLocale: 'en',
      translationResolver: (locale) => {
        'greeting': locale == 'ja' ? 'こんにちは' : 'Hello',
      },
    );
    final adapter = GameMiniRoyaleLocalizationAdapter(provider);
    var notifications = 0;
    adapter.addListener(() => notifications++);

    expect(adapter.locale, 'en');
    expect(adapter.text('greeting'), 'Hello');
    expect(adapter.text('missing key'), 'missing key');

    provider.setLocale('ja');

    expect(adapter.locale, 'ja');
    expect(adapter.text('greeting'), 'こんにちは');
    expect(notifications, 1);

    adapter.dispose();
    provider.setLocale('en');
    expect(notifications, 1);
    provider.dispose();
  });
}
