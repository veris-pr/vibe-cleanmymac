import SwiftUI

/// Settings view for managing tool installations after initial setup.
struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(spacing: 0) {
            moduleHeader(
                icon: "gearshape",
                title: "Settings",
                subtitle: "Manage tools and preferences"
            )

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    // Tools section
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        HStack {
                            Text("Tool Integrations")
                                .font(Theme.Font.heading)
                                .foregroundStyle(Theme.Colors.foreground)
                            Spacer()
                            if viewModel.isRefreshing {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Button("Refresh") {
                                    Task { await viewModel.refresh() }
                                }
                                .font(Theme.Font.caption)
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }

                        Text("OpenCMM integrates open-source CLI tools for enhanced functionality. Each module works without its tools, but produces better results with them.")
                            .font(Theme.Font.body)
                            .foregroundStyle(Theme.Colors.muted)

                        if !viewModel.hasHomebrew {
                            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                                HStack(spacing: Theme.Spacing.sm) {
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundStyle(Theme.Colors.warning)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Homebrew is required to install tools.")
                                            .font(Theme.Font.body)
                                            .foregroundStyle(Theme.Colors.foreground)
                                        Text("Click below to install it automatically — you'll be prompted for your password.")
                                            .font(Theme.Font.caption)
                                            .foregroundStyle(Theme.Colors.muted)
                                    }
                                    Spacer()
                                    if viewModel.isInstallingHomebrew {
                                        HStack(spacing: 6) {
                                            ProgressView()
                                                .controlSize(.small)
                                            Text("Installing...")
                                                .font(Theme.Font.caption)
                                                .foregroundStyle(Theme.Colors.muted)
                                        }
                                    } else {
                                        Button(action: {
                                            Task { await viewModel.installHomebrew() }
                                        }) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "arrow.down.circle")
                                                    .font(Theme.Font.caption)
                                                Text("Install Homebrew")
                                            }
                                        }
                                        .font(Theme.Font.bodyMedium)
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    }
                                }

                                if let error = viewModel.homebrewInstallError {
                                    HStack(spacing: 4) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(Theme.Font.small)
                                            .foregroundStyle(Theme.Colors.destructive)
                                        Text(error)
                                            .font(Theme.Font.caption)
                                            .foregroundStyle(Theme.Colors.destructive)
                                            .lineLimit(3)
                                    }
                                }
                            }
                            .padding(Theme.Spacing.md)
                            .background(Theme.Colors.warning.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                        }

                        ForEach(viewModel.tools) { tool in
                            settingsToolRow(tool)
                        }
                    }

                    // About section
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("About")
                            .font(Theme.Font.heading)
                            .foregroundStyle(Theme.Colors.foreground)

                        HStack {
                            Text("OpenCMM")
                                .font(Theme.Font.body)
                                .foregroundStyle(Theme.Colors.foreground)
                            Spacer()
                            Text("v\(AppConstants.version)")
                                .font(Theme.Font.mono)
                                .foregroundStyle(Theme.Colors.muted)
                        }

                        HStack {
                            Text("License")
                                .font(Theme.Font.body)
                                .foregroundStyle(Theme.Colors.foreground)
                            Spacer()
                            Text("MIT")
                                .font(Theme.Font.mono)
                                .foregroundStyle(Theme.Colors.muted)
                        }

                        HStack {
                            Text("Source")
                                .font(Theme.Font.body)
                                .foregroundStyle(Theme.Colors.foreground)
                            Spacer()
                            Link("GitHub", destination: URL(string: "https://github.com/veris-pr/vibe-cleanmymac")!)
                                .font(Theme.Font.bodyMedium)
                        }
                    }
                    .padding(Theme.Spacing.lg)
                    .cardStyle()
                }
                .padding(Theme.Spacing.lg)
            }
        }
        .background(Theme.Colors.background)
        .task { await viewModel.refresh() }
    }

    private func settingsToolRow(_ tool: SettingsViewModel.ToolRow) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Theme.Spacing.md) {
                // Status indicator
                Circle()
                    .fill(tool.isInstalled ? Theme.Colors.success : Theme.Colors.muted.opacity(0.3))
                    .frame(width: 8, height: 8)

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(tool.name)
                            .font(Theme.Font.bodyMedium)
                            .foregroundStyle(Theme.Colors.foreground)
                        Text(tool.module)
                            .badgeStyle()
                        sourceBadge(for: tool.source)
                    }
                    HStack(spacing: 4) {
                        Text(tool.description)
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Colors.muted)
                        Text("· tested v\(tool.testedVersion)")
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Colors.muted.opacity(0.6))
                    }
                }

                Spacer()

                if tool.isInstalled {
                    if let version = tool.version {
                        Text(version)
                            .font(Theme.Font.monoSmall)
                            .foregroundStyle(Theme.Colors.muted)
                            .lineLimit(1)
                            .frame(maxWidth: 140, alignment: .trailing)
                    }

                    if tool.managedByUs {
                        if tool.isUninstalling {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Button("Uninstall") {
                                Task { await viewModel.uninstall(tool.id) }
                            }
                            .font(Theme.Font.caption)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                } else {
                    if tool.isInstalling {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Button("Install") {
                            Task { await viewModel.install(tool.id) }
                        }
                        .font(Theme.Font.bodyMedium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(viewModel.hasHomebrew ? Color.primary.opacity(0.85) : Color.primary.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
                        .buttonStyle(.plain)
                        .disabled(!viewModel.hasHomebrew)
                        .help(tool.isCask
                              ? "Installs via Homebrew cask (may require admin password)"
                              : "Installs via Homebrew")
                    }
                }
            }
            .padding(Theme.Spacing.md)

            // Status / error feedback
            if let status = tool.statusText {
                HStack(spacing: 4) {
                    if tool.isInstalling || tool.isUninstalling {
                        ProgressView()
                            .controlSize(.mini)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(Theme.Font.small)
                            .foregroundStyle(Theme.Colors.success)
                    }
                    Text(status)
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Colors.muted)
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.sm)
            }

            if let error = tool.error {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(Theme.Font.small)
                        .foregroundStyle(Theme.Colors.destructive)
                    Text(error)
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Colors.destructive)
                        .lineLimit(2)
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.sm)
            }
        }
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .stroke(tool.error != nil ? Theme.Colors.destructive.opacity(0.3) : Theme.Colors.border, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func sourceBadge(for source: DependencyManager.InstallSource) -> some View {
        switch source {
        case .managedByUs:
            Text("managed")
                .font(Theme.Font.miniMedium)
                .foregroundStyle(Theme.Colors.success.opacity(0.8))
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Theme.Colors.success.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 3))
        case .homebrew:
            Text("homebrew")
                .font(Theme.Font.miniMedium)
                .foregroundStyle(Theme.Colors.muted)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Theme.Colors.muted.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 3))
        case .direct:
            Text("manual")
                .font(Theme.Font.miniMedium)
                .foregroundStyle(Theme.Colors.warning.opacity(0.8))
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Theme.Colors.warning.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 3))
        case .notInstalled:
            EmptyView()
        }
    }
}
