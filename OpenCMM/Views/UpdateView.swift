import SwiftUI

struct UpdateView: View {
    @StateObject private var viewModel = UpdateViewModel()

    var body: some View {
        VStack(spacing: 0) {
            moduleHeader(
                icon: "arrow.down.circle",
                title: "Update",
                subtitle: "Keep your apps up to date"
            )

            Divider()

            if viewModel.isChecking {
                Spacer()
                VStack(spacing: Theme.Spacing.md) {
                    ProgressView()
                        .controlSize(.regular)
                    Text("Checking for updates...")
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Colors.muted)
                }
                Spacer()
            } else if viewModel.checkComplete {
                if viewModel.updates.isEmpty {
                    Spacer()
                    SuccessStateView(
                        message: "All apps are up to date",
                        detail: nil,
                        action: { Task { await viewModel.checkForUpdates() } }
                    )
                    Spacer()
                } else {
                    List {
                        ForEach(viewModel.updates) { app in
                            HStack(spacing: Theme.Spacing.sm) {
                                Toggle("", isOn: Binding(
                                    get: { app.isSelected },
                                    set: { _ in viewModel.toggleApp(app.id) }
                                ))
                                .toggleStyle(.checkbox)
                                .labelsHidden()

                                Image(systemName: "shippingbox")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundStyle(Theme.Colors.muted)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(app.name)
                                        .font(Theme.Font.bodyMedium)
                                        .foregroundStyle(Theme.Colors.foreground)
                                    Text("\(app.currentVersion) → \(app.availableVersion)")
                                        .font(Theme.Font.caption)
                                        .foregroundStyle(Theme.Colors.muted)
                                }
                                Spacer()

                                Text(app.source.rawValue)
                                    .badgeStyle()

                                Button("Update") {
                                    Task { await viewModel.updateSingle(app) }
                                }
                                .font(Theme.Font.caption)
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            .padding(.vertical, 3)
                        }
                    }
                    .listStyle(.inset)

                    actionBar(
                        label: "\(viewModel.selectedCount) of \(viewModel.updateCount) selected",
                        buttonTitle: "Update All",
                        isWorking: viewModel.isUpdating,
                        action: { Task { await viewModel.updateSelected() } }
                    )
                }
            } else {
                Spacer()
                EmptyStateView(
                    icon: "arrow.down.circle",
                    message: "Check for updates",
                    detail: "Update all your Homebrew apps to improve security and stability.",
                    buttonTitle: "Check for Updates",
                    action: { Task { await viewModel.checkForUpdates() } }
                )
                Spacer()
            }
        }
        .background(Theme.Colors.background)
    }
}
