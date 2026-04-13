import SwiftUI

struct MainView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            contentView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch appState.selectedModule {
        case .smartCare:
            SmartCareView(viewModel: appState.smartCareVM)
        case .clean:
            CleanView(viewModel: appState.cleanVM)
        case .protect:
            ProtectView(viewModel: appState.protectVM)
        case .speed:
            SpeedView(viewModel: appState.speedVM)
        case .update:
            UpdateView(viewModel: appState.updateVM)
        case .declutter:
            DeclutterView(viewModel: appState.declutterVM)
        case .spaceLens:
            SpaceLensView(viewModel: appState.spaceLensVM)
        case .settings:
            SettingsView()
        }
    }
}
