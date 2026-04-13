import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        List(Module.allCases, selection: $appState.selectedModule) { module in
            sidebarItem(for: module)
                .tag(module)
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                Divider()
                HStack {
                    Image(systemName: "leaf.fill")
                        .foregroundStyle(.green)
                    Text("OpenCMM")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("v1.0")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
    }

    private func sidebarItem(for module: Module) -> some View {
        Label {
            Text(module.rawValue)
        } icon: {
            Image(systemName: module.icon)
                .foregroundStyle(module.color)
                .symbolRenderingMode(.hierarchical)
        }
        .padding(.vertical, 2)
    }
}
