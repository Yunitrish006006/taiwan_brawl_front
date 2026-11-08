# CD-08: Android production widget implementation

## Behavior implemented

`CoupleDaysWidgetProvider` is registered in the main Android manifest and included
in normal builds. It reads the private CD-07 snapshot, validates the envelope,
and shows only localized day count, "Please sign in", or "No partner linked".
Corrupt records never produce a count. Active records have no expiry and do not
require Flutter, a network request, or session credentials to calculate days.
Gregorian calendar fields are compared after UTC date normalization; current
system timezone is read on every update.

Confirmed native writes request redraw for all installed instances. The receiver
also refreshes on date/time/timezone/locale/reboot events and resizing. It uses a
single inexact local-midnight alarm, plus the system 30-minute periodic update as
fallback. Removing the last instance cancels the alarm. The private snapshot is
retained so adding the widget again can show the last known state. Multiple
instances share one current account and one record. Exact alarms, battery
exemptions and network polling were not added. OS restrictions may delay redraw;
neither midnight precision nor physical battery impact has been verified.

Resources include English/Japanese/Chinese labels, day/night colors and a
resizable small layout. Text size is bounded by available width and system font
scale, with two lines for empty states. Actual launcher appearance at all sizes,
accessibility settings and locales still requires visual QA.

Click PendingIntent is explicit and immutable; it carries no account or
relationship ID. Cold and warm launches use a separate native open-request
channel. Flutter waits for normal authentication bootstrap; if signed out it
opens login and retains the pending request. After login it opens the gate once.
The gate rechecks identity and fetches the current account's relationship. Offline
identity failure shows a retry page, not cached partner information. A changed
account is verified afresh; the old widget cannot authorize access to an old
relationship. The couple page includes Android widget-gallery instructions.

## Observed checks

- Android debug APK compiled successfully.
- Android JVM: 7 tests passed across `CoupleWidgetStateTest` (3) and
  `CoupleWidgetPresentationTest` (4), covering stale writes, minimal fields,
  corrupt/cleared states, offline continuity past 24 hours, current timezone,
  leap year, DST and year boundary.
- Flutter full VM suite: 368 passed, 3 skipped. Analyze passed.
- Navigation widget tests (3): offline gate never exposes cached days; a newly
  verified account replaces the previous relationship; pending native request
  waits for bootstrap/login and navigates once.
- The APK installed successfully on a read-only Pixel_10a emulator instance
  (API 37 image). The emulator initially showed its lock screen and then a black
  screen during attempts to access Launcher. `dumpsys appwidget` showed no
  providers/instances in that state. **Widget placement, visual rendering and
  click execution were not observed.** The instance was shut down after checks;
  its original AVD data was not wiped or saved over.

## Acceptance still open

Basic production-widget behavior has now been observed on a fresh API 35
emulator; see [isolated emulator acceptance](couple-widget-android-emulator-acceptance.md).
The earlier API 37 black-screen attempt above is historical. Full physical-device
and account-flow acceptance remains open. Remaining matrix: add/remove, multiple instances,
active/unbound/signed-out states, long offline operation, midnight, timezone
change, reboot/unlock, battery saver, resizing, light/dark, font scale and actual
click-to-login behavior. Test the full two-account API flow after the existing
database/feature cutover is approved and performed. No backend deployment,
remote flags or database data were changed here.

The CD-06 debug sample remains separately labeled and uses fixture data.
The production provider uses real snapshots; do not use the sample as evidence
for a live relationship. iOS source and Foundation tests are recorded in
[CD-09](couple-widget-cd09.md); native build, capabilities and signatures remain
unfinished CD-07/09 work.

Reproduce local checks with Flutter and JDK 17:

```sh
flutter analyze
flutter test
flutter build apk --debug
cd android
./gradlew -Dorg.gradle.java.home="$JAVA_HOME" :app:testDebugUnitTest --tests 'com.yunitrish.taiwanbrawl.CoupleWidget*Test'
```

Official scheduling reference:
[Android widget update mechanisms](https://developer.android.com/develop/ui/views/appwidgets/advanced).
