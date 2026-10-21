import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl/services/game_resource_installer.dart';

void main() {
  test(
    'resource signer vector interoperates with the backend Node publisher',
    () async {
      final payload = Uint8List.fromList(utf8.encode('archery rules v1'));
      final verifier = Ed25519GameResourceSignatureVerifier({
        'resource-vector-1': base64Url.decode(
          base64Url.normalize('gTl3Dqh9F19Wo1Rmw0x-zMuNipG07jeiXfYPW4_Js5Q'),
        ),
      });
      expect(
        await verifier.verify(
          keyId: 'resource-vector-1',
          signature:
              '3ENhfo4pPn7NdOvL8PXt2953p_4Own4a8ntba6OaKxy5rVI5b-ATsF8kzkwYb0PjQrnEqWizH6hql9HnHrm6BA',
          moduleId: 'game.archery',
          resourceId: 'game.archery.rules',
          version: '1.0.0',
          sha256:
              '36c6e7d9dda24e3f06727a4ccc56fe522b85058e9f7b99ef406d9385ae72b46c',
          payload: payload,
        ),
        isTrue,
      );
    },
  );

  test(
    'Ed25519 verifies a signature bound to module, resource and version',
    () async {
      final payload = Uint8List.fromList(utf8.encode('archery rules v1'));
      final digest = sha256.convert(payload).toString();
      final algorithm = Ed25519();
      final keyPair = await algorithm.newKeyPair();
      final publicKey = await keyPair.extractPublicKey();
      final message =
          Ed25519GameResourceSignatureVerifier.canonicalSignedMessage(
            moduleId: 'game.archery',
            resourceId: 'game.archery.rules',
            version: '1.0.0',
            sha256: digest,
            payload: payload,
          );
      final signature = await algorithm.sign(message, keyPair: keyPair);
      final verifier = Ed25519GameResourceSignatureVerifier({
        'test-key': publicKey.bytes,
      });

      Future<bool> verify({
        String moduleId = 'game.archery',
        String resourceId = 'game.archery.rules',
        String version = '1.0.0',
        Uint8List? signedPayload,
        String? keyId,
      }) => verifier.verify(
        keyId: keyId ?? 'test-key',
        signature: base64UrlEncode(signature.bytes),
        moduleId: moduleId,
        resourceId: resourceId,
        version: version,
        sha256: digest,
        payload: signedPayload ?? payload,
      );

      expect(await verify(), isTrue);
      expect(await verify(moduleId: 'game.other'), isFalse);
      expect(await verify(version: '2.0.0'), isFalse);
      expect(
        await verify(
          signedPayload: Uint8List.fromList(utf8.encode('altered rules')),
        ),
        isFalse,
      );
      expect(await verify(keyId: 'revoked-or-unknown-key'), isFalse);
    },
  );
}
