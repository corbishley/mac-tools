import Foundation
import WidgetKit

// MARK: - Settings (written by container app, read by widget extensions)

struct SettingsData: Codable {
    var githubToken:  String = ""
    var githubOrg:    String = ""
    var backendRepo:  String = "backend"
    var iosRepo:      String = "ios-app"
    var renderApiKey: String = ""
    var neonApiKey:   String = ""
    var cfApiToken:   String = ""
    var claudeToken:  String = ""
    var refreshMins:  Int    = 1

    // Resolved accessors
    var resolvedBackendRepo: String { backendRepo.isEmpty ? "backend"  : backendRepo }
    var resolvedIosRepo:     String { iosRepo.isEmpty     ? "ios-app"  : iosRepo     }
    var resolvedRefreshMins: Int    { refreshMins > 0     ? refreshMins : 1           }
    func resolvedNeonKey()    -> String? { neonApiKey.isEmpty   ? nil : neonApiKey }
    func resolvedCFToken()    -> String? { cfApiToken.isEmpty   ? nil : cfApiToken }
    func resolvedClaudeToken()-> String? { claudeToken.isEmpty  ? nil : claudeToken }

    // Container app (unsandboxed) writes into each widget extension's container,
    // snapshotting the Claude token from keychain at the moment of saving.
    func saveToWidgets() {
        var copy = self
        if let fresh = KeychainHelper.claudeAccessToken() { copy.claudeToken = fresh }
        let widgetBundleIDs = [
            "me.shoesthatfit.MacToolsWidgets.AILimitsWidget",
            "me.shoesthatfit.MacToolsWidgets.AIBuildsWidget",
        ]
        guard let encoded = try? JSONEncoder().encode(copy) else { return }
        let home = FileManager.default.homeDirectoryForCurrentUser
        // Write to each widget extension's sandboxed container
        for id in widgetBundleIDs {
            let dir = home
                .appendingPathComponent("Library/Containers/\(id)/Data/Library/Application Support/MacToolsWidgets")
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try? encoded.write(to: dir.appendingPathComponent("settings.json"))
        }
        // Also write to the container app's own Application Support so load() round-trips correctly
        if let url = Self.containerAppSettingsURL() {
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? encoded.write(to: url)
        }
    }

    // Widget extensions read from their own sandboxed container via applicationSupportDirectory
    private static func settingsURL() -> URL? {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("MacToolsWidgets/settings.json")
    }

    // Container app (non-sandboxed) persists here so settings survive between app opens
    private static func containerAppSettingsURL() -> URL? {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/MacToolsWidgets/settings.json")
    }

    static func load() -> SettingsData {
        // Try own applicationSupport first (works for both widget extensions and container app)
        // Fall back to the container app path for the unsandboxed settings app
        for url in [settingsURL(), containerAppSettingsURL()].compactMap({ $0 }) {
            if let data = try? Data(contentsOf: url),
               let s = try? JSONDecoder().decode(SettingsData.self, from: data) {
                return s
            }
        }
        return SettingsData()
    }
}

// MARK: - AILimitsWidget models

struct WindowUsage {
    let utilization: Double   // 0–100
    let resetsAt:    Date
    let windowSecs:  Double
}

struct ClaudeUsage {
    let fiveHour:         WindowUsage?
    let sevenDay:         WindowUsage?
    let extraUtilization: Double?
}

struct GitHubActionsUsage {
    let totalMinutes:    Double
    let includedMinutes: Double
    let breakdown:       [String: Double]   // "UBUNTU", "WINDOWS", "MACOS"
}

struct RenderBuildUsage {
    let buildMinutes: Int
    static let allowance = 500
}

struct NeonProjectUsage {
    let id:              String
    let name:            String
    let computeTimeSecs: Double
    let storageBytes:    Int64
    let transferBytes:   Int64
    let periodStart:     Date?
    let periodEnd:       Date?

