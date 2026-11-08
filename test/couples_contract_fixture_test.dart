@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taiwan_brawl/services/api_client.dart';
import 'package:taiwan_brawl/services/couples_remote_source.dart';
import 'package:taiwan_brawl/services/couples_service.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

class MemoryCredentials implements CredentialStore {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
}

class ContractRemote implements CouplesRemoteSource {
  ContractRemote(this.fixtures);
  final Map<String, dynamic> fixtures;
  String? path;
  Map<String, dynamic>? body;
  Map<String, dynamic> fixture(String id) => (fixtures['cases'] as List)
      .cast<Map<String, dynamic>>()
      .firstWhere((c) => c['id'] == id);
  @override
  Future<Map<String, dynamic>> overview({required int accountId}) async =>
      fixture('empty-overview')['expectedBody'] as Map<String, dynamic>;
  @override
  Future<Map<String, dynamic>> mutate(
    String path,
    Map<String, dynamic> body, {
    required int accountId,
  }) async {
    this.path = path;
    this.body = body;
    return fixture(
          path == '/api/couples/requests' ? 'create-request' : 'accept-request',
        )['expectedBody']
        as Map<String, dynamic>;
  }
}

void main() {
  test(
    'all typed operations send the documented endpoint and stable operation ID',
    () async {
      final fixtures =
          jsonDecode(
                File('test/fixtures/couple-days-v1.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      final remote = ContractRemote(fixtures);
      final request = remote.fixture(
        'create-request',
      )['expectedBody']['data']['request'];
      final relation = remote.fixture(
        'accept-request',
      )['expectedBody']['data']['relationship'];
      const requestId = '20000000-0000-4000-8000-000000000001',
          relationId = '30000000-0000-4000-8000-000000000001';
      const proposalId = '40000000-0000-4000-8000-000000000001';
      final operations = List.generate(
        9,
        (index) => '10000000-0000-4000-8000-00000000000${index + 1}',
      );
      final proposal = {
        'id': proposalId,
        'relationshipId': relationId,
        'requesterUserId': 101,
        'startedOn': '2026-10-01',
        'baseVersion': 1,
        'status': 'pending',
        'createdAt': '2026-11-04T04:00:00Z',
        'expiresAt': '2026-11-11T04:00:00Z',
      };
      final seen = <http.Request>[];
      final api = ApiClient(
        credentials: MemoryCredentials(),
        client: MockClient((r) async {
          expect(r.headers['X-Expected-Account-ID'], '101');
          if (r.method == 'GET') {
            return http.Response(
              jsonEncode(remote.fixture('empty-overview')['expectedBody']),
              200,
            );
          }
          seen.add(r);
          return http.Response(
            jsonEncode({
              'ok': true,
              'data': {
                'request': request,
                'relationship': relation,
                'proposal': proposal,
              },
              'serverNow': '2026-11-04T04:00:00Z',
            }),
            200,
          );
        }),
      );
      final service = CouplesService(ServerCouplesRemoteSource(api))
        ..setAccount(101);
      await service.sendRequest(
        targetUserId: 102,
        startedOn: '2026-11-01',
        timeZone: 'Asia/Taipei',
        operationId: operations[0],
      );
      await service.acceptRequest(
        requestId,
        timeZone: 'Asia/Taipei',
        operationId: operations[1],
      );
      await service.rejectRequest(requestId, operationId: operations[2]);
      await service.cancelRequest(requestId, operationId: operations[3]);
      await service.proposeDate(
        relationId,
        startedOn: '2026-10-01',
        timeZone: 'Asia/Taipei',
        expectedVersion: 1,
        operationId: operations[4],
      );
      await service.acceptDate(
        proposalId,
        timeZone: 'Asia/Taipei',
        operationId: operations[5],
      );
      await service.rejectDate(proposalId, operationId: operations[6]);
      await service.cancelDate(proposalId, operationId: operations[7]);
      await service.endRelationship(relationId, operationId: operations[8]);
      expect(seen.map((r) => r.url.path).toList(), [
        '/api/couples/requests',
        '/api/couples/requests/$requestId/accept',
        '/api/couples/requests/$requestId/reject',
        '/api/couples/requests/$requestId/cancel',
        '/api/couples/$relationId/date-proposals',
        '/api/couples/date-proposals/$proposalId/accept',
        '/api/couples/date-proposals/$proposalId/reject',
        '/api/couples/date-proposals/$proposalId/cancel',
        '/api/couples/$relationId/end',
      ]);
      for (var i = 0; i < seen.length; i++) {
        expect((jsonDecode(seen[i].body) as Map)['operationId'], operations[i]);
      }
      expect(jsonDecode(seen[4].body)['expectedVersion'], 1);
      service.dispose();
    },
  );
  test(
    'typed frontend methods consume the shared backend request and response examples',
    () async {
      final fixture =
          jsonDecode(
                File('test/fixtures/couple-days-v1.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      final remote = ContractRemote(fixture),
          service = CouplesService(remote)..setAccount(101);
      final create =
          remote.fixture('create-request')['request'] as Map<String, dynamic>;
      final createBody = create['body'] as Map<String, dynamic>;
      final request = await service.sendRequest(
        targetUserId: createBody['targetUserId'] as int,
        startedOn: createBody['startedOn'] as String,
        timeZone: createBody['timeZone'] as String,
        operationId: createBody['operationId'] as String,
      );
      expect(remote.path, create['path']);
      expect(remote.body, createBody);
      expect(request.recipientUserId, 102);
      final accept =
          remote.fixture('accept-request')['request'] as Map<String, dynamic>;
      final acceptBody = accept['body'] as Map<String, dynamic>;
      final relation = await service.acceptRequest(
        request.id,
        timeZone: acceptBody['timeZone'] as String,
        operationId: acceptBody['operationId'] as String,
      );
      expect(remote.path, accept['path']);
      expect(remote.body, acceptBody);
      expect(relation.partnerUserId, 101);
      service.dispose();
    },
  );
}
