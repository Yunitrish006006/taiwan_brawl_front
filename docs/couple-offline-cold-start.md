# App offline cold-start counter

The login page offers a read-only day-count entry when a previously confirmed
native snapshot exists and current identity is unresolved. The screen shows only
days and a last-confirmed-data notice. It does not select an account cache,
authenticate a user, or expose invitation/date-change/ending actions.

`readCounter` on the native widget channel projects exactly schemaVersion,
startedOn and lastSyncedAt after validating the stored record. It exports no
account scope, relationship ID, credentials, names or photos. Cleared, corrupt
or unreadable records produce no usable display. No old value is reused after
a read failure. Android and the gated iOS implementation share this behavior.

`OfflineCoupleCounterService` permits only an initial unresolved-identity window.
Successful verification, authoritative 401, explicit logout or starting sign-in
permanently closes that window for the current App process. Generation checks
reject delayed reads. A failed sign-in followed by offline refresh cannot reopen
the old data. Entry and page also directly watch auth to hide days without
waiting for a deferred service notification. AuthService now exposes sign-in
intent, and the widget controller clears its old selection during sign-in.

This is the same display information already available from the home widget,
not offline account login. Protected App views continue to require normal auth.
Web has no native projection. iOS remains opt-in pending Xcode, App Group and
signing verification. A failed disk clear cannot be claimed successful; native
crash/power-loss durability and immediate OS repaint are not proved here.

Days derive from the saved Gregorian date and current local date, inclusive of
the first day, with no expiry. While visible the page updates once a minute;
backgrounding stops the timer and resume re-reads storage. Current timezone and
system clock affect the next render. Offline remote termination remains unknown
until synchronization, as specified for the home widget.

Counter/widget tests cover 31-day calendar advance, invalid dates/identity fields,
logout/401, delayed reads during sign-in, failed sign-in not reopening access,
private-read failure, native projection method use, login entry/navigation,
large text, local-day change, and background/resume. The local HTTP/D1 harness
also passes real server data through a Dart bridge test double to the read-only
service without restoring authentication. Android and Swift tests independently
check minimal and cleared projections. These do not replace phone acceptance.

Actual Android cold-start UI and both platforms' phone/launcher flows remain
unverified. iOS channel/WidgetKit code still needs an actual Xcode build and
App Group/provisioning verification before enabling the iOS flag.
