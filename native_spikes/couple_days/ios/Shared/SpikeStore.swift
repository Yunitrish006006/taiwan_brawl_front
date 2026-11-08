import Foundation

enum SpikeStore {
    // Dedicated sample suite: never reads production accounts or credentials.
    static let suite = "group.com.yunitrish.taiwanbrawl.coupledays.spike"
    static let key = "sample.startedOn"
    static func read() -> String? { UserDefaults(suiteName: suite)?.string(forKey: key) }
    static func write(_ date: String?) {
        let defaults = UserDefaults(suiteName: suite)
        if let date { defaults?.set(date, forKey: key) }
        else { defaults?.removeObject(forKey: key) }
    }
}
