# taiwan_brawl_messaging

Transport-neutral messaging primitives for the Taiwan Brawl repository family.

This package is deliberately independent from Flutter, Hive, Cloudflare,
Firebase, WebRTC, and any particular encryption implementation. It defines the
event and projection boundary that those adapters will implement.

The first event model supports:

- local creation while offline;
- deterministic per-message revisions;
- edits after delivery;
- recalls after read, projected as `訊息已收回`;
- idempotent event ingestion;
- an outbox for transports such as WebRTC and server synchronization.
- an optional durable inbox for received events during verification and
  projection.

Remote ingestion rejects events that are provably invalid (for example, an
edit by a non-author), records a conflict, and leaves the projection intact.
Valid events that arrive with a revision gap are staged until the missing
revision arrives, which keeps unreliable transport ordering separate from
actual data conflicts.

`MessageCommandService` is the shared application command layer for creating,
editing, recalling, and reading messages. It centralizes author checks and
revision sequencing so product-specific services do not duplicate event rules.

Cryptographic signing is represented by an interface boundary. A production
adapter must provide signing and verification before events are accepted from an
untrusted peer.

`CredentialStore` and `DeviceIdentity` are also ports. They keep session tokens,
device keys, and other secrets out of feature code; platform packages provide
the secure-storage implementation.

`CredentialBackedDeviceIdentityDirectory` is an explicit trust-store adapter
for peer verification. It persists opaque, application-defined trust material,
supports revocation, and resolves identities only after the application supplies
a decoder. It is not created by default; products must define how a peer key is
authenticated before enabling remote verification.

`MessageEventStore` is the durable-storage port. The current repository uses an
in-memory implementation for deterministic tests; a production app must supply
an encrypted local adapter and restore events before exposing a conversation.
Stores may also implement `MessageConflictStore` to persist rejected-event
reasons across restarts. This capability is optional for source compatibility,
but the Flutter Hive adapter implements it so invalid or conflicting events do
not disappear when the app is restarted.

Stores may additionally implement `MessageInboxStore`. Remote events are
placed there before verification and projection, then removed only after the
receive operation completes. An interrupted receive can therefore be replayed
after restart without making a transport responsible for database recovery.

`EncryptionKeyProvider` is the boundary for obtaining the key used by that
adapter. The package intentionally does not choose a platform keychain or
invent a fallback key.

`PeerSignaling` is intentionally separate from `MessageTransport`: it only
exchanges WebRTC negotiation data. Message bodies must travel over the resulting
transport or through an explicit server synchronization adapter.

`PushProvider` and its provider-neutral permission, token, message, and
configuration types are shared here as well. FCM is only one frontend adapter;
application services do not need to depend on Firebase Messaging directly.

`PeerNegotiationBundle` provides a versioned JSON boundary for manual or QR
signaling. Its validator accepts only offer, answer, and ICE candidate payloads;
message events cannot be carried through that channel.