    static let computeAllowanceSecs:   Double = 100 * 3600
    static let storageAllowanceBytes:  Int64  = 512 * 1024 * 1024
    static let transferAllowanceBytes: Int64  = 5 * 1024 * 1024 * 1024
}

struct CloudflareUsage {
    let pagesBuilds:      Int
    let workersRequests:  Int
    static let pagesAllowance          = 500
    static let workersDailyAllowance   = 100_000
}

struct AILimitsEntry: TimelineEntry {
    let date:         Date
    let claude:       ClaudeUsage?
    let github:       GitHubActionsUsage?
    let render:       RenderBuildUsage?
    let neonProjects: [NeonProjectUsage]
    let cloudflare:   CloudflareUsage?
}

// MARK: - AIBuildsWidget models

enum WorkflowConclusion {
    case success, failure, timedOut, startupFailure, cancelled, inProgress, noRuns, unknown

    var dotColor: String {
        switch self {
        case .success:                        return "green"
        case .failure, .timedOut, .startupFailure: return "red"
        case .inProgress:                     return "blue"
        case .cancelled:                      return "orange"
        default:                              return "gray"
        }
    }

    var label: String {
        switch self {
        case .success:        return "passed"
        case .failure:        return "failed"
        case .timedOut:       return "timed out"
        case .startupFailure: return "startup failed"
        case .cancelled:      return "cancelled"
        case .inProgress:     return "running"
        case .noRuns:         return "no runs"
        case .unknown:        return "unknown"
        }
    }
}

struct WorkflowRun {
    let conclusion: WorkflowConclusion
    let createdAt:  Date?

    static let noRuns   = WorkflowRun(conclusion: .noRuns,   createdAt: nil)
    static let unknown  = WorkflowRun(conclusion: .unknown,  createdAt: nil)
}

struct EnvironmentStatus {
    let name:          String   // "production", "sandbox01"
    let backendCI:     WorkflowRun
    let backendCD:     WorkflowRun
    let backendMigrate:WorkflowRun
    let iosCI:         WorkflowRun
    let iosCDTesting:  WorkflowRun
}

enum RenderDeployStatus: String {
    case live
    case buildInProgress  = "build_in_progress"
    case updateInProgress = "update_in_progress"
    case created
    case buildFailed      = "build_failed"
    case updateFailed     = "update_failed"
    case preDeployFailed  = "pre_deploy_failed"
    case deactivated
    case canceled
    case unknown

    var label: String {
        switch self {
        case .live:             return "live"
        case .buildInProgress:  return "building"
        case .updateInProgress: return "updating"
        case .created:          return "created"
        case .buildFailed:      return "build failed"
        case .updateFailed:     return "update failed"
        case .preDeployFailed:  return "pre-deploy failed"
        case .deactivated:      return "deactivated"
        case .canceled:         return "canceled"
        case .unknown:          return "unknown"
        }
    }

    var conclusion: WorkflowConclusion {
        switch self {
        case .live:                               return .success
        case .buildFailed, .updateFailed,
             .preDeployFailed:                    return .failure
        case .buildInProgress, .updateInProgress,
             .created:                            return .inProgress
        case .deactivated, .canceled:             return .cancelled
        default:                                  return .unknown
        }
    }
}

struct RenderService {
    let name:         String
    let deployStatus: RenderDeployStatus
    let deployAt:     Date?
}

struct NeonEndpoint {
    let projectName: String
    let branch:      String
    let state:       String   // "active", "idle", "init", "unknown"
    let updatedAt:   Date?
}

struct AIBuildsEntry: TimelineEntry {
    let date:                 Date
    let environments:         [EnvironmentStatus]
    let renderServices:       [RenderService]
    let neonEndpoints:        [NeonEndpoint]
    let backendRebuild:       WorkflowRun
    let iosRebuild:           WorkflowRun
    let backendDeleteBranches:WorkflowRun
    let iosDeleteBranches:    WorkflowRun
    let iosRelease:           WorkflowRun
}
