import SwiftUI

struct LargeLimitsView: View {
    let entry: AILimitsEntry

    private var now: Date { entry.date }
    private var monthTime: Double { monthTimeFrac(now: now) }
    private var monthElapsed: Double { 1 - monthTime }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header
            HStack {
                Text("AI Limits").font(.headline).fontWeight(.semibold)
                Spacer()
                Text(now, style: .time).font(.caption2).foregroundStyle(.secondary)
            }
            .padding(.bottom, 2)

            claudeSection
            Divider()
            githubSection
            Divider()
            renderSection
            if !entry.neonProjects.isEmpty {
                Divider()
                neonSection
            }
            if let cf = entry.cloudflare {
                Divider()
                cloudflareSection(cf)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
    }

    // MARK: - Claude

    @ViewBuilder private var claudeSection: some View {
        SectionHeader(title: "Claude")
        if let claude = entry.claude {
            if let w = claude.fiveHour {
                ClaudeWindowRow(label: "5h", window: w, now: now)
            }
            if let w = claude.sevenDay {
                ClaudeWindowRow(label: "7d", window: w, now: now)
            }
            if claude.fiveHour == nil && claude.sevenDay == nil {
                placeholderRow("Token expired — use Claude then Save & Reload")
            }
        } else {
            placeholderRow("Token not found — hit Save & Reload after using Claude")
        }
    }

    // MARK: - GitHub Actions

    @ViewBuilder private var githubSection: some View {
        SectionHeader(title: "GitHub Actions")
        if let gh = entry.github {
            let usageFrac = gh.includedMinutes > 0 ? min(gh.totalMinutes / gh.includedMinutes, 1) : 0
            let color = trafficColor(usageFrac: usageFrac, timeFrac: monthTime)
            HStack(spacing: 5) {
                Circle().fill(color).frame(width: 7, height: 7)
                Text("Actions").font(.caption2).frame(width: 40, alignment: .leading)
                DualBar(usageFrac: usageFrac, elapsedFrac: monthElapsed, color: color)
                Text("\(Int(gh.totalMinutes))/\(Int(gh.includedMinutes))m")
                    .font(.caption2).monospacedDigit().foregroundStyle(.secondary)
            }
        } else {
            placeholderRow(SettingsData.load().githubToken.isEmpty ? "GITHUB_TOKEN not set" : "—")
        }
    }

    // MARK: - Render

    @ViewBuilder private var renderSection: some View {
        SectionHeader(title: "Render")
        if let render = entry.render {
            let usageFrac = Double(render.buildMinutes) / Double(RenderBuildUsage.allowance)
            let color = trafficColor(usageFrac: min(usageFrac, 1), timeFrac: monthTime)
            HStack(spacing: 5) {
                Circle().fill(color).frame(width: 7, height: 7)
                Text("Build").font(.caption2).frame(width: 40, alignment: .leading)
                DualBar(usageFrac: min(usageFrac, 1), elapsedFrac: monthElapsed, color: color)
                Text("\(render.buildMinutes)/\(RenderBuildUsage.allowance)m")
                    .font(.caption2).monospacedDigit().foregroundStyle(.secondary)
            }
        } else {
            placeholderRow(SettingsData.load().renderApiKey.isEmpty ? "RENDER_API_KEY not set" : "—")
        }
    }

    // MARK: - Neon

