import Foundation

enum SpikeCalendar {
    static func count(startedOn: String, now: Date, timeZone: TimeZone) -> Int? {
        let parts = startedOn.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let year = Int(parts[0]), year >= 1900, let month = Int(parts[1]), let day = Int(parts[2]) else { return nil }
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let start = utc.date(from: DateComponents(year: year, month: month, day: day)),
              utc.dateComponents([.year, .month, .day], from: start) == DateComponents(year: year, month: month, day: day) else { return nil }
        var local = Calendar(identifier: .gregorian)
        local.timeZone = timeZone
        let fields = local.dateComponents([.year, .month, .day], from: now)
        guard let today = utc.date(from: fields), let days = utc.dateComponents([.day], from: start, to: today).day else { return nil }
        return max(1, days + 1)
    }
}
