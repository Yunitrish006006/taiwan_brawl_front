import Foundation

func verify(_ start: String, _ instant: String, _ zone: String, _ expected: Int?) {
    let now = ISO8601DateFormatter().date(from: instant)!
    let result = SpikeCalendar.count(startedOn: start, now: now, timeZone: TimeZone(identifier: zone)!)
    precondition(result == expected, "\(start), \(instant), \(zone): \(String(describing: result)) != \(String(describing: expected))")
}
verify("2026-11-01", "2026-11-01T04:00:00Z", "Asia/Taipei", 1)
verify("2026-11-01", "2026-11-04T04:00:00Z", "Asia/Taipei", 4)
verify("2024-02-28", "2024-03-01T04:00:00Z", "Asia/Taipei", 3)
verify("2026-03-07", "2026-03-09T16:00:00Z", "America/New_York", 3)
verify("2026-10-31", "2026-11-02T17:00:00Z", "America/New_York", 3)
verify("2026-11-02", "2026-11-02T01:00:00Z", "Pacific/Honolulu", 1)
verify("2026-11-01", "2026-11-02T01:00:00Z", "Asia/Taipei", 2)
verify("2026-02-30", "2026-03-01T04:00:00Z", "Asia/Taipei", nil)
print("SpikeCalendar: 8 calendar checks passed (Foundation only; not WidgetKit runtime)")
