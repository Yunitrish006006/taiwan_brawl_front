import 'package:flutter/foundation.dart';
import 'package:user_basic_system/user_basic_system.dart';

import '../models/app_user.dart';
import 'api_client.dart';
import 'auth_service.dart';

/// Bridges [AuthService] to the [ProfileService] interface
/// required by `user_basic_system`'s [ProfilePage].
///
/// Forwards all [AuthService] change notifications so the UI reacts
/// to login/logout and remote refreshes automatically.
class TaiwanBrawlProfileService extends ChangeNotifier
    implements ProfileService {
  TaiwanBrawlProfileService(this._auth) {
    _auth.addListener(_forward);
  }

  final AuthService _auth;

  void _forward() => notifyListeners();

  @override
  void dispose() {
    _auth.removeListener(_forward);
    super.dispose();
  }

  @override
  UserProfile? get profile {
    final u = _auth.user;
    if (u == null) return null;
    return _toProfile(u);
  }

  @override
  Future<void> updateProfile({
    required String name,
    required String bio,
    required String avatarSource,
    required String customAvatarUrl,
  }) async {
    try {
      await _auth.updateProfile(
        name: name,
        bio: bio,
        avatarSource: avatarSource,
        customAvatarUrl: customAvatarUrl,
      );
    } on ApiException catch (e) {
      throw UserSystemException(e.message);
    }
  }

  @override
  Future<void> uploadAvatarImage({
    required String bytesBase64,
    required String contentType,
    String? fileName,
  }) async {
    try {
      await _auth.uploadAvatarImage(
        bytesBase64: bytesBase64,
        contentType: contentType,
        fileName: fileName,
      );
    } on ApiException catch (e) {
      throw UserSystemException(e.message);
    }
  }

  @override
  Future<void> deleteAvatarImage() async {
    try {
      await _auth.deleteAvatarImage();
    } on ApiException catch (e) {
      throw UserSystemException(e.message);
    }
  }

  // ── mapping ────────────────────────────────────────────────────────────────

  static UserProfile _toProfile(AppUser u) => UserProfile(
    id: u.id,
    name: u.name,
    email: u.email,
    bio: u.bio,
    googleAvatarUrl: u.googleAvatarUrl,
    customAvatarUrl: u.customAvatarUrl,
    uploadedAvatarUrl: u.uploadedAvatarUrl,
    avatarSource: u.avatarSource ?? 'google',
  );
}