    @ViewBuilder private var neonSection: some View {
        SectionHeader(title: "Neon")
        ForEach(entry.neonProjects, id: \.id) { project in
            neonProjectRows(project)
        }
        // Egress (account-wide)
        let totalTransfer = entry.neonProjects.reduce(0) { $0 + $1.transferBytes }
        let tFrac = Double(totalTransfer) / Double(NeonProjectUsage.transferAllowanceBytes)
        let tColor = trafficColor(usageFrac: min(tFrac, 1), timeFrac: monthTime)
        HStack(spacing: 5) {
            Circle().fill(tColor).frame(width: 7, height: 7)
            Text("Egress").font(.caption2).frame(width: 40, alignment: .leading)
            DualBar(usageFrac: min(tFrac, 1), elapsedFrac: monthElapsed, color: tColor)
            Text("\(bytesToMiB(totalTransfer))/5120 MiB")
                .font(.caption2).monospacedDigit().foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private func neonProjectRows(_ p: NeonProjectUsage) -> some View {
        let periodFrac: Double = {
            guard let start = p.periodStart, let end = p.periodEnd else { return monthTime }
            let total = end.timeIntervalSince(start)
            let remaining = end.timeIntervalSince(now)
            return max(0, remaining / total)
        }()
        let cFrac  = min(p.computeTimeSecs / NeonProjectUsage.computeAllowanceSecs, 1)
        let cColor = trafficColor(usageFrac: cFrac, timeFrac: periodFrac)
        let sFrac  = min(Double(p.storageBytes) / Double(NeonProjectUsage.storageAllowanceBytes), 1)
        let sColor: Color = sFrac < 0.7 ? .green : (sFrac < 0.9 ? .orange : .red)

        HStack(spacing: 5) {
            Circle().fill(cColor).frame(width: 7, height: 7)
            Text("\(p.name) cpu").font(.caption2).lineLimit(1)
                .frame(width: 80, alignment: .leading)
            DualBar(usageFrac: cFrac, elapsedFrac: 1 - periodFrac, color: cColor)
            Text("\(String(format: "%.1f", p.computeTimeSecs / 3600))/100 CU-h")
                .font(.caption2).monospacedDigit().foregroundStyle(.secondary)
        }
        HStack(spacing: 5) {
            Circle().fill(sColor).frame(width: 7, height: 7)
            Text("\(p.name) db").font(.caption2).lineLimit(1)
                .frame(width: 80, alignment: .leading)
            DualBar(usageFrac: sFrac, elapsedFrac: sFrac, color: sColor)
            Text("\(bytesToMiB(p.storageBytes))/512 MiB")
                .font(.caption2).monospacedDigit().foregroundStyle(.secondary)
        }
    }

    // MARK: - Cloudflare

    @ViewBuilder private func cloudflareSection(_ cf: CloudflareUsage) -> some View {
        SectionHeader(title: "Cloudflare")
        let pFrac  = min(Double(cf.pagesBuilds) / Double(CloudflareUsage.pagesAllowance), 1)
        let pColor = trafficColor(usageFrac: pFrac, timeFrac: monthTime)
        HStack(spacing: 5) {
            Circle().fill(pColor).frame(width: 7, height: 7)
            Text("Pages").font(.caption2).frame(width: 40, alignment: .leading)
            DualBar(usageFrac: pFrac, elapsedFrac: monthElapsed, color: pColor)
            Text("\(cf.pagesBuilds)/\(CloudflareUsage.pagesAllowance) builds")
                .font(.caption2).monospacedDigit().foregroundStyle(.secondary)
        }
        let wFrac  = min(Double(cf.workersRequests) / Double(CloudflareUsage.workersDailyAllowance), 1)
        let wColor: Color = wFrac < 0.8 ? .green : (wFrac < 1.0 ? .orange : .red)
        HStack(spacing: 5) {
            Circle().fill(wColor).frame(width: 7, height: 7)
            Text("Workers").font(.caption2).frame(width: 40, alignment: .leading)
            DualBar(usageFrac: wFrac, elapsedFrac: wFrac, color: wColor)
            Text("\(cf.workersRequests.formatted())/\(CloudflareUsage.workersDailyAllowance.formatted()) today")
                .font(.caption2).monospacedDigit().foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private func placeholderRow(_ msg: String) -> some View {
        Text(msg).font(.caption2).foregroundStyle(.secondary).padding(.leading, 12)
    }

    private func bytesToMiB(_ bytes: Int64) -> String {
        String(format: "%.0f", Double(bytes) / (1024 * 1024))
    }
}
