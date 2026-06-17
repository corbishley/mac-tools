import WidgetKit
import SwiftUI

@main
struct AILimitsWidgetBundle: WidgetBundle {
    var body: some Widget {
        AILimitsWidget()
    }
}

struct AILimitsWidget: Widget {
    let kind = "AILimitsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AILimitsProvider()) { entry in
            AILimitsEntryView(entry: entry)
                .containerBackground(for: .widget) { Color(nsColor: .windowBackgroundColor) }
        }
        .configurationDisplayName("AI Limits")
        .description("Quota usage across AI and cloud services.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct AILimitsEntryView: View {
    let entry: AILimitsEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemMedium: MediumLimitsView(entry: entry)
        default:            LargeLimitsView(entry: entry)
        }
    }
}
