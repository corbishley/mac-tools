import SwiftUI
import WidgetKit

struct SettingsView: View {
    @State private var s = SettingsData.load()

    var body: some View {
        Form {
            Section("GitHub") {
                SecureField("Personal Access Token (repo, actions, org)", text: $s.githubToken)
                TextField("Organisation",  text: $s.githubOrg)
                TextField("Backend repo",  text: $s.backendRepo)
                TextField("iOS repo",      text: $s.iosRepo)
            }

            Section("Render") {
                SecureField("API Key", text: $s.renderApiKey)
            }

            Section("Neon") {
                SecureField("API Key (leave blank to use keychain)", text: $s.neonApiKey)
                KeychainRow(label: "Keychain fallback", value: KeychainHelper.neonApiKey())
            }

            Section("Cloudflare") {
                SecureField("API Token (leave blank to use keychain)", text: $s.cfApiToken)
                KeychainRow(label: "Keychain fallback", value: KeychainHelper.cloudflareApiToken())
            }

            Section("Refresh") {
                Stepper("Every \(s.refreshMins) min\(s.refreshMins == 1 ? "" : "s")",
                        value: $s.refreshMins, in: 1...60)
            }

            Section("Keychain") {
                KeychainRow(label: "Claude OAuth token", value: KeychainHelper.claudeAccessToken())
            }

            Section {
                Button("Save & Reload Widgets") {
                    s.saveToWidgets()
                    WidgetCenter.shared.reloadAllTimelines()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(minWidth: 440, maxWidth: 520)
    }
}

private struct KeychainRow: View {
    let label: String
    let value: String?

    var body: some View {
        LabeledContent(label) {
            if value != nil {
                Label("found", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .labelStyle(.iconOnly)
            } else {
                Label("not found", systemImage: "xmark.circle")
                    .foregroundStyle(.secondary)
                    .labelStyle(.iconOnly)
            }
        }
    }
}

#Preview {
    SettingsView()
}
