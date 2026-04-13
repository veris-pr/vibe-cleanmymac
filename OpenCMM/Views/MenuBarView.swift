import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 4) {
            Button("Open OpenCMM") {
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first(where: { $0.isKeyWindow == false }) {
                    window.makeKeyAndOrderFront(nil)
                }
            }
            .keyboardShortcut("o")

            Divider()

            Button("Quick Clean") {
                appState.selectedModule = .clean
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
            }

            Button("Check Threats") {
                appState.selectedModule = .protect
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
            }

            Button("System Status") {
                appState.selectedModule = .speed
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
