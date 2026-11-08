# CD-09: iPhone bridge and WidgetKit implementation

## Implemented source

The Runner project now contains a `CoupleDaysWidget` app-extension target,
explicit Runner target dependency and an Embed Foundation Extensions phase
before Flutter's Thin Binary phase. The extension compiles only SwiftUI/WidgetKit
and the shared Foundation code; it does not link Runner's Flutter/CocoaPods
frameworks. Its version values come from Generated.xcconfig and match Runner.
The existing iOS 26 minimum and Google Sign-In URL callback are preserved.

Both targets declare the proposed shared group
`group.com.yunitrish.taiwanbrawl.coupledays`; the extension bundle is
`com.yunitrish.taiwanbrawl.CoupleDaysWidget`. These identifiers have not been
registered or verified with an Apple developer account by this work. A valid
development team and provisioning profiles remain required for device builds.

`CoupleWidgetPlugin` is registered with the implicit Flutter engine and exports
the same beginSession/replace/consumeOpen contract as Android. Host code is the
sole writer. It stores the entire validated snapshot as one atomically replaced
file in the App Group container, protected until first user authentication after
boot. It never falls back to ordinary defaults or private app storage when the
group is unavailable. Failure returns `WIDGET_WRITE_REJECTED` to Dart. A
process-wide lock serializes host instances; this is not cross-process writing
support or proof of crash/power-loss durability.

Persistent generation, opaque scope and strictly newer requestSequence are
checked before replacement. Unknown keys, Boolean/fractional counters, malformed
dates, invalid timestamps and uncleared empty states are rejected. Corrupt
existing state cannot silently reset generation. The record contains no token,
names, photos or expiry. The extension only reads it.

WidgetKit builds an immediate entry plus seven local-midnight entries and asks
for regeneration the following day. Entries contain dates only. The view reads
the latest complete record, then calculates Gregorian calendar days using the
current timezone. Missing/unreadable state shows sign-in; unbound shows the empty
relationship state. A read failure never falls back to an old active entry.
English, Japanese and Traditional Chinese strings and system light/dark styles
are supplied. The timeline horizon is not data expiry.

Confirmed writes and host foreground/significant time/timezone notifications
request a timeline reload. WidgetKit controls when reload and cached rendered
views are replaced. Immediate remote termination, exact midnight refresh and
timezone behavior while the host is not running are not guaranteed or verified.

The widget opens only `taiwanbrawl-widget://open`, with no account/relationship
arguments. The native plugin receives cold/warm scene callbacks and preserves a
pending open request until Flutter can consume it. Other URLs are left to normal
plugins. Dart uses the existing auth bootstrap and verification gate from CD-08;
native widget content is never an authorization source.

## Verification actually performed

- Shared store + App Group container helper compiled using macOS Foundation.
- **28 standalone Foundation checks passed**, including real temporary-file
  close/reopen, clear, same-account relogin, stale sequence/scope/generation
  rejection, unknown credential field rejection, Boolean/fraction rejection,
  invalid dates, long-offline counting, DST/leap year/date line, 20 concurrent
  host reservations, failed writes and corrupt-state handling. These tests use
  temporary files, not an entitled iOS App Group container.
- Swift syntax parse passed for AppDelegate, plugin, container and widget source.
  Parsing is not UIKit/Flutter/WidgetKit type checking.
- **6 project preflight checks passed**: dependency/embedding order, shared source
  membership, extension separation, all configuration entitlements, version
  parity, URL registration, localization and unchanged iOS deployment minimum.
  Plist/strings syntax checks passed. These are not an Xcode build.
- Flutter VM full suite: **369 passed, 3 skipped**; analyze passed.
- Opt-in Dart compile-path tests: **9 passed** for platform gating, snapshot
  controller and auth navigation with `ENABLE_IOS_COUPLE_WIDGET=true`. This
  enables a Dart constant in tests; it does not execute iOS native channels.

## Not yet verified / activation

Xcode remains unavailable in this environment. Runner + extension have **not
been compiled, archived or signed**. Actual Scene/Flutter registration, WidgetKit
rendering, App Group access, provisioning, extension embedding at runtime and
physical iPhone flows are **NOT_EVALUATED**. The existing Android Launcher
acceptance limitation also remains open. App offline cold start now has a separate
[read-only counter](couple-offline-cold-start.md), without restoring account access.

The Dart iOS bridge and native-open listener are opt-in:

```sh
flutter run --dart-define=ENABLE_IOS_COUPLE_WIDGET=true
```

Keep that option off until the native build/capabilities are verified. The flag
controls Dart synchronization/listening only: **it does not remove the extension
target or entitlements from Xcode builds**. Future iOS builds must configure the
new group's provisioning for both Runner and the extension, even with the Dart
flag off. No Apple portal registration, signing profile or deployment was done.

On a machine with Xcode, configure a valid team, register/verify both identifiers
and their shared App Group, then build Runner with the extension and test a
simulator/device. Use unsigned simulator builds as compile evidence only; they
cannot prove device provisioning. Verify actual add/remove, multiple instances,
active/unbound/signed-out, long offline, timezone/DST, reboot/first unlock,
logout/relogin/account switch, failed group access, large text, themes and
click-to-login navigation. CD-09 remains pending this native/device acceptance.

Reproduce the checks available without Xcode:

```sh
swiftc ios/CoupleWidgetShared/CoupleWidgetStore.swift ios/CoupleWidgetShared/CoupleWidgetContainer.swift ios/CoupleWidgetTests/main.swift -o /tmp/couple-widget-store-check
/tmp/couple-widget-store-check
node --test tool/couple_widget_ios_project.test.mjs tool/ios_deployment_target.test.mjs
flutter analyze
flutter test
flutter test --dart-define=ENABLE_IOS_COUPLE_WIDGET=true test/couple_widget_platform_test.dart test/couple_widget_navigation_test.dart test/couple_widget_controller_test.dart
```

References: [Apple App Groups](https://developer.apple.com/documentation/xcode/configuring-app-groups),
[WidgetKit scene linking](https://developer.apple.com/documentation/widgetkit/linking-to-specific-app-scenes-from-your-widget-or-live-activity),
[Flutter extension embedding dependency issue](https://github.com/flutter/flutter/issues/135056).
