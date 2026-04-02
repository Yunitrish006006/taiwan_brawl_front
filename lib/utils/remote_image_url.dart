import '../constants/app_constants.dart';

Uri _apiOriginUri() {
  final apiUri = Uri.parse(AppConstants.apiBaseUrl);
  return apiUri.replace(path: '/', query: null, fragment: null);
}

String? resolveRemoteImageUrl(String? rawUrl) {
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

  return _apiOriginUri().resolveUri(uri).toString();
}
