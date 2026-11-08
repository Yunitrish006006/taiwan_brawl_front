import 'package:http/http.dart' as http;

/// Replays signed production-shaped resource URLs against the loopback-only
/// preview publisher. This adapter must never be used outside PREVIEW_MODE.
class PreviewGameResourceHttpClient extends http.BaseClient {
  PreviewGameResourceHttpClient({required this.apiBaseUrl, http.Client? client})
    : _client = client ?? http.Client();

  final String apiBaseUrl;
  final http.Client _client;

  static const _publisherHost = 'taiwan-brawl-api.yunitrish0419.workers.dev';
  static const _loopbackHosts = {'127.0.0.1', 'localhost', '::1'};

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final sourceUri = request.url;
    if (sourceUri.scheme != 'https' ||
        sourceUri.host != _publisherHost ||
        sourceUri.port != 443 ||
        !sourceUri.path.startsWith('/game-resources/')) {
      throw StateError(
        'Preview downloads must target the signed game resource API.',
      );
    }
    if (request.method != 'GET' && request.method != 'HEAD') {
      throw StateError('Preview game resource requests are read-only.');
    }

    final localOrigin = Uri.parse(apiBaseUrl);
    if ((localOrigin.scheme != 'http' && localOrigin.scheme != 'https') ||
        !_loopbackHosts.contains(localOrigin.host) ||
        localOrigin.userInfo.isNotEmpty ||
        localOrigin.path != '' && localOrigin.path != '/' ||
        localOrigin.hasQuery ||
        localOrigin.hasFragment) {
      throw StateError(
        'Preview resource API must use a plain loopback origin.',
      );
    }
    final targetUri = localOrigin.replace(
      path: sourceUri.path,
      query: sourceUri.hasQuery ? sourceUri.query : null,
      fragment: null,
    );
    final forwarded = http.Request(request.method, targetUri)
      ..headers.addAll(request.headers);
    return _client.send(forwarded);
  }

  @override
  void close() => _client.close();
}
