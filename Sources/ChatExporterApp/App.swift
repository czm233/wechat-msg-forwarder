import AppKit
import SwiftUI

@main
struct WeChatChatExporterApp: App {
    @StateObject private var store = HistoryStore()

    var body: some Scene {
        WindowGroup {
            Group {
                if store.needsSetup { PermissionSetupView() } else { ContentView() }
            }
                .environmentObject(store)
                .frame(minWidth: 860, minHeight: 560)
                .task { store.launch() }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    store.applicationBecameActive()
                }
        }
        .defaultSize(width: 1080, height: 720)

        Settings {
            Group {
                if store.needsSetup { PermissionSetupView() } else { SettingsView() }
            }
                .environmentObject(store)
                .frame(width: 640)
                .padding(24)
        }
    }
}
