# Additional couple widget verification — 2026-11-09

## Results

| Check | Observed scope and result |
| --- | --- |
| iPhone offline cold launch | User confirmed airplane mode, Wi-Fi disabled, App closed, widget tapped: corrected build displays read-only offline days. Home widget retained its day count throughout. |
| Android native lifecycle | One integration test passed on a new disposable API 35 emulator using real Flutter MethodChannel and native persistence, with no mock channel and no backend account. |
| Native account isolation | Account A → B, logout, same-account relogin and unbound projection clear passed. Wrong scope, duplicate sequence and late previous-generation writes were rejected; display projection contains only schemaVersion, startedOn and lastSyncedAt. Palette survived logout. |
| Android midnight | A production home widget with a synthetic active snapshot displayed Day 9 at emulator time 2026-11-09 23:59:37 +0800 and Day 10 at 2026-11-10 00:00:22 +0800, without a manual refresh after midnight. Airplane mode was enabled and Wi-Fi disabled. |
| Flutter regression | 395 passed, 4 skipped; includes 23 targeted navigation, offline-counter and controller checks. |
| Frontend analysis | Passed after the final changes. |
| iPhone updated build | Signed Release build succeeded and installed while retaining App data. User subsequently confirmed the corrected offline behavior. |

The midnight observation advances only a disposable emulator's clock to just
before midnight, then lets it cross naturally. Production receiver, launcher
and Android scheduling/date broadcasts execute; this does not isolate alarm
delivery from DATE_CHANGED, prove an exact refresh deadline, or establish
physical-device battery/Doze behavior. Emulator time, timezone and preferences
were restored after the check. No real relationship was ended or modified.

## Corrected behavior

An unresolved identity after network failure may display the native minimal
counter directly from a widget tap, including when a previously verified route
loses connectivity during its next identity check. Successful identity reads
suspend this display; explicit logout, starting sign-in and authoritative 401
close it for the process and reject late reads. Account access and relationship
operations still require normal server authentication.

The repeatable native lifecycle test is
`integration_test/couple_widget_native_lifecycle_test.dart`. It requires explicit
`COUPLE_WIDGET_DISPOSABLE_TEST=true` and must run only on a disposable emulator
or simulator because it replaces native widget storage. Android CI now runs it
and the offline-navigation regressions. It is not an OAuth/end/logout API test;
the native state transitions stand in for those lifecycle events.

## Remaining evidence limits

- Physical iPhone midnight/WidgetKit timeline delivery and extended offline days.
- Physical Android/iPhone battery-saving behavior and OS scheduling budgets.
- Real-account logout/switch/revocation during offline cold launch; tested with
  native synthetic generations and Flutter regressions instead of disrupting
  the user's active relationship.
- No App Store or TestFlight publication was performed in this verification.
