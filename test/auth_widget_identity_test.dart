import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl/services/auth_remote_source.dart';
import 'package:taiwan_brawl/services/auth_service.dart';
import 'package:taiwan_brawl/services/remote_source_exception.dart';

class IdentityRemote implements AuthRemoteSource {
  Object? failure;
  final pending = Completer<Map<String, dynamic>>();
  @override
  Future<Map<String, dynamic>> loadCurrentUser() async {
    if (failure != null) throw failure!;
    return pending.future;
  }

  @override
  Future<Map<String, dynamic>> logout() async => {'ok': true};
  @override
  Future<void> clearSession() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'offline unknown identity differs from authoritative session expiry',
    () async {
      final remote = IdentityRemote()
        ..failure = const RemoteSourceException('offline');
      final auth = AuthService(remoteSource: remote);
      await auth.init();
      expect(auth.identityState, AuthIdentityState.unresolved);
      remote.failure = const RemoteSourceException('expired', statusCode: 401);
      await auth.refreshMe();
      expect(auth.identityState, AuthIdentityState.signedOut);
      auth.dispose();
    },
  );
  test(
    'old successful identity response cannot resurrect a logged out account',
    () async {
      final remote = IdentityRemote();
      final auth = AuthService(remoteSource: remote);
      final request = auth.init();
      await Future<void>.delayed(Duration.zero);
      final logout = auth.logout();
      expect(auth.identityState, AuthIdentityState.signedOut);
      remote.pending.complete({
        'user': {'id': 1, 'name': 'Old'},
      });
      await request;
      await logout;
      expect(auth.user, isNull);
      expect(auth.identityState, AuthIdentityState.signedOut);
      auth.dispose();
    },
  );
}
