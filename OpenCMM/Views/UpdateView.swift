import SwiftUI

struct UpdateView: View {
    @ObservedObject var viewModel: UpdateViewModel

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
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

            // MARK: - Body
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
                        detail: nil
                    )
                    Spacer()
                } else {
                    updatesList
                }
            } else {
                VStack(spacing: Theme.Spacing.sm) {
                    DependencyBanner(
                        toolName: "Homebrew",
                        description: "Package manager for macOS CLI tools and apps",
                        isInstalled: viewModel.isHomebrewInstalled,
                        isInstalling: viewModel.isInstallingHomebrew,
                        installError: viewModel.installError,
                        installAction: { Task { await viewModel.installHomebrew() } }
                    )

                    DependencyBanner(
                        toolName: "mas",
                        description: "Mac App Store CLI for checking and updating apps",
                        isInstalled: viewModel.isMasInstalled,
                        isInstalling: viewModel.isInstallingMas,
                        installError: viewModel.installError,
                        installAction: { Task { await viewModel.installMas() } },
                        version: viewModel.masVersion
                    )
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.md)

                Spacer()
                EmptyStateView(
                    icon: "arrow.down.circle",
                    message: "Check for updates",
                    detail: "Update all your Homebrew and App Store apps to improve security and stability."
                )
                Spacer()
            }

            // MARK: - Footer
            if viewModel.isChecking {
                footerBar {
                    ghostButton("Stop") { viewModel.cancelCheck() }
                }
            } else if viewModel.checkComplete && !viewModel.updates.isEmpty {
                actionBar(
                    label: "\(viewModel.selectedCount) of \(viewModel.updateCount) selected",
                    buttonTitle: "Update All",
                    isWorking: viewModel.isUpdating,
                    action: { viewModel.showConfirmation = true },
                    secondaryTitle: "Rescan",
                    secondaryAction: { viewModel.startCheckForUpdates() }
                )
            } else {
                footerBar {
                    ScanButton(title: viewModel.checkComplete ? "Rescan" : "Start Scan") {
                        viewModel.startCheckForUpdates()
                    }
                }
            }
        }
        .background(Theme.Colors.background)
        .task {
            await viewModel.checkDependencies()
            viewModel.loadFromStore()
        }
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

    // MARK: - Updates List

    private var updatesList: some View {
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
    }
}
