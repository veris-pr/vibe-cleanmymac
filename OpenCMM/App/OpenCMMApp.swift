import SwiftUI

@main
struct OpenCMMApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var adminAuth = AdminAuthManager.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if appState.hasCompletedSetup {
                    MainView()
                } else {
                    SetupView()
                }
            }
            .environmentObject(appState)
            .environmentObject(appState.scanStore)
            .environmentObject(adminAuth)
            .sheet(isPresented: $adminAuth.isShowingPrompt) {
                AdminPasswordSheet(authManager: adminAuth)
            }
            .frame(minWidth: 800, minHeight: 560)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 900, height: 620)

        MenuBarExtra("OpenCMM", systemImage: "leaf") {
            MenuBarView()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.window)
    }
}
