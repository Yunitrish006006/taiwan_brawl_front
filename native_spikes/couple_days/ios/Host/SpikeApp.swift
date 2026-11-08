import SwiftUI
import WidgetKit

@main
struct SpikeApp: App {
    var body: some Scene {
        WindowGroup {
            VStack(spacing: 24) {
                Text("Couple days sample — fixture data only")
                Button("Use sample date 2026-11-01") {
                    SpikeStore.write("2026-11-01")
                    WidgetCenter.shared.reloadTimelines(ofKind: "CoupleDaysSpike")
                }
                Button("Clear sample") {
                    SpikeStore.write(nil)
                    WidgetCenter.shared.reloadTimelines(ofKind: "CoupleDaysSpike")
                }
                Text("Add the sample widget from the Home Screen widget gallery.")
            }.padding()
        }
    }
}
