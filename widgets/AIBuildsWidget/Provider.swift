import WidgetKit
import Foundation

let environments = ["production", "sandbox01"]

struct AIBuildsProvider: TimelineProvider {
    func placeholder(in context: Context) -> AIBuildsEntry {
        AIBuildsEntry(
            date: Date(),
            environments: [],
            renderServices: [],
            neonEndpoints: [],
            backendRebuild: .noRuns,
            iosRebuild: .noRuns,
            backendDeleteBranches: .noRuns,
            iosDeleteBranches: .noRuns
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (AIBuildsEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AIBuildsEntry>) -> Void) {
        Task {
            let entry   = await fetchEntry()
            let refresh = Date().addingTimeInterval(Double(SettingsData.load().resolvedRefreshMins) * 60)
            completion(Timeline(entries: [entry], policy: .after(refresh)))
        }
    }

    // MARK: - Fetch

    private func fetchEntry() async -> AIBuildsEntry {
        let s         = SettingsData.load()
        let token     = s.githubToken
        let org       = s.githubOrg
        let backend   = s.resolvedBackendRepo
        let ios       = s.resolvedIosRepo
        let renderKey = s.renderApiKey
        let neonKey   = s.resolvedNeonKey() ?? KeychainHelper.neonApiKey()

        guard !token.isEmpty, !org.isEmpty else {
            return AIBuildsEntry(date: Date(), environments: [], renderServices: [],
                                 neonEndpoints: [], backendRebuild: .noRuns, iosRebuild: .noRuns,
                                 backendDeleteBranches: .noRuns, iosDeleteBranches: .noRuns)
        }

        async let envStatuses = fetchEnvironments(token: token, org: org, backend: backend, ios: ios)
        async let renderSvcs  = fetchRender(key: renderKey)
        async let neonEps     = fetchNeon(key: neonKey)
        async let beRebuild   = APIClient.fetchWorkflowRun(token: token, org: org, repo: backend, workflow: "rebuild-sandboxes.yml")
        async let iosRebuild  = APIClient.fetchWorkflowRun(token: token, org: org, repo: ios,     workflow: "rebuild-sandboxes.yml")
        async let beDelete    = APIClient.fetchWorkflowRun(token: token, org: org, repo: backend, workflow: "delete-merged-branches.yml")
        async let iosDelete   = APIClient.fetchWorkflowRun(token: token, org: org, repo: ios,     workflow: "delete-merged-branches.yml")

        return AIBuildsEntry(
            date:                  Date(),
            environments:          await envStatuses,
            renderServices:        await renderSvcs,
            neonEndpoints:         await neonEps,
            backendRebuild:        await beRebuild,
            iosRebuild:            await iosRebuild,
            backendDeleteBranches: await beDelete,
            iosDeleteBranches:     await iosDelete
        )
    }

    private func fetchEnvironments(token: String, org: String, backend: String, ios: String) async -> [EnvironmentStatus] {
        await withTaskGroup(of: EnvironmentStatus.self) { group in
            for env in environments {
                group.addTask {
                    async let beCI      = APIClient.fetchWorkflowRun(token: token, org: org, repo: backend, workflow: "ci.yml",                   titleFilter: env)
                    async let beCD      = APIClient.fetchWorkflowRun(token: token, org: org, repo: backend, workflow: "cd.yml",                   titleFilter: env)
                    async let beMigrate = APIClient.fetchWorkflowRun(token: token, org: org, repo: backend, workflow: "migrate-database.yml",    titleFilter: env)
                    async let iosCI     = APIClient.fetchWorkflowRun(token: token, org: org, repo: ios,     workflow: "ci.yml",                   titleFilter: env)
                    async let iosCD     = APIClient.fetchWorkflowRun(token: token, org: org, repo: ios,     workflow: "cd.yml",                   titleFilter: env)
                    return EnvironmentStatus(
                        name:          env,
                        backendCI:     await beCI,
                        backendCD:     await beCD,
                        backendMigrate:await beMigrate,
                        iosCI:         await iosCI,
                        iosCD:         await iosCD
                    )
                }
            }
            var result: [EnvironmentStatus] = []
            for await s in group { result.append(s) }
            return result.sorted { $0.name < $1.name }
        }
    }

    private func fetchRender(key: String) async -> [RenderService] {
        guard !key.isEmpty else { return [] }
        return (try? await APIClient.fetchRenderServices(apiKey: key)) ?? []
    }

    private func fetchNeon(key: String?) async -> [NeonEndpoint] {
        guard let key else { return [] }
        return (try? await APIClient.fetchNeonEndpoints(apiKey: key)) ?? []
    }
}
