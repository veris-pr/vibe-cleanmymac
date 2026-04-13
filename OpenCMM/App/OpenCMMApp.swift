import SwiftUI

@main
struct OpenCMMApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()

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
