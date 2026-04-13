import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var appState: AppState

    private var moduleItems: [Module] {
        Module.allCases.filter { $0 != .settings }
    }

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $appState.selectedModule) {
                Section {
                    ForEach(moduleItems) { module in
                        sidebarItem(for: module)
                            .tag(module)
                    }
                }

                Section {
                    sidebarItem(for: .settings)
                        .tag(Module.settings)
                }
            }
            .listStyle(.sidebar)

            Divider()

            HStack(spacing: 6) {
                Image(systemName: "leaf")
                    .font(Theme.Font.captionMedium)
                    .foregroundStyle(Theme.Colors.muted)
                Text("OpenCMM")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Colors.muted)
                Spacer()
                Text("v\(AppConstants.version)")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Colors.muted.opacity(0.6))
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
        }
    }

    private func sidebarItem(for module: Module) -> some View {
        Label {
            Text(module.rawValue)
                .font(Theme.Font.bodyMedium)
        } icon: {
            Image(systemName: module.icon)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Colors.secondary)
        }
        .padding(.vertical, 1)
    }
}
