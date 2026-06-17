import WidgetKit
import Foundation

struct AILimitsProvider: TimelineProvider {
    func placeholder(in context: Context) -> AILimitsEntry {
        AILimitsEntry(date: Date(), claude: nil, github: nil, render: nil,
                      neonProjects: [], cloudflare: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (AILimitsEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AILimitsEntry>) -> Void) {
        Task {
            let entry   = await fetchEntry()
            let s       = SettingsData.load()
            let refresh = Date().addingTimeInterval(Double(s.resolvedRefreshMins) * 60)
            completion(Timeline(entries: [entry], policy: .after(refresh)))
        }
    }

    private func fetchEntry() async -> AILimitsEntry {
        let s           = SettingsData.load()
        let claudeToken = s.resolvedClaudeToken() ?? KeychainHelper.claudeAccessToken()
        let neonKey     = s.resolvedNeonKey() ?? KeychainHelper.neonApiKey()
        let cfToken     = s.resolvedCFToken() ?? KeychainHelper.cloudflareApiToken()

        async let claude = fetchClaude(token: claudeToken)
        async let github = fetchGitHub(token: s.githubToken, org: s.githubOrg)
        async let render = fetchRender(key: s.renderApiKey)
        async let neon   = fetchNeon(key: neonKey)
        async let cf     = fetchCloudflare(token: cfToken)

        return AILimitsEntry(
            date:         Date(),
            claude:       await claude,
            github:       await github,
            render:       await render,
            neonProjects: await neon,
            cloudflare:   await cf
        )
    }

    private func fetchClaude(token: String?) async -> ClaudeUsage? {
        guard let token else { return nil }
        return try? await APIClient.fetchClaudeUsage(token: token)
    }

    private func fetchGitHub(token: String, org: String) async -> GitHubActionsUsage? {
        guard !token.isEmpty, !org.isEmpty else { return nil }
        return try? await APIClient.fetchGitHubActionsUsage(token: token, org: org)
    }

    private func fetchRender(key: String) async -> RenderBuildUsage? {
        guard !key.isEmpty else { return nil }
        return try? await APIClient.fetchRenderBuildMinutes(apiKey: key)
    }

    private func fetchNeon(key: String?) async -> [NeonProjectUsage] {
        guard let key else { return [] }
        return (try? await APIClient.fetchNeonUsage(apiKey: key)) ?? []
    }

    private func fetchCloudflare(token: String?) async -> CloudflareUsage? {
        guard let token else { return nil }
        return try? await APIClient.fetchCloudflareUsage(token: token)
    }
}
