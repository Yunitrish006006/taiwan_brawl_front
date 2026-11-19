import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taiwan_brawl/constants/app_constants.dart';
import 'package:taiwan_brawl/services/api_client.dart';
import 'package:taiwan_brawl/services/friends_service.dart';
import 'package:user_social_system/user_social_system.dart';

void main() {
  test(
    'host preserves friend endpoint and resolves relative avatar URLs',
    () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/friends/overview');
        return http.Response(
          jsonEncode({
            'friends': [
              {'userId': 7, 'name': 'Friend', 'avatarUrl': '/avatar.png'},
            ],
          }),
          200,
        );
      });
      final FriendsDirectory friends = FriendsService(
        ApiClient(client: client),
      );
      final overview = await friends.fetchOverview();
      expect(overview.friends.single.userId, 7);
      expect(
        overview.friends.single.avatarUrl,
        Uri.parse(AppConstants.apiBaseUrl).resolve('/avatar.png').toString(),
      );
    },
  );
}
