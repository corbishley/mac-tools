import Foundation

enum APIClient {

    // MARK: - Helpers

    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let iso8601Basic = ISO8601DateFormatter()

    static func parseDate(_ s: String?) -> Date? {
        guard let s else { return nil }
        return iso8601.date(from: s) ?? iso8601Basic.date(from: s)
    }

    private static func jsonGet(_ url: URL, headers: [String: String]) async throws -> Any {
        var req = URLRequest(url: url)
        headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }
        let (data, _) = try await URLSession.shared.data(for: req)
        return (try? JSONSerialization.jsonObject(with: data)) ?? [String: Any]()
    }

    // MARK: - Claude

    static func fetchClaudeUsage(token: String) async throws -> ClaudeUsage {
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        let (data, _) = try await URLSession.shared.data(for: req)

        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ClaudeUsage(fiveHour: nil, sevenDay: nil, extraUtilization: nil)
        }

        func window(_ key: String, secs: Double) -> WindowUsage? {
            guard let w = obj[key] as? [String: Any],
                  let pct = w["utilization"] as? Double,
                  let resetsAt = parseDate(w["resets_at"] as? String)
            else { return nil }
            return WindowUsage(utilization: pct, resetsAt: resetsAt, windowSecs: secs)
        }

        var extraUtilization: Double? = nil
        if let extra = obj["extra_usage"] as? [String: Any],
           extra["is_enabled"] as? Bool == true,
           let pct = extra["utilization"] as? Double {
            extraUtilization = pct
        }

        return ClaudeUsage(
            fiveHour:         window("five_hour", secs: 5 * 3600),
            sevenDay:         window("seven_day", secs: 7 * 24 * 3600),
            extraUtilization: extraUtilization
        )
    }

    // MARK: - GitHub Actions billing

    static func fetchGitHubActionsUsage(token: String, org: String) async throws -> GitHubActionsUsage {
        let now = Date()
        let cal = Calendar.current
        let year  = cal.component(.year,  from: now)
        let month = cal.component(.month, from: now)

        let headers: [String: String] = [
            "Authorization":      "Bearer \(token)",
            "Accept":             "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
        ]

        var allItems: [[String: Any]] = []
        var nextURL: String? = "https://api.github.com/orgs/\(org)/settings/billing/usage?year=\(year)&month=\(month)&per_page=100"

        while let urlStr = nextURL {
            var req = URLRequest(url: URL(string: urlStr)!)
            headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }
            let (data, resp) = try await URLSession.shared.data(for: req)
            nextURL = (resp as? HTTPURLResponse)
                .flatMap { $0.value(forHTTPHeaderField: "Link") }
                .flatMap(parseLinkNext)
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let items = obj["usageItems"] as? [[String: Any]] {
                allItems.append(contentsOf: items)
            } else {
                nextURL = nil
            }
        }

        let multipliers: [String: Double] = ["UBUNTU": 1, "WINDOWS": 2, "MACOS": 10]
        var raw:    [String: Double] = [:]
        var billed: Double = 0

        for item in allItems {
            guard item["product"] as? String == "actions" else { continue }
            let qty = (item["quantity"] as? Double) ?? Double(item["quantity"] as? Int ?? 0)
            let sku = (item["sku"] as? String ?? "").lowercased()
            let key: String
            if      sku.contains("linux")   { key = "UBUNTU"  }
            else if sku.contains("mac")     { key = "MACOS"   }
            else if sku.contains("windows") { key = "WINDOWS" }
            else { key = item["sku"] as? String ?? "Other" }
            raw[key, default: 0] += qty
            billed += qty * (multipliers[key] ?? 1)
        }

        return GitHubActionsUsage(totalMinutes: billed, includedMinutes: 2000, breakdown: raw)
    }

    private static func parseLinkNext(_ header: String) -> String? {
        for part in header.components(separatedBy: ",") {
            let comps = part.components(separatedBy: ";").map { $0.trimmingCharacters(in: .whitespaces) }
            guard comps.count == 2,
                  comps[1] == #"rel="next""#,
                  comps[0].hasPrefix("<"), comps[0].hasSuffix(">")
            else { continue }
            return String(comps[0].dropFirst().dropLast())
        }
        return nil
    }

    // MARK: - Render build minutes

    static func fetchRenderBuildMinutes(apiKey: String) async throws -> RenderBuildUsage {
        let headers = renderHeaders(apiKey)
        guard let obj = try await jsonGet(URL(string: "https://api.render.com/v1/services?limit=100")!, headers: headers) as? [[String: Any]] else {
            return RenderBuildUsage(buildMinutes: 0)
        }

        let cal = Calendar.current
        let now = Date()
        var c = cal.dateComponents([.year, .month], from: now)
        c.day = 1
        let monthStart = cal.date(from: c) ?? now

        var totalMs: Int64 = 0
        try await withThrowingTaskGroup(of: Int64.self) { group in
            for item in obj {
                let svc = item["service"] as? [String: Any] ?? item
                guard let id = svc["id"] as? String else { continue }
                group.addTask { try await renderServiceMs(apiKey: apiKey, id: id, monthStart: monthStart) }
            }
            for try await ms in group { totalMs += ms }
        }
        return RenderBuildUsage(buildMinutes: Int(totalMs / 60_000))
    }

    private static func renderServiceMs(apiKey: String, id: String, monthStart: Date) async throws -> Int64 {
        let url = URL(string: "https://api.render.com/v1/services/\(id)/deploys?limit=100")!
        guard let items = try await jsonGet(url, headers: renderHeaders(apiKey)) as? [[String: Any]] else { return 0 }
        var ms: Int64 = 0
        for item in items {
            let d = item["deploy"] as? [String: Any] ?? item
            guard let st = parseDate(d["startedAt"] as? String ?? d["createdAt"] as? String),
                  let ft = parseDate(d["finishedAt"] as? String),
                  st >= monthStart
            else { continue }
            let raw = max(0, Int64(ft.timeIntervalSince(st) * 1000))
            ms += ((raw + 59_999) / 60_000) * 60_000
        }
        return ms
    }

    private static func renderHeaders(_ key: String) -> [String: String] {
        ["Authorization": "Bearer \(key)", "Accept": "application/json"]
    }

    // MARK: - Neon (shared project fetch)

    static func fetchNeonProjects(apiKey: String) async throws -> [[String: Any]] {
        let headers = ["Authorization": "Bearer \(apiKey)"]
        let base = "https://console.neon.tech/api/v2"

        let (obj1, code1) = try await neonGet("\(base)/projects?limit=100", headers: headers)
        if code1 == 200, let projs = (obj1 as? [String: Any])?["projects"] as? [[String: Any]] {
            return projs
        }

        let (orgsObj, _) = try await neonGet("\(base)/users/me/organizations", headers: headers)
        var all: [[String: Any]] = []
        if let orgs = (orgsObj as? [String: Any])?["organizations"] as? [[String: Any]] {
            for org in orgs {
                guard let orgId = org["id"] as? String else { continue }
                let (pObj, _) = try await neonGet("\(base)/projects?limit=100&org_id=\(orgId)", headers: headers)
                if let projs = (pObj as? [String: Any])?["projects"] as? [[String: Any]] {
                    all.append(contentsOf: projs)
                }
            }
        }
        return all
    }

    private static func neonGet(_ urlStr: String, headers: [String: String]) async throws -> (Any, Int) {
        var req = URLRequest(url: URL(string: urlStr)!)
        headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        return ((try? JSONSerialization.jsonObject(with: data)) ?? [:], code)
    }

    // MARK: - Neon usage (AILimitsWidget)

    static func fetchNeonUsage(apiKey: String) async throws -> [NeonProjectUsage] {
        let projects = try await fetchNeonProjects(apiKey: apiKey)
        return try await withThrowingTaskGroup(of: NeonProjectUsage.self) { group in
            for p in projects {
                group.addTask { try await buildNeonProjectUsage(apiKey: apiKey, project: p) }
            }
            var result: [NeonProjectUsage] = []
            for try await u in group { result.append(u) }
            return result.sorted { $0.name.lowercased() < $1.name.lowercased() }
        }
    }

    private static func buildNeonProjectUsage(apiKey: String, project: [String: Any]) async throws -> NeonProjectUsage {
        let id   = project["id"]   as? String ?? ""
        let name = project["name"] as? String ?? id
        let computeSecs   = (project["compute_time_seconds"] as? Double) ?? 0
        let transferBytes = Int64((project["data_transfer_bytes"] as? Double) ?? 0)
        let periodStart   = parseDate(project["consumption_period_start"] as? String)
        let periodEnd     = parseDate(project["consumption_period_end"]   as? String)

        let headers = ["Authorization": "Bearer \(apiKey)"]
        let url = URL(string: "https://console.neon.tech/api/v2/projects/\(id)/branches")!
        let (branchObj, _) = try await neonGet(url.absoluteString, headers: headers)
        var storageBytes: Int64 = 0
        if let branches = (branchObj as? [String: Any])?["branches"] as? [[String: Any]] {
            storageBytes = branches.reduce(0) { $0 + Int64(($1["logical_size"] as? Double) ?? 0) }
        }

        return NeonProjectUsage(id: id, name: name, computeTimeSecs: computeSecs,
                                storageBytes: storageBytes, transferBytes: transferBytes,
                                periodStart: periodStart, periodEnd: periodEnd)
    }

    // MARK: - Cloudflare

    static func fetchCloudflareUsage(token: String) async throws -> CloudflareUsage {
        let headers = ["Authorization": "Bearer \(token)"]
        let base = "https://api.cloudflare.com/client/v4"

        guard let accounts = (try await jsonGet(URL(string: "\(base)/accounts?per_page=1")!, headers: headers) as? [String: Any])?["result"] as? [[String: Any]],
              let accountId = accounts.first?["id"] as? String
        else { return CloudflareUsage(pagesBuilds: 0, workersRequests: 0) }

        let now = Date()
        let cal = Calendar.current
        var c = cal.dateComponents([.year, .month], from: now)
        c.day = 1
        let monthStart = cal.date(from: c) ?? now

        let pagesObj = try await jsonGet(URL(string: "\(base)/accounts/\(accountId)/pages/projects?per_page=100")!, headers: headers)
        var totalBuilds = 0
        if let projects = (pagesObj as? [String: Any])?["result"] as? [[String: Any]] {
            for proj in projects {
                guard let pname = proj["name"] as? String else { continue }
                let deploys = try await jsonGet(URL(string: "\(base)/accounts/\(accountId)/pages/projects/\(pname)/deployments?per_page=100")!, headers: headers)
                if let list = (deploys as? [String: Any])?["result"] as? [[String: Any]] {
                    for d in list {
                        if let dt = parseDate(d["created_on"] as? String), dt >= monthStart {
                            totalBuilds += 1
                        }
                    }
                }
            }
        }

        let dayStart = cal.startOfDay(for: now)
        let dayEnd   = cal.date(byAdding: .day, value: 1, to: dayStart) ?? now
        let startStr = ISO8601DateFormatter().string(from: dayStart)
        let endStr   = ISO8601DateFormatter().string(from: dayEnd)

        let gql = #"{"query":"{ viewer { accounts(filter: {accountTag: \""# + accountId + #"\"}) { workersInvocationsAdaptive(limit: 10000 filter: {datetime_geq: \""# + startStr + #"\", datetime_leq: \""# + endStr + #"\"}) { sum { requests } } } } }"}"#

        var gqlReq = URLRequest(url: URL(string: "\(base)/graphql")!)
        gqlReq.httpMethod = "POST"
        gqlReq.setValue("Bearer \(token)",    forHTTPHeaderField: "Authorization")
        gqlReq.setValue("application/json",   forHTTPHeaderField: "Content-Type")
        gqlReq.httpBody = gql.data(using: .utf8)
        var workersRequests = 0
        if let (gqlData, _) = try? await URLSession.shared.data(for: gqlReq),
           let gqlObj  = try? JSONSerialization.jsonObject(with: gqlData) as? [String: Any],
           let viewer  = (gqlObj["data"] as? [String: Any])?["viewer"] as? [String: Any],
           let accts   = viewer["accounts"] as? [[String: Any]] {
            for acct in accts {
                for w in (acct["workersInvocationsAdaptive"] as? [[String: Any]]) ?? [] {
                    workersRequests += (w["sum"] as? [String: Any])?["requests"] as? Int ?? 0
                }
            }
        }

        return CloudflareUsage(pagesBuilds: totalBuilds, workersRequests: workersRequests)
    }

    // MARK: - GitHub workflow run (AIBuildsWidget)

    static func fetchWorkflowRun(token: String, org: String, repo: String,
                                  workflow: String, titleFilter: String? = nil) async -> WorkflowRun {
        let perPage = titleFilter != nil ? 20 : 1
        guard let url = URL(string: "https://api.github.com/repos/\(org)/\(repo)/actions/workflows/\(workflow)/runs?per_page=\(perPage)") else {
            return .unknown
        }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)",             forHTTPHeaderField: "Authorization")
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("2022-11-28",                  forHTTPHeaderField: "X-GitHub-Api-Version")

        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let obj  = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let runs = obj["workflow_runs"] as? [[String: Any]]
        else { return .unknown }

        let run: [String: Any]?
        if let filter = titleFilter {
            run = runs.first { ($0["display_title"] as? String ?? "").contains(filter) }
        } else {
            run = runs.first
        }
        guard let run else { return .noRuns }

        let status     = run["status"]     as? String ?? ""
        let conclusion = run["conclusion"] as? String ?? ""
        let createdAt  = parseDate(run["created_at"] as? String)

        let c: WorkflowConclusion
        if ["in_progress", "queued", "waiting", "requested", "pending"].contains(status) {
            c = .inProgress
        } else if conclusion == "success"            { c = .success        }
        else if conclusion == "timed_out"            { c = .timedOut       }
        else if conclusion == "startup_failure"      { c = .startupFailure }
        else if conclusion == "failure"              { c = .failure        }
        else if conclusion == "cancelled"            { c = .cancelled      }
        else if conclusion.isEmpty && status.isEmpty { c = .noRuns         }
        else                                         { c = .unknown        }

        return WorkflowRun(conclusion: c, createdAt: createdAt)
    }

    // MARK: - Render service status (AIBuildsWidget)

    static func fetchRenderServices(apiKey: String) async throws -> [RenderService] {
        let headers = renderHeaders(apiKey)
        guard let items = try await jsonGet(URL(string: "https://api.render.com/v1/services?limit=100")!, headers: headers) as? [[String: Any]] else {
            return []
        }
        return try await withThrowingTaskGroup(of: RenderService?.self) { group in
            for item in items {
                let svc = item["service"] as? [String: Any] ?? item
                group.addTask { try await renderServiceStatus(apiKey: apiKey, svc: svc) }
            }
            var result: [RenderService] = []
            for try await s in group { if let s { result.append(s) } }
            return result.sorted { $0.name.lowercased() < $1.name.lowercased() }
        }
    }

    private static func renderServiceStatus(apiKey: String, svc: [String: Any]) async throws -> RenderService? {
        guard let id   = svc["id"]   as? String,
              let name = svc["name"] as? String else { return nil }
        let url = URL(string: "https://api.render.com/v1/services/\(id)/deploys?limit=1")!
        guard let items = try await jsonGet(url, headers: renderHeaders(apiKey)) as? [[String: Any]],
              let first = items.first
        else { return RenderService(name: name, deployStatus: .unknown, deployAt: nil) }
        let d = first["deploy"] as? [String: Any] ?? first
        let status = RenderDeployStatus(rawValue: d["status"] as? String ?? "") ?? .unknown
        let at     = parseDate(d["updatedAt"] as? String ?? d["createdAt"] as? String)
        return RenderService(name: name, deployStatus: status, deployAt: at)
    }

    // MARK: - Neon endpoints (AIBuildsWidget)

    static func fetchNeonEndpoints(apiKey: String) async throws -> [NeonEndpoint] {
        let projects = try await fetchNeonProjects(apiKey: apiKey)
        return try await withThrowingTaskGroup(of: [NeonEndpoint].self) { group in
            for p in projects {
                group.addTask { try await projectEndpoints(apiKey: apiKey, project: p) }
            }
            var all: [NeonEndpoint] = []
            for try await eps in group { all.append(contentsOf: eps) }
            return all.sorted { $0.projectName.lowercased() < $1.projectName.lowercased() }
        }
    }

    private static func projectEndpoints(apiKey: String, project: [String: Any]) async throws -> [NeonEndpoint] {
        let id   = project["id"]   as? String ?? ""
        let name = project["name"] as? String ?? id
        let headers = ["Authorization": "Bearer \(apiKey)"]
        let base = "https://console.neon.tech/api/v2"

        let (branchObj, _) = try await neonGet("\(base)/projects/\(id)/branches", headers: headers)
        var branchNames: [String: String] = [:]
        if let branches = (branchObj as? [String: Any])?["branches"] as? [[String: Any]] {
            for b in branches {
                if let bid = b["id"] as? String, let bname = b["name"] as? String {
                    branchNames[bid] = bname
                }
            }
        }

        let (epObj, _) = try await neonGet("\(base)/projects/\(id)/endpoints", headers: headers)
        guard let endpoints = (epObj as? [String: Any])?["endpoints"] as? [[String: Any]] else { return [] }

        return endpoints.compactMap { e -> NeonEndpoint? in
            guard e["type"] as? String == "read_write" else { return nil }
            let branch    = branchNames[e["branch_id"] as? String ?? ""] ?? "?"
            let state     = e["current_state"] as? String ?? e["state"] as? String ?? "unknown"
            let updatedAt = parseDate(e["updated_at"] as? String)
            return NeonEndpoint(projectName: name, branch: branch, state: state, updatedAt: updatedAt)
        }
    }
}
