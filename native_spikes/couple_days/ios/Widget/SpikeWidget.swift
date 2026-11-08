import SwiftUI
import WidgetKit

struct SpikeEntry: TimelineEntry {
    let date: Date
    let startedOn: String?
}

struct SpikeProvider: TimelineProvider {
    func placeholder(in context: Context) -> SpikeEntry { SpikeEntry(date: Date(), startedOn: "2026-11-01") }
    func getSnapshot(in context: Context, completion: @escaping (SpikeEntry) -> Void) {
        completion(SpikeEntry(date: Date(), startedOn: SpikeStore.read()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<SpikeEntry>) -> Void) {
        let now = Date()
        let start = SpikeStore.read()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        let midnight = calendar.startOfDay(for: now)
        let entries = [SpikeEntry(date: now, startedOn: start)] + (1...7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: midnight).map { SpikeEntry(date: $0, startedOn: start) }
        }
        // Rebuild from the stored start date; the timeline horizon is not an expiry.
        let reload = calendar.date(byAdding: .day, value: 1, to: midnight) ?? now.addingTimeInterval(3600)
        completion(Timeline(entries: entries, policy: .after(reload)))
    }
}

@main
struct SpikeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CoupleDaysSpike", provider: SpikeProvider()) { entry in
            Group {
                if let date = entry.startedOn, let count = SpikeCalendar.count(startedOn: date, now: entry.date, timeZone: .autoupdatingCurrent) {
                    Text("Day \(count)").font(.title).minimumScaleFactor(0.5)
                } else { Text("No sample") }
            }
            .containerBackground(.background, for: .widget)
            .widgetURL(URL(string: "coupledays-spike://open"))
        }
        .configurationDisplayName("Couple days sample")
        .description("Fixture data only; no account connection.")
        .supportedFamilies([.systemSmall])
    }
}
