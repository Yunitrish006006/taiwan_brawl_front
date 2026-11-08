import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:taiwan_brawl/services/preview_game_resource_http_client.dart';

class _RecordingClient extends http.BaseClient {
  Uri? requestedUri;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestedUri = request.url;
    return http.StreamedResponse(
      const Stream<List<int>>.empty(),
      200,
      request: request,
    );
  }
}

void main() {
  test('rewrites only signed publisher resource URLs to loopback', () async {
    final recorder = _RecordingClient();
    final client = PreviewGameResourceHttpClient(
      apiBaseUrl: 'http://127.0.0.1:8790',
      client: recorder,
    );

    final response = await client.get(
      Uri.parse(
        'https://taiwan-brawl-api.yunitrish0419.workers.dev/game-resources/street-scrap/game.street-scrap.content.chapters-0-4/0.1.22',
      ),
    );

    expect(response.statusCode, 200);
    expect(
      recorder.requestedUri,
      Uri.parse(
        'http://127.0.0.1:8790/game-resources/street-scrap/game.street-scrap.content.chapters-0-4/0.1.22',
      ),
    );
  });

  test(
    'refuses arbitrary HTTPS hosts and non-loopback fixture origins',
    () async {
      final client = PreviewGameResourceHttpClient(
        apiBaseUrl: 'http://127.0.0.1:8790',
        client: _RecordingClient(),
      );
      await expectLater(
        client.get(
          Uri.parse('https://attacker.invalid/game-resources/anything'),
        ),
        throwsStateError,
      );

      final invalidOriginClient = PreviewGameResourceHttpClient(
        apiBaseUrl: 'http://example.invalid',
        client: _RecordingClient(),
      );
      await expectLater(
        invalidOriginClient.get(
          Uri.parse(
            'https://taiwan-brawl-api.yunitrish0419.workers.dev/game-resources/street-scrap/id/1.0.0',
          ),
        ),
        throwsStateError,
      );
    },
  );
}
