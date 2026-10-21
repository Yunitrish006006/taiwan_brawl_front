import 'package:flutter_test/flutter_test.dart';
import 'package:taiwan_brawl/models/friends_models.dart';

void main() {
  test('friends profile images use the injected API origin', () {
    final overview = FriendsOverview.fromJson({
      'friends': [
        {
          'userId': 1,
          'name': 'Friend',
          'avatarUrl': '/user-avatars/1?v=2',
          'isOnline': true,
        },
      ],
    }, apiBaseUrl: 'https://api.example.test');

    expect(
      overview.friends.single.avatarUrl,
      'https://api.example.test/user-avatars/1?v=2',
    );
  });
}
