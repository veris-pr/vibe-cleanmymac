import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 4) {
            Button("Open OpenCMM") {
                activateApp()
            }
            .keyboardShortcut("o")

            Divider()

            Button("Quick Clean") {
                appState.selectedModule = .clean
                activateApp()
            }

            Button("Check Threats") {
                appState.selectedModule = .protect
                activateApp()
            }

            Button("System Status") {
                appState.selectedModule = .speed
                activateApp()
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }

    private func activateApp() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.canBecomeKey }) {
            window.makeKeyAndOrderFront(nil)
        }
    }
}
