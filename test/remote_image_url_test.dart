import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl/utils/remote_image_url.dart';

void main() {
  test('resolves relative image URLs against an injected API origin', () {
    expect(
      resolveRemoteImageUrl(
        '/assets/avatar.png',
        apiBaseUrl: 'https://images.example.test/v1',
      ),
      'https://images.example.test/assets/avatar.png',
    );
  });

  test('preserves absolute image URLs', () {
    expect(
      resolveRemoteImageUrl(
        'https://cdn.example.test/avatar.png',
        apiBaseUrl: 'https://api.example.test',
      ),
      'https://cdn.example.test/avatar.png',
    );
  });
}
