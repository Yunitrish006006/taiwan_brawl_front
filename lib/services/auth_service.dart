import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../config/app_configuration.dart';
import 'auth_remote_source.dart';
import 'service_utils.dart';
import 'remote_source_exception.dart';

enum AuthIdentityState { unresolved, authenticated, signedOut }

class AuthService extends ChangeNotifier {
  AuthService({
    required AuthRemoteSource remoteSource,
    AppConfiguration? configuration,
  }) : _remoteSource = remoteSource,
       _configuration = configuration ?? AppConfiguration.environment;

  final AuthRemoteSource _remoteSource;
  final AppConfiguration _configuration;
  AppUser? _user;
  bool _hasInitialized = false;
  int _identityEpoch = 0;
  int _identityReadSequence = 0;
  Future<void> _sessionQueue = Future.value();
  Future<void> _serializeSession(Future<void> Function() action) {
    final operation = _sessionQueue.then((_) => action());
    _sessionQueue = operation.catchError((Object _) {});
    return operation;
  }

  AuthIdentityState _identityState = AuthIdentityState.unresolved;
  AuthIdentityState get identityState => _identityState;

  Future<void> updateLocale(String locale) async {
    await _remoteSource.updateLocale(locale);
    await refreshMe(silent: true);
  }

  bool _isLoading = false;
  bool _isSigningIn = false;
  bool get isSigningIn => _isSigningIn;

  AppUser? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _user != null;
  bool get hasInitialized => _hasInitialized;

  AppUser _readUser(Map<String, dynamic> response) {
    return jsonModel(
      response,
      'user',
      (json) => AppUser.fromJson(json, configuration: _configuration),
    );
  }

  Future<void> _writeAndRefresh(
    Future<Map<String, dynamic>> Function() request,
  ) async {
    await request();
    await refreshMe(silent: true);
  }

  Future<void> init() async {
    await refreshMe(silent: true);
  }

  Future<void> refreshMe({bool silent = false}) async {
    final epoch = _identityEpoch, sequence = ++_identityReadSequence;
    _setLoading(!silent);
    await _serializeSession(() async {
      if (epoch != _identityEpoch || sequence != _identityReadSequence) return;
      try {
        final res = await _remoteSource.loadCurrentUser();
        if (epoch != _identityEpoch || sequence != _identityReadSequence) {
          return;
        }
        _user = _readUser(res);
        _identityState = AuthIdentityState.authenticated;
      } catch (error) {
        if (epoch != _identityEpoch || sequence != _identityReadSequence) {
          return;
        }
        _user = null;
        _identityState =
            error is RemoteSourceException && error.statusCode == 401
            ? AuthIdentityState.signedOut
            : AuthIdentityState.unresolved;
      } finally {
        if (epoch == _identityEpoch && sequence == _identityReadSequence) {
          _hasInitialized = true;
          _setLoading(false);
          notifyListeners();
        }
      }
    });
  }

  Future<void> verifyGoogleToken(String idToken) async {
    final epoch = ++_identityEpoch;
    _isSigningIn = true;
    _setLoading(true);
    await _serializeSession(() async {
      if (epoch != _identityEpoch) return;
      try {
        final res = await _remoteSource.verifyGoogleToken(idToken);
        if (epoch != _identityEpoch) return;
        _hasInitialized = true;
        _saveUser(res);
      } catch (_) {
        if (epoch == _identityEpoch) {
          _user = null;
          _identityState = AuthIdentityState.signedOut;
          _hasInitialized = true;
          notifyListeners();
          await _remoteSource.clearSession();
        }
        rethrow;
      } finally {
        if (epoch == _identityEpoch) {
          _isSigningIn = false;
          _setLoading(false);
        }
      }
    });
  }

  Future<void> updateProfile({
    required String name,
    required String bio,
    required String avatarSource,
    required String customAvatarUrl,
  }) async {
    await _writeAndRefresh(
      () => _remoteSource.updateProfile({
        'name': name,
        'bio': bio,
        'avatar_source': avatarSource,
        'custom_avatar_url': customAvatarUrl,
      }),
    );
  }

  Future<void> uploadAvatarImage({
    required String bytesBase64,
    required String contentType,
    String? fileName,
  }) async {
    await _writeAndRefresh(
      () => _remoteSource.uploadAvatarImage({
        'bytesBase64': bytesBase64,
        'contentType': contentType,
        'fileName': fileName,
      }),
    );
  }

  Future<void> deleteAvatarImage() async {
    await _writeAndRefresh(() => _remoteSource.deleteAvatarImage());
  }

  Future<void> updateThemeMode(String themeMode) async {
    await _writeAndRefresh(() => _remoteSource.updateThemeMode(themeMode));
  }

  Future<void> updateFontSizeScale(double scale) async {
    await _writeAndRefresh(() => _remoteSource.updateUiPreferences(scale));
  }

  Future<void> updateLlmBotSettings({
    required String baseUrl,
    required String model,
    String? apiKey,
  }) async {
    await _writeAndRefresh(
      () => _remoteSource.updateLlmBotSettings({
        'base_url': baseUrl,
        'model': model,
        'api_key': apiKey,
      }),
    );
  }

  Future<void> logout() async {
    ++_identityEpoch;
    _isSigningIn = false;
    _user = null;
    _identityState = AuthIdentityState.signedOut;
    _hasInitialized = true;
    _setLoading(false);
    await _serializeSession(() async {
      try {
        await _remoteSource.logout();
      } catch (_) {
        // Ignore API failures when logging out locally.
      }
      await _remoteSource.clearSession();
    });
  }

  void _saveUser(Map<String, dynamic> response) {
    _user = _readUser(response);
    _identityState = AuthIdentityState.authenticated;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
