import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            List(Module.allCases, selection: $appState.selectedModule) { module in
                sidebarItem(for: module)
                    .tag(module)
            }
            .listStyle(.sidebar)

            Divider()

            HStack(spacing: 6) {
                Image(systemName: "leaf")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.Colors.muted)
                Text("OpenCMM")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Colors.muted)
                Spacer()
                Text("v1.0")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Colors.muted.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private func sidebarItem(for module: Module) -> some View {
        Label {
            Text(module.rawValue)
                .font(Theme.Font.bodyMedium)
        } icon: {
            Image(systemName: module.icon)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Theme.Colors.secondary)
        }
        .padding(.vertical, 1)
    }
}
