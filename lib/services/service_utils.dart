typedef JsonModelFactory<T> = T Function(Map<String, dynamic> json);

String buildApiPath(
  String path, {
  Map<String, Object?> queryParameters = const {},
}) {
  final filtered = <String, String>{};
  for (final entry in queryParameters.entries) {
    final value = entry.value;
    if (value == null) {
      continue;
    }
    final text = value.toString();
    if (text.isEmpty) {
      continue;
    }
    filtered[entry.key] = text;
  }

  if (filtered.isEmpty) {
    return path;
  }
  return Uri(path: path, queryParameters: filtered).toString();
}

Map<String, dynamic> requiredJsonMap(Map<String, dynamic> json, String key) {
  return json[key] as Map<String, dynamic>;
}

List<T> jsonModelList<T>(
  Map<String, dynamic> json,
  String key,
  JsonModelFactory<T> fromJson,
) {
  return (json[key] as List<dynamic>? ?? const <dynamic>[])
      .map((item) => fromJson(item as Map<String, dynamic>))
      .toList();
}

T jsonModel<T>(
  Map<String, dynamic> json,
  String key,
  JsonModelFactory<T> fromJson,
) {
  return fromJson(requiredJsonMap(json, key));
}

T? jsonNullableModel<T>(
  Map<String, dynamic> json,
  String key,
  JsonModelFactory<T> fromJson,
) {
  final value = json[key];
  if (value is Map<String, dynamic>) {
    return fromJson(value);
  }
  return null;
}
