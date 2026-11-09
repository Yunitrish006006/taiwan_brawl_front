# iPhone couple widget acceptance — 2026-11-09

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
global default remains opt-in until physical acceptance is confirmed. This is
development provisioning, not an App Store or TestFlight release.

## Backend prerequisite

The production couple API is active. Seventeen live friend/invite/accept/date/
end/block checks passed with isolated temporary accounts, which were removed.
The existing production web files remain verified. Physical iPhone sign-in,
binding, shared-container synchronization, widget colors/name/day rendering and
offline behavior still require observed device results.

## Current sign-in gate

The user reached Google sign-in but reported `Invalid Google token`. Backend
configuration was corrected to declare the App's existing Web/server OAuth
audience. That first correction alone did not establish successful sign-in;
credential-free server rejection-stage diagnostics are being used to identify
the remaining cause. Physical binding, App Group snapshot writes, widget display
and cold-start behavior remain pending until real sign-in succeeds.
