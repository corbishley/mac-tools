import SwiftUI
import WidgetKit

// MARK: - Shared helpers

func trafficColor(usageFrac: Double, timeFrac: Double) -> Color {
    let elapsedFrac = 1.0 - timeFrac
    let diff = elapsedFrac - usageFrac
    if diff >= -0.01 { return .green }
    if diff >= -0.10 { return .orange }
    return .red
}

func monthTimeFrac(now: Date = Date()) -> Double {
    let cal = Calendar.current
    var c = cal.dateComponents([.year, .month], from: now)
    c.day = 1
    let start = cal.date(from: c) ?? now
    c.month! += 1
    let end = cal.date(from: c) ?? now
    let total    = end.timeIntervalSince(start)
    let remaining = end.timeIntervalSince(now)
    return max(0, remaining / total)
}

func resetText(resetsAt: Date, now: Date = Date()) -> String {
    let secs = max(0, Int(resetsAt.timeIntervalSince(now)))
    if secs < 60 { return "soon" }
    let d = secs / 86400
    let h = (secs % 86400) / 3600
    let m = (secs % 3600) / 60
    if d > 0 { return "↺ \(d)d \(h)h" }
    if h > 0 { return "↺ \(h)h \(m)m" }
    return "↺ \(m)m"
}

// MARK: - Dual-fill progress bar

struct DualBar: View {
    let usageFrac:   Double   // 0–1  (filled, opaque)
    let elapsedFrac: Double   // 0–1  (tint, translucent background layer)
    let color:       Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(height: 5)
                RoundedRectangle(cornerRadius: 2)
                    .fill(color.opacity(0.25))
                    .frame(width: geo.size.width * min(elapsedFrac, 1), height: 5)
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: geo.size.width * min(usageFrac, 1), height: 5)
            }
        }
        .frame(height: 5)
    }
}

// MARK: - Reusable row types

struct ClaudeWindowRow: View {
    let label:  String
    let window: WindowUsage
    let now:    Date

    private var usageFrac:   Double { min(window.utilization / 100, 1) }
    private var timeFrac:    Double { max(0, window.resetsAt.timeIntervalSince(now)) / window.windowSecs }
    private var elapsedFrac: Double { 1 - timeFrac }
    private var color:       Color  { trafficColor(usageFrac: usageFrac, timeFrac: timeFrac) }

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label).font(.caption2).frame(width: 22, alignment: .leading)
            DualBar(usageFrac: usageFrac, elapsedFrac: elapsedFrac, color: color)
            Text("\(Int(window.utilization))%")
                .font(.caption2).monospacedDigit()
                .frame(width: 30, alignment: .trailing)
            Text(resetText(resetsAt: window.resetsAt, now: now))
                .font(.caption2).foregroundStyle(.secondary)
        }
    }
}

struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }
}

// MARK: - Medium view (Claude only)

struct MediumLimitsView: View {
    let entry: AILimitsEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("AI Limits").font(.headline).fontWeight(.semibold)
                Spacer()
                Text(entry.date, style: .time).font(.caption2).foregroundStyle(.secondary)
            }

            SectionHeader(title: "Claude")
            if let claude = entry.claude {
                if let w = claude.fiveHour {
                    ClaudeWindowRow(label: "5h", window: w, now: entry.date)
                }
                if let w = claude.sevenDay {
                    ClaudeWindowRow(label: "7d", window: w, now: entry.date)
                }
                if let pct = claude.extraUtilization {
                    Text("Extra add-on: \(Int(pct))% used")
                        .font(.caption2).foregroundStyle(.secondary)
                        .padding(.leading, 12)
                }
                if claude.fiveHour == nil && claude.sevenDay == nil {
                    Text("Token expired — use Claude then Save & Reload")
                        .font(.caption2).foregroundStyle(.secondary)
                        .padding(.leading, 12)
                }
            } else {
                Text("Use Claude then hit Save & Reload in settings")
                    .font(.caption2).foregroundStyle(.secondary)
                    .padding(.leading, 12)
            }
            Spacer()
        }
        .padding(12)
    }
}
