/// Resolves asset URLs against the API origin supplied by the host adapter.
/// With no injected origin the model remains portable and returns relative URLs.
String? resolveRemoteImageUrl(String? rawUrl, {String? apiBaseUrl}) {
  final normalized = rawUrl?.trim() ?? '';
  if (normalized.isEmpty) return null;

  final uri = Uri.tryParse(normalized);
  if (uri == null || uri.hasScheme || apiBaseUrl?.trim().isNotEmpty != true) {
    return normalized;
  }
  final origin = Uri.parse(
    apiBaseUrl!.trim(),
  ).replace(path: '/', query: null, fragment: null);
  return origin.resolveUri(uri).toString();
}
