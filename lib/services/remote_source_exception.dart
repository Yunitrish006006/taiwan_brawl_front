/// Provider-neutral failure returned by a replaceable remote-source adapter.
class RemoteSourceException implements Exception {
  const RemoteSourceException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() =>
      'RemoteSourceException(statusCode: $statusCode, message: $message)';
}
