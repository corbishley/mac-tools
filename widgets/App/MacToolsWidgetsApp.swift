import SwiftUI
import WidgetKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var tokenTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        refreshClaudeToken()
        // Re-check every 20 minutes so widgets never go more than one cycle stale
        tokenTimer = Timer.scheduledTimer(withTimeInterval: 20 * 60, repeats: true) { [weak self] _ in
            self?.refreshClaudeToken()
        }
    }

    private func refreshClaudeToken() {
        guard let fresh = KeychainHelper.claudeAccessToken() else { return }
        var s = SettingsData.load()
        guard s.claudeToken != fresh else { return }
        s.claudeToken = fresh
        s.saveToWidgets()
        WidgetCenter.shared.reloadTimelines(ofKind: "AILimitsWidget")
    }
}

@main
struct MacToolsWidgetsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup("Mac Tools — Settings", id: "settings") {
            SettingsView()
        }
        .windowResizability(.contentSize)

        MenuBarExtra("Mac Tools", systemImage: "chart.bar.fill") {
            MenuBarItems()
        }
    }
}

struct MenuBarItems: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Open Settings…") {
            openWindow(id: "settings")
            NSApp.activate(ignoringOtherApps: true)
        }

        Divider()

        Button("Reload Widgets") {
            WidgetCenter.shared.reloadAllTimelines()
        }

        Divider()

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
    }
}
