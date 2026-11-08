# CD-07: widget snapshot adapter and Android persistence

## Implemented locally

The eager `CoupleWidgetController` observes auth and couple service state through
the production composition root. On Android it writes a minimal snapshot over
`taiwan_brawl/couple_widget`. It does not write credentials, numeric account IDs,
names or photos. The account scope is 32 random bytes encoded as hex, persisted
in a separate per-account Hive mapping and stable across storage reopen.

The exported record contains only schemaVersion, accountScope,
sessionGeneration, requestSequence, relationshipId, relationshipVersion,
startedOn, status and lastSyncedAt. It has no expiry. A previously confirmed
active start date remains suitable for local calendar counting beyond 24 hours.
This is last-known relationship data, not an assertion of current server state.

Before selecting an account, native storage is cleared using a new generation;
then scope lookup and a scoped reservation happen. A failing scope lookup cannot
leave the old account's active record behind. The native generation is read from
persisted state and incremented, never derived from a Dart process counter.
Replacements require matching scope/generation and a strictly newer sequence.
Unknown keys, including credentials, malformed dates and uncleared empty states
are rejected by native code. The complete JSON record is saved with a checked
SharedPreferences `commit()` under a process-wide lock before returning success.
This protects the normal single-process host writer; it is not a cross-process
database transaction or proof against device storage failure.

Explicit logout, authoritative 401 and account switching clear or replace the
snapshot. Auth now exposes `unresolved`, `authenticated`, and `signedOut` solely
to distinguish offline uncertainty from confirmed logout. An unresolved cold
start preserves the previously confirmed native record, without authenticating
the user or loading another account's App UI cache. A request epoch prevents a
late old identity response from undoing an explicit logout. The existing App
offline cold start now has a separate [read-only counter](couple-offline-cold-start.md).
It does not select an account cache or restore authentication.

Controller writes are serialized and obsolete queued work is skipped. Native
validation remains necessary even when Dart has already checked its epoch.
Persistence failure is observable on the couple page in all three languages;
the next couple refresh can retry. A failed disk clear cannot be claimed to have
removed persisted data. No native plugin calls occur on unsupported platforms.

## Boundaries

- Android production snapshot storage is implemented and compiled.
- The debug CD-06 fixture widget intentionally remains separate; it still uses
  the sample date. CD-08 now implements the production reader, redraw requests
  and authenticated click routing; see [CD-08 evidence](couple-widget-cd08.md).
  Launcher rendering and real device acceptance remain unverified.
- iOS production bridge is **disabled by default**, not silently mapped to ordinary
  defaults. CD-09 now supplies source for shared storage, stale-write protection,
  native channels and a WidgetKit target. A registered App Group, native build
  and signatures have not been verified; see [CD-09 evidence](couple-widget-cd09.md).
- Web has no phone-home-widget channel and is intentionally disabled.
- No remote feature flags, database bindings, deployment or device installation
  were changed. Physical Android/iPhone widget flows remain NOT_EVALUATED.

## Evidence

- Full Flutter VM suite: 365 passed, 3 skipped; analyze passed.
- Controller tests: minimal fields, long-offline continuity, pending old write
  followed by logout, same-account new generation, switch during scope lookup,
  failed persistence/retry, unsupported platform behavior.
- Hive scope mapping: close/reopen stability and different accounts produce
  different opaque keys.
- Auth tests: offline uncertainty versus 401, late response after logout.
- Android JVM `CoupleWidgetStateTest`: 3 tests passed, independently rejecting
  old generations, sequences, wrong scopes, malformed dates, credentials and
  active data hidden inside empty states. These are pure state-machine tests,
  not physical SharedPreferences crash-recovery or widget-render tests.
- Android debug APK compiled with the native channel.

Reproduce using the project's Flutter toolchain and JDK 17:

```sh
flutter analyze
flutter test
flutter build apk --debug
cd android
./gradlew -Dorg.gradle.java.home="$JAVA_HOME" :app:testDebugUnitTest --tests com.yunitrish.taiwanbrawl.CoupleWidgetStateTest
```

CD-07 is partially verified across platforms: Dart and Android storage are
locally verified; iOS source and Foundation tests now exist, but its native build,
capabilities and real device tests remain open.
