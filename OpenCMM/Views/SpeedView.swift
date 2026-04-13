import SwiftUI

struct SpeedView: View {
    @ObservedObject var viewModel: SpeedViewModel

    var body: some View {
        VStack(spacing: 0) {
            moduleHeader(
                icon: "gauge.with.needle",
                title: "Boost",
                subtitle: "Manage startup items and system info"
            )

            Divider()

            if let error = viewModel.errorMessage {
                ErrorBanner(message: error, onDismiss: { viewModel.errorMessage = nil })
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.md)
            }

            if viewModel.isLoading {
                Spacer()
                VStack(spacing: Theme.Spacing.md) {
                    ProgressView()
                        .controlSize(.regular)
                    Text("Loading system info...")
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Colors.muted)
                }
                Spacer()
            } else if (!viewModel.hostname.isEmpty && viewModel.hostname != "Mac") || !viewModel.loginItems.isEmpty {
                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        // Startup items
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            Text("Startup Items")
                                .font(Theme.Font.heading)
                                .foregroundStyle(Theme.Colors.foreground)
                                .padding(.bottom, Theme.Spacing.xs)

                            if viewModel.loginItems.isEmpty {
                                Text("No startup items found")
                                    .font(Theme.Font.body)
                                    .foregroundStyle(Theme.Colors.muted)
                            } else {
                                ForEach(viewModel.loginItems) { item in
                                    HStack(spacing: Theme.Spacing.sm) {
                                        Circle()
                                            .fill(item.isEnabled ? Theme.Colors.success : Theme.Colors.muted.opacity(0.3))
                                            .frame(width: 6, height: 6)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(item.name)
                                                .font(Theme.Font.body)
                                                .foregroundStyle(Theme.Colors.foreground)
                                                .lineLimit(1)
                                            Text(item.kind.rawValue)
                                                .font(Theme.Font.caption)
                                                .foregroundStyle(Theme.Colors.muted)
                                        }
                                        Spacer()
                                        Button(item.isEnabled ? "Disable" : "Enable") {
                                            Task {
                                                if item.isEnabled {
                                                    await viewModel.disableLoginItem(item)
                                                } else {
                                                    await viewModel.enableLoginItem(item)
                                                }
                                            }
                                        }
                                        .font(Theme.Font.caption)
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    }
                                    .padding(.vertical, 2)
                                    if item.id != viewModel.loginItems.last?.id {
                                        Divider()
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardStyle()
                        .padding(.horizontal, Theme.Spacing.lg)

                        // System details
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text("System")
                                .font(Theme.Font.heading)
                                .foregroundStyle(Theme.Colors.foreground)
                                .padding(.bottom, Theme.Spacing.xs)
                            detailRow("Computer", viewModel.hostname)
                            Divider()
                            detailRow("macOS", viewModel.osVersion)
                            Divider()
                            detailRow("Uptime", Formatters.duration(viewModel.uptime))
                        }
                        .cardStyle()
                        .padding(.horizontal, Theme.Spacing.lg)
                    }
                    .padding(.vertical, Theme.Spacing.lg)
                }
            } else {
                Spacer()
                EmptyStateView(
                    icon: "gauge.with.needle",
                    message: "Manage startup items",
                    detail: "View and manage login items and launch agents that run at startup.",
                    buttonTitle: "Load",
                    action: { Task { await viewModel.loadData() } }
                )
                Spacer()
            }
        }
        .background(Theme.Colors.background)
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Colors.muted)
            Spacer()
            Text(value)
                .font(Theme.Font.bodyMedium)
                .foregroundStyle(Theme.Colors.foreground)
        }
    }
}
