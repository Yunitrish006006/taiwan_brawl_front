import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taiwan_brawl/game_modules/mini_royale_platform_adapters.dart';

void main() {
  test(
    'HTTP animation source normalizes successful and failed downloads',
    () async {
      final source = HttpBattleAnimationRemoteSource(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/ok.png')) {
            return http.Response.bytes(<int>[0, 1, 2], 200);
          }
          return http.Response('', 404);
        }),
      );

      expect(
        await source.download(Uri.parse('https://example.test/ok.png')),
        orderedEquals(<int>[0, 1, 2]),
      );
      expect(
        await source.download(Uri.parse('https://example.test/missing.png')),
        isNull,
      );
      source.dispose();
    },
  );
}
