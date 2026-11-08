import Foundation
import CoreFoundation

enum CoupleWidgetError: Error { case invalid, obsolete, unavailable }

struct CoupleWidgetSnapshot: Codable {
    static let maxInteger: Int64 = 9_007_199_254_740_991
    let schemaVersion: Int
    let accountScope: String?
    let sessionGeneration: Int64
    let requestSequence: Int64
    let relationshipId: String?
    let relationshipVersion: Int64?
    let startedOn: String?
    let status: String
    let lastSyncedAt: String?
    var partnerName: String? = nil

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion, accountScope, sessionGeneration, requestSequence,
             relationshipId, relationshipVersion, startedOn, status, lastSyncedAt, partnerName
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(schemaVersion, forKey: .schemaVersion)
        try c.encode(accountScope, forKey: .accountScope)
        try c.encode(sessionGeneration, forKey: .sessionGeneration)
        try c.encode(requestSequence, forKey: .requestSequence)
        try c.encode(relationshipId, forKey: .relationshipId)
        try c.encode(relationshipVersion, forKey: .relationshipVersion)
        try c.encode(startedOn, forKey: .startedOn)
        try c.encode(status, forKey: .status)
        try c.encode(lastSyncedAt, forKey: .lastSyncedAt)
        try c.encodeIfPresent(partnerName, forKey: .partnerName)
    }
    static func decode(_ data: Data) throws -> Self {
        guard let raw = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(raw.keys).subtracting(["partnerName"]) == Set(CodingKeys.allCases.map(\.rawValue)).subtracting(["partnerName"]) else { throw CoupleWidgetError.invalid }
        for key in ["schemaVersion", "sessionGeneration", "requestSequence", "relationshipVersion"] {
            if raw[key] is NSNull { continue }
            guard let number = raw[key] as? NSNumber,
                  CFGetTypeID(number) != CFBooleanGetTypeID(),
                  number.doubleValue.isFinite,
                  number.doubleValue.rounded() == number.doubleValue else { throw CoupleWidgetError.invalid }
        }
        let snapshot = try JSONDecoder().decode(Self.self, from: data)
        try snapshot.validate()
        return snapshot
    }
    func validate() throws {
        guard schemaVersion == 1, (1...Self.maxInteger).contains(sessionGeneration),
              (0...Self.maxInteger).contains(requestSequence),
              ["active", "unbound", "signedOut"].contains(status),
              (accountScope == nil) == (status == "signedOut") else { throw CoupleWidgetError.invalid }
        if let scope = accountScope, scope.range(of: "^[a-f0-9]{64}$", options: .regularExpression) == nil { throw CoupleWidgetError.invalid }
        if status == "active" {
            if let name = partnerName {
                guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, name.utf16.count <= 160,
                      name.rangeOfCharacter(from: .controlCharacters) == nil else { throw CoupleWidgetError.invalid }
            }
            guard let id = relationshipId, !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  let version = relationshipVersion, (1...Self.maxInteger).contains(version),
                  let date = startedOn, CoupleWidgetCalendar.date(date) != nil,
                  let stamp = lastSyncedAt, stamp.hasSuffix("Z") else { throw CoupleWidgetError.invalid }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if formatter.date(from: stamp) == nil {
                formatter.formatOptions = [.withInternetDateTime]
                guard formatter.date(from: stamp) != nil else { throw CoupleWidgetError.invalid }
            }
        } else if relationshipId != nil || relationshipVersion != nil || startedOn != nil || lastSyncedAt != nil || partnerName != nil {
            throw CoupleWidgetError.invalid
        }
    }
    static func empty(scope: String?, generation: Int64) throws -> Self {
        let snapshot = Self(schemaVersion: 1, accountScope: scope, sessionGeneration: generation, requestSequence: 0,
            relationshipId: nil, relationshipVersion: nil, startedOn: nil,
            status: scope == nil ? "signedOut" : "unbound", lastSyncedAt: nil)
        try snapshot.validate()
        return snapshot
    }
    func counterProjection() -> [String: Any]? {
        guard (try? validate()) != nil, status == "active", let date = startedOn, let stamp = lastSyncedAt else { return nil }
        return ["schemaVersion": 1, "startedOn": date, "lastSyncedAt": stamp]
    }
}

enum CoupleWidgetCalendar {
    static var utc: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }
    static func date(_ text: String) -> Date? {
        guard text.range(of: "^[0-9]{4}-[0-9]{2}-[0-9]{2}$", options: .regularExpression) != nil else { return nil }
        let p = text.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3, p[0] >= 1900 else { return nil }
        let fields = DateComponents(year: p[0], month: p[1], day: p[2])
        guard let value = utc.date(from: fields), utc.dateComponents([.year, .month, .day], from: value) == fields else { return nil }
        return value
    }
    static func days(_ snapshot: CoupleWidgetSnapshot?, now: Date, timeZone: TimeZone) -> Int? {
        guard let snapshot, (try? snapshot.validate()) != nil, snapshot.status == "active",
              let text = snapshot.startedOn, let start = date(text) else { return nil }
        var local = Calendar(identifier: .gregorian)
        local.timeZone = timeZone
        let fields = local.dateComponents([.year, .month, .day], from: now)
        guard let today = utc.date(from: fields), let days = utc.dateComponents([.day], from: start, to: today).day else { return nil }
        return max(1, days + 1)
    }
}

/// App is the sole writer; extension reads a complete atomically replaced file.
/// A process-wide lock serializes all host store instances. No cross-process writes.
final class CoupleWidgetStore {
    static let group = "group.com.yunitrish.taiwanbrawl.coupledays"
    static let kind = "TaiwanBrawlCoupleDays"
    private static let lock = NSLock()
    let file: URL
    init(file: URL) { self.file = file }
    func read() throws -> CoupleWidgetSnapshot? {
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        return try CoupleWidgetSnapshot.decode(Data(contentsOf: file))
    }
    func begin(scope: String?) throws -> Int64 {
        Self.lock.lock(); defer { Self.lock.unlock() }
        let previous = try read()?.sessionGeneration ?? 0
        guard previous < CoupleWidgetSnapshot.maxInteger else { throw CoupleWidgetError.invalid }
        let next = try CoupleWidgetSnapshot.empty(scope: scope, generation: previous + 1)
        try save(next)
        return next.sessionGeneration
    }
    func replace(_ next: CoupleWidgetSnapshot) throws {
        Self.lock.lock(); defer { Self.lock.unlock() }
        try next.validate()
        guard let current = try read(), current.sessionGeneration == next.sessionGeneration,
              current.accountScope == next.accountScope, next.requestSequence > current.requestSequence else { throw CoupleWidgetError.obsolete }
        try save(next)
    }
    private func save(_ snapshot: CoupleWidgetSnapshot) throws {
        let data = try JSONEncoder().encode(snapshot)
        #if os(iOS)
        try data.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try data.write(to: file, options: [.atomic])
        #endif
    }
}
