# CD-06: couple days native samples

These samples use the fixed date **2026-11-01**. They do not read real accounts,
sessions, couple caches or network data. They are not the production widget.

## Observed validation

- Android debug APK compiled, including the AppWidget receiver and resources.
- Android merged manifest: minimum API 24, target API 36. No minimum OS upgrade.
- Android JVM: 3 tests passed, covering inclusive days, leap year, year boundary,
  DST transitions, date-line clamping and invalid dates.
- Swift Foundation calendar code compiled with Command Line Tools; 8 checks passed.
- iOS entitlement plist syntax passed `plutil -lint`.
- No connected Android device was available. Widget placement, reboot delivery,
  power-saving, large text, multi-instance behavior and launcher screenshots are
  **NOT_EVALUATED**. APK compilation is not launcher verification.
- Xcode and XcodeGen were unavailable. WidgetKit/SwiftUI sources and project
  specification are **NOT_COMPILED**. App Group registration, provisioning,
  extension embedding and physical iPhone behavior are **NOT_EVALUATED**.

## Android

`android/app/src/debug/` contains `CoupleDaysSpikeProvider` and resources. The
widget gallery label explicitly says sample. The widget itself shows only days.
The fixture is rebuilt locally whenever the provider updates; it has no expiry.
Its date arithmetic normalizes calendar fields before subtraction, so DST does
not turn a calendar day into 23/25 elapsed hours. Click opens the normal app;
authenticated couple-page routing belongs to CD-07/08.

With the project's Flutter SDK and JDK 17 configured:

```sh
flutter build apk --debug
cd android
./gradlew -Dorg.gradle.java.home="$JAVA_HOME" :app:testDebugUnitTest --tests com.yunitrish.taiwanbrawl.CoupleDaysSpikeCalendarTest
```

The provider is absent from main/release sources. The only dependency added to
the app build is test-scoped JUnit. After installing the debug APK, add
"Couple days — sample" from the launcher's widget gallery. Periodic refresh is
30 minutes; date/time/timezone/locale/reboot events also request redraw. Delivery
may be delayed by the system. No exact-alarm or battery exemption is requested.

## iPhone standalone sample

`ios/project.yml` describes a separate XcodeGen host app and WidgetKit extension.
It does not edit the production Runner project or claim a working signature.
The sample uses iOS 26, matching the current Runner deployment target; lowering
the production requirement is outside this sample.

When Xcode and XcodeGen are available:

```sh
cd native_spikes/couple_days/ios
xcodegen generate
xcodebuild -project CoupleDaysSpike.xcodeproj -scheme CoupleDaysSpike -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build
```

The generated project command is a reproduction instruction, not an observed
successful build. Before device installation, select a valid development team
and register the two bundle IDs and shared App Group from `project.yml` and
`Spike.entitlements` under that team. None have been registered by this task.
The host writes/clears a sample date; the extension reads it and builds seven
local-midnight entries, requesting regeneration the following day. This horizon
does not expire the underlying date. System scheduling remains subject to budget.
The sample URL opens the standalone host, not the authenticated production page.
Production timezone-change timeline behavior remains a device acceptance case.

The Foundation-only calculation can be checked without WidgetKit:

```sh
swiftc Shared/SpikeCalendar.swift Tests/main.swift -o /tmp/couple-days-calendar-check
/tmp/couple-days-calendar-check
```

## CD-07 bridge and storage decision

Use a native MethodChannel named `taiwan_brawl/couple_widget` (Web unsupported).
The following is the implementation contract. CD-07 now implements the Dart
adapter and Android writer; see [implementation evidence](../../docs/couple-widget-cd07.md).
CD-09 adds the iOS production writer source and target wiring, still disabled by
default pending native build/provisioning; see [iOS evidence](../../docs/couple-widget-cd09.md).
The samples below still use fixture data and are not production readers:

1. `beginSession({accountScope: opaqueLocalKeyOrNull})` atomically reserves a
   **native-persisted**, increasing generation and writes an empty snapshot
   before returning it. A Dart process restart must not reset this counter.
2. `replace({snapshot})` accepts schemaVersion 1, the exact current accountScope
   and sessionGeneration, and a strictly increasing requestSequence. It rejects
   late writes, including writes from a previous login of the same account.
3. Snapshot fields: schemaVersion, accountScope, sessionGeneration,
   requestSequence, relationshipId, relationshipVersion, startedOn, status,
   lastSyncedAt. Null/ended/signed-out states contain no old relationship/date.
   No credentials, names, photos, private messages, or expiry field are allowed.
4. Persist the complete envelope as one record, then request widget refresh.
   Failure must return to Dart; never report durable success before persistence.
   Extension/provider readers only read; the host is the sole writer.
5. Android: app-private SharedPreferences in the normal app process, serialized
   native writer. iOS: one record in a production App Group suite, serialized
   host writer; capability and both target entitlements must be verified first.
   The sample App Group is deliberately separate and cannot be treated as the
   production group. Widget extension does not receive session credentials.
6. Clear on logout/account change before publishing a new account. Clearing
   increments generation and invalidates pending Dart callbacks. An old timeline
   may remain visible until the OS honors reload; do not promise immediate repaint.

CD-07 owns Dart adaptation, actual bridge implementation, persistence/race tests
and authenticated navigation. CD-08/09 own the production widget, scheduling,
styling and device acceptance. CD-06 remains partially verified until the iOS
WidgetKit sample builds and both platforms are checked on devices.

Official references: [Android widget updates](https://developer.android.com/develop/ui/views/appwidgets/advanced),
[WidgetKit extension](https://developer.apple.com/documentation/widgetkit/creating-a-widget-extension),
[WidgetKit refresh](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date).
