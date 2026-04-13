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
            SmartCareView()
        case .clean:
            CleanView()
        case .protect:
            ProtectView()
        case .speed:
            SpeedView()
        case .update:
            UpdateView()
        case .declutter:
            DeclutterView()
        }
    }
}
