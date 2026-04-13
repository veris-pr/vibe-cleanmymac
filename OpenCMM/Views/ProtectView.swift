import SwiftUI

struct ProtectView: View {
    @StateObject private var viewModel = ProtectViewModel()

    var body: some View {
        VStack(spacing: 0) {
            moduleHeader(
                icon: "shield",
                title: "Protect",
                subtitle: "Neutralize threats before they do any harm"
            )

            Divider()

            if viewModel.isScanning {
                Spacer()
                VStack(spacing: Theme.Spacing.md) {
                    ProgressView()
                        .controlSize(.regular)
                    Text(viewModel.isClamAVInstalled ? "Deep scanning with ClamAV..." : "Scanning for threats...")
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Colors.muted)
                }
                Spacer()
            } else if viewModel.scanComplete {
                // Status banner
                statusBanner
                    .padding(Theme.Spacing.lg)

                if viewModel.threats.isEmpty {
                    Spacer()
                    SuccessStateView(
                        message: "Your Mac is secure",
                        detail: "No threats or privacy risks detected.",
                        action: { Task { await viewModel.scan() } }
                    )
                    Spacer()
                } else {
                    List {
                        ForEach(viewModel.threats) { threat in
                            HStack(spacing: Theme.Spacing.sm) {
                                Toggle("", isOn: Binding(
                                    get: { threat.isSelected },
                                    set: { _ in viewModel.toggleThreat(threat.id) }
                                ))
                                .toggleStyle(.checkbox)
                                .labelsHidden()

                                Image(systemName: threat.threatType.icon)
                                    .font(.system(size: 12))
                                    .foregroundStyle(threat.severity == .critical ? Theme.Colors.destructive : Theme.Colors.muted)
                                    .frame(width: 20)

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(threat.name)
                                            .font(Theme.Font.body)
                                            .foregroundStyle(Theme.Colors.foreground)
                                        Text(threat.threatType.rawValue)
                                            .badgeStyle()
                                    }
                                    Text(threat.path)
                                        .font(Theme.Font.caption)
                                        .foregroundStyle(Theme.Colors.muted.opacity(0.7))
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                Spacer()
                                Text(threat.severity.rawValue)
                                    .font(Theme.Font.caption)
                                    .foregroundStyle(threat.severity == .critical ? Theme.Colors.destructive : Theme.Colors.muted)
                            }
                        }
                    }
                    .listStyle(.inset)

                    actionBar(
                        label: "\(viewModel.threats.filter(\.isSelected).count) threat(s) selected",
                        buttonTitle: "Remove",
                        isWorking: viewModel.isRemoving,
                        action: { Task { await viewModel.removeThreats() } }
                    )
                }
            } else {
                // Dependency banner
                DependencyBanner(
                    toolName: "ClamAV",
                    description: "Industry-standard antivirus engine with millions of malware signatures. Without it, only basic pattern checks run.",
                    isInstalled: viewModel.isClamAVInstalled,
                    isInstalling: viewModel.isInstallingClamAV,
                    installError: viewModel.installError,
                    installAction: { Task { await viewModel.installClamAV() } }
                )
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.md)

                Spacer()
                EmptyStateView(
                    icon: "shield",
                    message: "Check for threats",
                    detail: "Spot and remove malware hiding within seemingly innocent software. Scan for privacy risks like browser history and cookies.",
                    buttonTitle: "Scan",
                    action: { Task { await viewModel.scan() } }
                )
                Spacer()
            }
        }
        .background(Theme.Colors.background)
        .task { await viewModel.checkDependencies() }
    }

    private var statusBanner: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: viewModel.threats.isEmpty ? "checkmark.shield" : "exclamationmark.shield")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(viewModel.threats.isEmpty ? Theme.Colors.success : Theme.Colors.destructive)
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.statusMessage)
                    .font(Theme.Font.heading)
                    .foregroundStyle(Theme.Colors.foreground)
                if !viewModel.threats.isEmpty {
                    Text("\(viewModel.criticalCount) critical · \(viewModel.warningCount) warnings")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Colors.muted)
                }
            }
            Spacer()
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.subtle)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .stroke(Theme.Colors.border, lineWidth: 1)
        )
    }
}
