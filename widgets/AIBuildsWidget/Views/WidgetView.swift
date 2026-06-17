import SwiftUI

// MARK: - Status dot

private func conclusionColor(_ c: WorkflowConclusion) -> Color {
    switch c {
    case .success:                        return .green
    case .failure, .timedOut, .startupFailure: return .red
    case .inProgress:                     return .blue
    case .cancelled:                      return .orange
    default:                              return .gray
    }
}

private struct StatusDot: View {
    let run: WorkflowRun
    var body: some View {
        Circle().fill(conclusionColor(run.conclusion)).frame(width: 8, height: 8)
    }
}

private func renderColor(_ s: RenderDeployStatus) -> Color { conclusionColor(s.conclusion) }

private func neonColor(_ state: String) -> Color {
    switch state {
    case "active": return .green
    case "idle":   return .orange
    case "init":   return .blue
    default:       return .gray
    }
}

// MARK: - Build row

private struct BuildRow: View {
    let label:  String
    let run:    WorkflowRun
    var labelWidth: CGFloat = 80

    var body: some View {
        HStack(spacing: 5) {
            StatusDot(run: run)
            Text(label)
                .font(.caption2)
                .lineLimit(1)
                .frame(width: labelWidth, alignment: .leading)
            Text(run.conclusion.label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            if let at = run.createdAt {
                Text("· \(at.formatted(.dateTime.weekday(.abbreviated).hour().minute()))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Render + Neon rows

private struct RenderRow: View {
    let svc: RenderService
    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(renderColor(svc.deployStatus)).frame(width: 8, height: 8)
            Text(svc.name).font(.caption2).lineLimit(1)
            Text(svc.deployStatus.label).font(.caption2).foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }
}

private struct NeonRow: View {
    let ep: NeonEndpoint
    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(neonColor(ep.state)).frame(width: 8, height: 8)
            Text("\(ep.projectName) \(ep.branch)").font(.caption2).lineLimit(1)
            Text(ep.state).font(.caption2).foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Section header

private struct BuildSectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
    }
}

// MARK: - Per-environment block

private struct EnvBlock: View {
    let status:     EnvironmentStatus
    let render:     [RenderService]
    let neon:       [NeonEndpoint]
    let backendRepo: String
    let iosRepo:     String

    private var envRender: [RenderService] {
        render.filter { $0.name.lowercased().contains(status.name.lowercased()) }
    }
    private var envNeon: [NeonEndpoint] {
        neon.filter {
            $0.projectName.lowercased().contains(status.name.lowercased()) ||
            $0.branch.lowercased().contains(status.name.lowercased())
        }
    }

    var body: some View {
        Group {
            BuildSectionHeader(title: "── \(status.name) ──")
            BuildRow(label: "\(backendRepo) CD", run: status.backendCD)
            BuildRow(label: "\(backendRepo) CI", run: status.backendCI)
            BuildRow(label: "migrate-db",        run: status.backendMigrate)
            BuildRow(label: "\(iosRepo) CD",     run: status.iosCD)
            BuildRow(label: "\(iosRepo) CI",     run: status.iosCI)
            if !envRender.isEmpty {
                BuildSectionHeader(title: "Render")
                ForEach(envRender, id: \.name) { RenderRow(svc: $0) }
            }
            if !envNeon.isEmpty {
                BuildSectionHeader(title: "Neon")
                ForEach(envNeon, id: \.branch) { NeonRow(ep: $0) }
            }
        }
    }
}

// MARK: - Main view

struct BuildsWidgetView: View {
    let entry:       AIBuildsEntry
    let showSandbox: Bool

    private var backend: String { SettingsData.load().resolvedBackendRepo }
    private var ios:     String { SettingsData.load().resolvedIosRepo }

    private var prodEnv: EnvironmentStatus? { entry.environments.first { $0.name == "production" } }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            // Header
            HStack {
                Text("AI Builds").font(.headline).fontWeight(.semibold)
                Spacer()
                Text(entry.date, style: .time).font(.caption2).foregroundStyle(.secondary)
            }
            .padding(.bottom, 2)

            // Rebuilds + delete (large only)
            if showSandbox {
                BuildSectionHeader(title: "── Rebuilds ──")
                BuildRow(label: backend, run: entry.backendRebuild)
                BuildRow(label: ios,     run: entry.iosRebuild)
                BuildSectionHeader(title: "── Delete merged ──")
                BuildRow(label: backend, run: entry.backendDeleteBranches)
                BuildRow(label: ios,     run: entry.iosDeleteBranches)
                Divider()
            }

            // Production (both sizes)
            if let prod = prodEnv {
                EnvBlock(status: prod,
                         render: entry.renderServices,
                         neon: entry.neonEndpoints,
                         backendRepo: backend,
                         iosRepo: ios)
            } else {
                Text("Configure GitHub token and org in settings")
                    .font(.caption2).foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
    }
}
