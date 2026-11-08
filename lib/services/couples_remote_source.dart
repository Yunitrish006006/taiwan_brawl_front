import 'api_client.dart';

abstract interface class CouplesRemoteSource {
  Future<Map<String, dynamic>> overview({required int accountId});
  Future<Map<String, dynamic>> mutate(
    String path,
    Map<String, dynamic> body, {
    required int accountId,
  });
}

class ServerCouplesRemoteSource implements CouplesRemoteSource {
  const ServerCouplesRemoteSource(this.client);
  final ApiClient client;
  @override
  Future<Map<String, dynamic>> overview({required int accountId}) =>
      client.getJson(
        '/api/couples/overview',
        extraHeaders: {'X-Expected-Account-ID': '$accountId'},
      );
  @override
  Future<Map<String, dynamic>> mutate(
    String path,
    Map<String, dynamic> body, {
    required int accountId,
  }) {
    if (!RegExp(
      r'^/api/couples/(?:requests(?:/[0-9a-fA-F-]+/(?:accept|reject|cancel))?|date-proposals/[0-9a-fA-F-]+/(?:accept|reject|cancel)|[0-9a-fA-F-]+/(?:date-proposals|end))$',
    ).hasMatch(path)) {
      throw ArgumentError.value(path, 'path', 'Invalid couples route');
    }
    return client.postJson(
      path,
      body,
      extraHeaders: {'X-Expected-Account-ID': '$accountId'},
    );
  }
}
