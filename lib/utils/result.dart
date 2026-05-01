import 'package:taiwan_brawl/utils/app_error.dart' show AppError;
import 'package:taiwan_brawl/services/api_client.dart' show ApiException;

/// Result type for operations that can fail
sealed class Result<T> {
  const Result();
}

class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

class Err<T> extends Result<T> {
  const Err(this.error);
  final AppError error;
}

extension ResultExtension<T> on Result<T> {
  bool get isOk => this is Ok<T>;
  bool get isErr => this is Err<T>;
  T? get value => this is Ok<T> ? (this as Ok<T>).value : null;
  AppError? get error => this is Err<T> ? (this as Err<T>).error : null;

  T getOrThrow() => switch (this) {
    Ok(value: final v) => v,
    Err(error: final e) => throw e,
  };

  T getOrElse(T defaultValue) => switch (this) {
    Ok(value: final v) => v,
    Err() => defaultValue,
  };
}

Future<Result<T>> asyncResult<T>(Future<T> Function() operation) async {
  try {
    return Ok(await operation());
  } on ApiException catch (e, st) {
    return Err(AppError.fromApiException(e, st: st));
  } catch (e, st) {
    return Err(AppError.generic(e, st: st));
  }
}
