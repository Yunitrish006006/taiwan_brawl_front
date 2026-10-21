import '../config/app_configuration.dart';

Uri _apiOriginUri(String? apiBaseUrl) {
  final apiUri = Uri.parse(
    apiBaseUrl?.trim().isNotEmpty == true
        ? apiBaseUrl!.trim()
        : AppConfiguration.environment.apiBaseUrl,
  );
  return apiUri.replace(path: '/', query: null, fragment: null);
}

String? resolveRemoteImageUrl(String? rawUrl, {String? apiBaseUrl}) {
  final normalized = rawUrl?.trim() ?? '';
  if (normalized.isEmpty) {
    return null;
  }

  final uri = Uri.tryParse(normalized);
  if (uri == null) {
    return normalized;
  }
  if (uri.hasScheme) {
    return normalized;
  }

  return _apiOriginUri(apiBaseUrl).resolveUri(uri).toString();
}
