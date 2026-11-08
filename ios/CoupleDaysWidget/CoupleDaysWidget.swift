import SwiftUI
import WidgetKit

struct CoupleDaysEntry: TimelineEntry {
    let date: Date
}
struct CoupleDaysProvider: TimelineProvider {
    func placeholder(in context: Context) -> CoupleDaysEntry { CoupleDaysEntry(date: Date()) }
    func getSnapshot(in context: Context, completion: @escaping (CoupleDaysEntry) -> Void) {
        completion(CoupleDaysEntry(date: Date()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<CoupleDaysEntry>) -> Void) {
        let now = Date()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        let midnight = calendar.startOfDay(for: now)
        let future = (1...7).compactMap { calendar.date(byAdding: .day, value: $0, to: midnight) }
        let entries = ([now] + future).map { CoupleDaysEntry(date: $0) }
        let refresh = calendar.date(byAdding: .day, value: 1, to: midnight) ?? now.addingTimeInterval(3600)
        completion(Timeline(entries: entries, policy: .after(refresh)))
    }
}
struct CoupleDaysView: View {
    let entry: CoupleDaysEntry
    var body: some View {
        // Read the latest complete record; never fall back to an old entry's data
        // after clear/read failure. WidgetKit may cache views until reload is honored.
        let snapshot = try? CoupleWidgetContainer.store().read()
        let colors = CoupleWidgetAppearance.colors(try? CoupleWidgetContainer.appearance()).map { rgb in
            Color(red: Double((rgb >> 16) & 255) / 255, green: Double((rgb >> 8) & 255) / 255, blue: Double(rgb & 255) / 255)
        }
        ZStack(alignment: .topTrailing) {
            Circle().fill(colors[2].opacity(0.05)).frame(width: 104, height: 104).offset(x: 36, y: -36).accessibilityHidden(true)
            Image(systemName: "heart").font(.system(size: 18)).opacity(0.45).accessibilityHidden(true)
            Group {
            if let days = CoupleWidgetCalendar.days(snapshot, now: entry.date, timeZone: .autoupdatingCurrent) {
                VStack(spacing: 8) {
                if let name = snapshot?.partnerName {
                    Text(String(format: NSLocalizedString("widget.partnerLine", comment: "Partner"), name))
                        .font(.caption).lineLimit(1).truncationMode(.tail)
                }
                Text(String(format: NSLocalizedString("widget.days", comment: "Day count"), days))
                    .font(.system(size: 34, weight: .semibold, design: .rounded)).minimumScaleFactor(0.5).lineLimit(1)
                }
            } else {
                Text(LocalizedStringKey(snapshot?.status == "unbound" ? "widget.unbound" : "widget.signedOut"))
                    .font(.headline).multilineTextAlignment(.center)
            }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .foregroundStyle(colors[2])
        .padding()
        .containerBackground(for: .widget) { LinearGradient(colors: [colors[0], colors[1]], startPoint: .topLeading, endPoint: .bottomTrailing) }
        .widgetURL(URL(string: "taiwanbrawl-widget://open"))
    }
}
@main
struct CoupleDaysWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: CoupleWidgetStore.kind, provider: CoupleDaysProvider()) { CoupleDaysView(entry: $0) }
            .configurationDisplayName("widget.name")
            .description("widget.description")
            .supportedFamilies([.systemSmall])
    }
}
