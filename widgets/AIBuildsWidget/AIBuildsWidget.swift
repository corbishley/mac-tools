import WidgetKit
import SwiftUI

@main
struct AIBuildsWidgetBundle: WidgetBundle {
    var body: some Widget {
        AIBuildsWidget()
    }
}

struct AIBuildsWidget: Widget {
    let kind = "AIBuildsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AIBuildsProvider()) { entry in
            AIBuildsEntryView(entry: entry)
                .containerBackground(for: .widget) { Color(nsColor: .windowBackgroundColor) }
        }
        .configurationDisplayName("AI Builds")
        .description("CI/CD and service status.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct AIBuildsEntryView: View {
    let entry: AIBuildsEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemMedium: BuildsWidgetView(entry: entry, showSandbox: false)
        default:            BuildsWidgetView(entry: entry, showSandbox: true)
        }
    }
}
