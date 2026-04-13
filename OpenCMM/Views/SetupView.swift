import SwiftUI

/// First-run setup wizard. Lets users choose which optional tools to install.
struct SetupView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = SetupViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: Theme.Spacing.md) {
                Image(systemName: "leaf")
                    .font(.system(size: 40, weight: .thin))
                    .foregroundStyle(Theme.Colors.secondary)

                Text("Welcome to OpenCMM")
                    .font(Theme.Font.largeTitle)
                    .foregroundStyle(Theme.Colors.foreground)

                Text("OpenCMM works great out of the box. For even better results, you can install open-source tools that power advanced features.")
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Colors.muted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 480)
            }
            .padding(.top, Theme.Spacing.xxxl)
            .padding(.bottom, Theme.Spacing.xl)

            // Homebrew check
            if !viewModel.hasHomebrew {
                homebrewBanner
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.bottom, Theme.Spacing.lg)
            }

            // Tools list
            ScrollView {
                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(viewModel.tools) { tool in
                        toolRow(tool)
                    }
                }
                .padding(.horizontal, Theme.Spacing.xl)
            }
            .frame(maxHeight: 320)

            Spacer()

            // Actions
            VStack(spacing: Theme.Spacing.md) {
                if let error = viewModel.errorMessage {
                    ErrorBanner(message: error, onDismiss: { viewModel.errorMessage = nil })
                        .padding(.horizontal, Theme.Spacing.xl)
                }

                if viewModel.isInstalling {
                    VStack(spacing: Theme.Spacing.sm) {
                        ProgressView(value: viewModel.installProgress)
                            .progressViewStyle(.linear)
                            .tint(Theme.Colors.secondary)
                        Text(viewModel.installStatus)
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Colors.muted)
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                }

                HStack(spacing: Theme.Spacing.lg) {
                    Button("Skip for Now") {
                        appState.completeSetup()
                    }
                    .font(Theme.Font.bodyMedium)
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    if viewModel.selectedCount > 0 {
                        Button(action: {
                            Task { await viewModel.installSelected { appState.completeSetup() } }
                        }) {
                            HStack(spacing: 6) {
                                if viewModel.isInstalling {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                                Text(viewModel.isInstalling ? "Installing..." : "Install \(viewModel.selectedCount) Tool\(viewModel.selectedCount == 1 ? "" : "s")")
                                    .font(Theme.Font.bodyMedium)
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(viewModel.isInstalling ? Color.primary.opacity(0.4) : Color.primary.opacity(0.85))
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isInstalling || !viewModel.hasHomebrew)
                    } else {
                        Button("Get Started") {
                            appState.completeSetup()
                        }
                        .font(Theme.Font.bodyMedium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color.primary.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, Theme.Spacing.xxl)
            }
        }
        .background(Theme.Colors.background)
        .task { await viewModel.checkStatus() }
    }

    // MARK: - Subviews

    private var homebrewBanner: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 14))
                .foregroundStyle(Theme.Colors.warning)
            VStack(alignment: .leading, spacing: 2) {
                Text("Homebrew not found")
                    .font(Theme.Font.bodyMedium)
                    .foregroundStyle(Theme.Colors.foreground)
                Text("Install Homebrew first to enable tool installation: brew.sh")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Colors.muted)
            }
            Spacer()
            Button("Open brew.sh") {
                NSWorkspace.shared.open(URL(string: "https://brew.sh")!)
            }
            .font(Theme.Font.caption)
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.warning.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .stroke(Theme.Colors.warning.opacity(0.2), lineWidth: 1)
        )
    }

    private func toolRow(_ tool: SetupViewModel.SetupTool) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            // Checkbox
            Button(action: { viewModel.toggle(tool.info.id) }) {
                Image(systemName: tool.isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 18))
                    .foregroundStyle(tool.isSelected ? Theme.Colors.foreground : Theme.Colors.muted)
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.hasHomebrew || tool.isInstalled)

            // Icon
            Image(systemName: tool.icon)
                .font(.system(size: 14))
                .foregroundStyle(Theme.Colors.secondary)
                .frame(width: 24)

            // Info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(tool.info.name)
                        .font(Theme.Font.bodyMedium)
                        .foregroundStyle(Theme.Colors.foreground)
                    Text(tool.module)
                        .badgeStyle()
                    if tool.isInstalled {
                        Text("Installed")
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Colors.success)
                    }
                }
                Text(tool.info.description)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Colors.muted)
            }

            Spacer()

            if tool.installState == .installing {
                ProgressView()
                    .controlSize(.small)
            } else if tool.installState == .failed {
                Image(systemName: "xmark.circle")
                    .foregroundStyle(Theme.Colors.destructive)
                    .font(.system(size: 14))
            } else if tool.installState == .done {
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(Theme.Colors.success)
                    .font(.system(size: 14))
            }
        }
        .padding(Theme.Spacing.md)
        .background(tool.isSelected && !tool.isInstalled ? Theme.Colors.subtle : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .stroke(tool.isSelected && !tool.isInstalled ? Theme.Colors.border : Color.clear, lineWidth: 1)
        )
    }
}
