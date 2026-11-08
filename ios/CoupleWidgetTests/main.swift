import Foundation

var checks = 0
func check(_ condition: Bool, _ message: String) {
    precondition(condition, message); checks += 1
}
func rejects(_ operation: () throws -> Void) {
    do { try operation(); preconditionFailure("Invalid operation was accepted") }
    catch { checks += 1 }
}
let directory = FileManager.default.temporaryDirectory.appendingPathComponent("couple-widget-tests-" + UUID().uuidString)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: directory) }
let file = directory.appendingPathComponent("snapshot.json")
let store = CoupleWidgetStore(file: file)
let scope = String(repeating: "a", count: 64)
let generation = try store.begin(scope: scope)
check(generation == 1, "First generation")
let emptyData = try Data(contentsOf: file)
let emptyRaw = try JSONSerialization.jsonObject(with: emptyData) as! [String: Any]
check(emptyRaw.count == 9 && emptyRaw["startedOn"] is NSNull, "Empty fields must be explicit nulls")
func active(_ generation: Int64, _ sequence: Int64, _ startedOn: String = "2026-11-01", _ accountScope: String? = nil) -> CoupleWidgetSnapshot {
    CoupleWidgetSnapshot(schemaVersion: 1, accountScope: accountScope ?? scope,
        sessionGeneration: generation, requestSequence: sequence, relationshipId: "relationship",
        relationshipVersion: 1, startedOn: startedOn, status: "active", lastSyncedAt: "2026-11-01T00:00:00.000Z")
}
try store.replace(active(generation, 1))
let reopened = CoupleWidgetStore(file: file)
check(try reopened.read()?.startedOn == "2026-11-01", "Reopen preserves snapshot")
rejects { try reopened.replace(active(generation, 1)) }
rejects { try reopened.replace(active(generation, 0)) }
rejects { try reopened.replace(active(generation, 2, "2026-11-01", String(repeating: "b", count: 64))) }
let logout = try reopened.begin(scope: nil)
check(logout > generation, "Logout increments persisted generation")
check(try reopened.read()?.startedOn == nil, "Logout removes start date")
check(try reopened.read()?.status == "signedOut", "Logout state")
check(try reopened.read()?.counterProjection() == nil, "Signed-out counter projection is empty")
rejects { try reopened.replace(active(generation, 3)) }
let relogin = try CoupleWidgetStore(file: file).begin(scope: scope)
check(relogin > logout, "Same account relogin has new generation")
try reopened.replace(active(relogin, 1))
let record = active(relogin, 1)
check(Set(record.counterProjection()!.keys) == Set(["schemaVersion", "startedOn", "lastSyncedAt"]), "Projection exposes no identity or credentials")
let stamp = ISO8601DateFormatter()
func days(_ date: String, _ instant: String, _ zone: String, _ expected: Int) {
    check(CoupleWidgetCalendar.days(active(relogin, 1, date), now: stamp.date(from: instant)!, timeZone: TimeZone(identifier: zone)!) == expected, "Calendar case \(date), \(zone)")
}
days("2026-11-01", "2026-11-01T04:00:00Z", "Asia/Taipei", 1)
days("2026-11-01", "2027-01-01T04:00:00Z", "Asia/Taipei", 62)
days("2024-02-28", "2024-03-01T04:00:00Z", "Asia/Taipei", 3)
days("2026-03-07", "2026-03-09T16:00:00Z", "America/New_York", 3)
days("2026-10-31", "2026-11-02T17:00:00Z", "America/New_York", 3)
days("2026-11-02", "2026-11-02T01:00:00Z", "Pacific/Honolulu", 1)
check(CoupleWidgetCalendar.days(try reopened.read(), now: stamp.date(from: "2026-11-02T01:00:00Z")!, timeZone: TimeZone(identifier: "Asia/Taipei")!) == 2, "Device timezone read at calculation")
rejects { try active(relogin, 2, "2026-02-30").validate() }
var raw = try JSONSerialization.jsonObject(with: JSONEncoder().encode(record)) as! [String: Any]
raw["token"] = "fixture"
rejects { _ = try CoupleWidgetSnapshot.decode(JSONSerialization.data(withJSONObject: raw)) }
raw.removeValue(forKey: "token"); raw["requestSequence"] = true
rejects { _ = try CoupleWidgetSnapshot.decode(JSONSerialization.data(withJSONObject: raw)) }
raw["requestSequence"] = 1.5
rejects { _ = try CoupleWidgetSnapshot.decode(JSONSerialization.data(withJSONObject: raw)) }
raw["requestSequence"] = 1; raw["status"] = "unbound"
rejects { _ = try CoupleWidgetSnapshot.decode(JSONSerialization.data(withJSONObject: raw)) }
let beforeConcurrent = try reopened.read()!.sessionGeneration
DispatchQueue.concurrentPerform(iterations: 20) { _ in
    do { _ = try CoupleWidgetStore(file: file).begin(scope: scope) }
    catch { preconditionFailure("Serialized writer failed: \(error)") }
}
check(try reopened.read()?.sessionGeneration == beforeConcurrent + 20, "Host instances serialize generation updates")
let unavailable = CoupleWidgetStore(file: directory.appendingPathComponent("missing/record.json"))
rejects { _ = try unavailable.begin(scope: scope) }
check(!FileManager.default.fileExists(atPath: unavailable.file.path), "Failed write does not claim a record")
try Data("corrupt".utf8).write(to: file)
rejects { _ = try reopened.begin(scope: scope) }
check(try Data(contentsOf: file) == Data("corrupt".utf8), "Corrupt generation cannot be reset silently")
let appearanceFile = directory.appendingPathComponent("appearance.txt")
var named = active(relogin, 5)
named.partnerName = "Partner"
let decodedName = try CoupleWidgetSnapshot.decode(JSONEncoder().encode(named))
check(decodedName.partnerName == "Partner", "Name survives storage encoding")
check(Set(decodedName.counterProjection()!.keys) == Set(["schemaVersion", "startedOn", "lastSyncedAt"]), "Read-only projection excludes partner name")
check(try CoupleWidgetSnapshot.empty(scope: nil, generation: 50).partnerName == nil, "Logout clears partner name")
named.partnerName = "bad\nname"
rejects { try named.validate() }
check(try CoupleWidgetAppearance.read(from: appearanceFile) == "rose", "Missing appearance defaults to rose")
for id in CoupleWidgetAppearance.ids {
    try CoupleWidgetAppearance.write(id, to: appearanceFile)
    check(try CoupleWidgetAppearance.read(from: appearanceFile) == id, "Palette persists")
    check(CoupleWidgetAppearance.colors(id).count == 3, "Palette has gradient and foreground")
}
rejects { try CoupleWidgetAppearance.write("invalid", to: appearanceFile) }
try Data("obsolete".utf8).write(to: appearanceFile)
check(try CoupleWidgetAppearance.read(from: appearanceFile) == "rose", "Unknown stored appearance defaults safely")
check(try Data(contentsOf: file) == Data("corrupt".utf8), "Appearance writes never modify relationship storage")
print("CoupleWidgetStore: \(checks) Foundation checks passed; WidgetKit/signing not evaluated")
