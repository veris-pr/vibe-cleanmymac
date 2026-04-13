import SwiftUI

struct UpdateView: View {
    @ObservedObject var viewModel: UpdateViewModel

    var body: some View {
        VStack(spacing: 0) {
            moduleHeader(
                icon: "arrow.down.circle",
                title: "Update",
                subtitle: "Keep your apps up to date"
            )

            Divider()

            if let error = viewModel.errorMessage {
                ErrorBanner(message: error, onDismiss: { viewModel.errorMessage = nil })
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.md)
            }

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

                                Image(systemName: app.source == .appStore ? "app.badge" : "shippingbox")
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
                        action: { viewModel.showConfirmation = true }
                    )
                }
            } else {
                // Dependency banners
                VStack(spacing: Theme.Spacing.sm) {
                    DependencyBanner(
                        toolName: "Homebrew",
                        description: "Package manager required for updating Homebrew apps and installing tools.",
                        isInstalled: viewModel.isHomebrewInstalled,
                        isInstalling: false,
                        installError: nil,
                        installAction: {}
                    )

                    DependencyBanner(
                        toolName: "mas",
                        description: "Mac App Store CLI for checking and updating App Store apps.",
                        isInstalled: viewModel.isMasInstalled,
                        isInstalling: false,
                        installError: nil,
                        installAction: {}
                    )
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.md)

                Spacer()
                EmptyStateView(
                    icon: "arrow.down.circle",
                    message: "Check for updates",
                    detail: "Update all your Homebrew and App Store apps to improve security and stability.",
                    buttonTitle: "Check for Updates",
                    action: { Task { await viewModel.checkForUpdates() } }
                )
                Spacer()
            }
        }
        .background(Theme.Colors.background)
        .task { await viewModel.checkDependencies() }
        .confirmationDialog(
            "Update Selected Apps",
            isPresented: $viewModel.showConfirmation,
            titleVisibility: .visible
        ) {
            Button("Update \(viewModel.selectedCount) app(s)") {
                Task { await viewModel.updateSelected() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The selected apps will be updated to their latest versions.")
        }
    }
}
