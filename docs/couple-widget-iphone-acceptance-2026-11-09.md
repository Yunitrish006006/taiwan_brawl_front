# iPhone couple widget acceptance — 2026-11-09

Status: user-confirmed physical acceptance passed for the behaviors listed below.

Device: iPhone 11, iOS 27.0.1. Development environment: Xcode 27.2 and
CocoaPods 1.16.2. The user authorized Xcode installation and explicitly approved
Personal Team provisioning for Runner, CoupleDaysWidget and their existing App
Group. Account credentials, device identifiers, profiles and screenshots remain
outside version control.

## Build and signing evidence

- An initial native build exposed dependency deployment targets below Xcode's
  supported range. The Podfile now raises lower targets to the app's existing
  iOS 26 minimum, preserving any dependency with a higher minimum.
- Podfile.lock was regenerated for the plugins already pinned by pubspec.lock,
  including Firebase, connectivity, audio and secure storage.
- All six iOS project/deployment preflight checks passed.
- Unsigned Debug build with the iOS widget opt-in succeeded.
- Signed Debug build with the approved Personal Team succeeded.
- System signature verification passed outside the filesystem sandbox. Both
  signed Runner and the embedded extension include the shared
  `group.com.yunitrish.taiwanbrawl.coupledays` entitlement and provisioning.
- Device tooling confirmed the Debug App installed as version 0.132.0. A running
  UI was not inferred from installation: launch initially stalled on development
  service unlock/trust, and the user reported the untrusted-developer prompt.
- The user enabled Developer Mode and confirmed the developer trust setup.
  A signed Release test build completed (54.0 MB), installed successfully through
  device tooling and launched independently of the Flutter debugger. The user
  confirmed that the App opens. Its build, installation and launch are observed
  physical-device results, not just CI evidence.

The build uses `ENABLE_IOS_COUPLE_WIDGET=true` and the production API URL. The
global default remains opt-in; this tested build explicitly enables it. This is
development provisioning, not an App Store or TestFlight release.

## Backend prerequisite

The production couple API is active. Seventeen live friend/invite/accept/date/
end/block checks passed with isolated temporary accounts, which were removed.
The existing production web files remain verified. Real iPhone sign-in and
production couple binding were subsequently confirmed by the user.

## Resolved sign-in gate

The user reached Google sign-in but reported `Invalid Google token`. Backend
configuration was corrected to declare the App's existing Web/server OAuth
audience. That first correction alone did not establish successful sign-in;
credential-free server diagnostics identified an audience mismatch. The explicit
production allowlist now includes the existing Web/server and iOS OAuth clients.
Signature, issuer, expiry and verified-email checks remain enforced, and tokens
for unrelated clients remain rejected. The user confirmed successful sign-in.

## User-confirmed physical results

- Google sign-in succeeds on the installed iPhone App.
- After the other account accepted the production invitation, the App displayed
  the partner name and relationship day count.
- The home-screen couple widget displayed the correct partner name and count.
- Changing the widget color in the App updated the home-screen widget.
- Tapping the widget returned to the App successfully.

After additional offline testing exposed login/verification-only navigation,
both the bootstrap listener and widget gate were corrected to open the minimal
read-only counter when identity cannot be verified. After installing the second
corrected Release build, the user confirmed airplane mode with Wi-Fi disabled,
closing the App and tapping the home widget displays offline days.

These visible results were reported by the user; they are not inferred from
installation, simulator tests or App Group file listings. Physical midnight
rollover, extended offline operation and real-account/revocation cold-start races
remain NOT_EVALUATED in this device session. No disruptive end/block test was
performed on the user's real couple relationship.

## Second iPhone — 2026-11-10

A second physical iPhone running iOS 27.2 was paired with Developer Mode enabled.
Both Runner and CoupleDaysWidget provisioning profiles include the new device
and the shared App Group. A signed Release build completed, strict signature
verification passed and device tooling confirmed installation. The user then
trusted the developer and confirmed the App opens.

The build enables the iOS widget and connects to the production Cloudflare API.
The user confirmed Google sign-in, the correct existing partner name/day count,
the correct home-widget name/count and successful navigation back to the App
when tapping the widget. No new relationship or date change was needed.

These are user-confirmed physical results on the second phone. Color changes,
offline cold launch, midnight rollover and battery-saving behavior were not
separately verified on this second device. Private device/account identifiers
and provisioning profiles remain outside version control.
