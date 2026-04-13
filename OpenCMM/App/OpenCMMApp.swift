import SwiftUI

@main
struct OpenCMMApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(appState)
                .frame(minWidth: 800, minHeight: 560)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 900, height: 620)

        MenuBarExtra("OpenCMM", systemImage: "leaf.fill") {
            MenuBarView()
                .environmentObject(appState)
        }
    }
}
