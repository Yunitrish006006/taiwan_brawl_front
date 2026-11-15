import 'dart:convert';

import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

/// Stores conversation keys in the platform credential store.
///
/// A key is written only by a future authenticated P2P pairing flow. Missing
/// keys deliberately resolve to null, keeping relay unavailable until pairing
/// has actually completed.
class SecureConversationKeyStore implements ConversationKeyResolver {
  SecureConversationKeyStore({
    required CredentialStore credentials,
    this.keyPrefix = 'taiwan_brawl.conversation-key.',
  }) : _credentials = credentials;

  final CredentialStore _credentials;
  final String keyPrefix;

  Future<void> save({
    required String conversationId,
    required String keyId,
    required List<int> key,
  }) async {
    if (key.length != 32) {
      throw const FormatException('Conversation key must be 256 bits');
    }
    await _credentials.write(
      _storageKey(conversationId, keyId),
      base64UrlEncode(key),
    );
  }

  @override
  Future<List<int>?> resolve(String conversationId, String keyId) async {
    final encoded = await _credentials.read(_storageKey(conversationId, keyId));
    if (encoded == null) return null;
    try {
      final key = base64Url.decode(base64Url.normalize(encoded));
      return key.length == 32 ? key : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> delete({
    required String conversationId,
    required String keyId,
  }) => _credentials.delete(_storageKey(conversationId, keyId));

  String _storageKey(String conversationId, String keyId) {
    final conversation = base64UrlEncode(utf8.encode(conversationId));
    final key = base64UrlEncode(utf8.encode(keyId));
    return '$keyPrefix$conversation.$key';
  }
}
