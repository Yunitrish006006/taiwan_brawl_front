import 'package:test/test.dart';
import 'package:taiwan_brawl_messaging/taiwan_brawl_messaging.dart';

void main() {
  test('commands create sequential author-owned edits and recalls', () async {
    final repository = MessageRepository();
    final commands = MessageCommandService(
      repository: repository,
      actorId: 'alice',
      conversationId: '1:2',
      clock: () => DateTime.utc(2026, 10, 20, 1),
    );

    final created = await commands.create('hello', messageId: 'm1');
    final edited = await commands.edit('m1', 'edited');
    final read = await MessageCommandService(
      repository: repository,
      actorId: 'bob',
      conversationId: '1:2',
      clock: () => DateTime.utc(2026, 10, 20, 1, 1),
    ).read('m1');
    final recalled = await commands.recall('m1');

    expect(created.revision, 0);
    expect(edited?.revision, 1);
    expect(read?.revision, 2);
    expect(recalled?.revision, 3);
    expect(repository.projectionFor('m1')?.visibleBody, recalledMessageText);
    await repository.dispose();
  });

  test('commands reject edits by another actor', () async {
    final repository = MessageRepository();
    await MessageCommandService(
      repository: repository,
      actorId: 'alice',
      conversationId: '1:2',
    ).create('hello', messageId: 'm1');
    final result = await MessageCommandService(
      repository: repository,
      actorId: 'bob',
      conversationId: '1:2',
    ).edit('m1', 'tampered');

    expect(result, isNull);
    expect(repository.projectionFor('m1')?.visibleBody, 'hello');
    await repository.dispose();
  });

  test(
    'commands sign local events through the injected authenticator',
    () async {
      final repository = MessageRepository();
      final authenticator = _TestAuthenticator();
      final commands = MessageCommandService(
        repository: repository,
        actorId: 'alice',
        conversationId: '1:2',
        authenticator: authenticator,
      );

      final created = await commands.create('signed', messageId: 'signed-1');

      expect(created.signature, 'valid:${created.eventId}');
      expect(repository.pendingOutbox.single.signature, created.signature);
      await repository.dispose();
    },
  );
}

class _TestAuthenticator implements EventAuthenticator {
  @override
  Future<String> sign(MessageEvent event) async => 'valid:${event.eventId}';

  @override
  Future<bool> verify(MessageEvent event) async =>
      event.signature == 'valid:${event.eventId}';
}
