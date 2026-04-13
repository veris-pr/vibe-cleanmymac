import SwiftUI

struct ProtectView: View {
    @ObservedObject var viewModel: ProtectViewModel

    var body: some View {
        VStack(spacing: 0) {
            moduleHeader(
                icon: "shield",
                title: "Security",
                subtitle: "Neutralize threats before they do any harm"
            )

            Divider()

            if let error = viewModel.errorMessage {
                ErrorBanner(message: error, onDismiss: { viewModel.errorMessage = nil })
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.md)
            }

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
                    ScrollView {
                        VStack(spacing: 0) {
                            // Threats list
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
                                .padding(.vertical, 4)
                                .padding(.horizontal, Theme.Spacing.lg)
                                .revealInFinderContextMenu(path: threat.path)

                                if threat.id != viewModel.threats.last?.id {
                                    Divider().padding(.horizontal, Theme.Spacing.lg)
                                }
                            }
                        }

                        // System Audit section
                        if let audit = viewModel.auditResult {
                            auditSection(audit)
                                .padding(.top, Theme.Spacing.lg)
                        }
                    }

                    actionBar(
                        label: "\(viewModel.threats.filter(\.isSelected).count) threat(s) selected",
                        buttonTitle: "Remove",
                        isWorking: viewModel.isRemoving,
                        action: { viewModel.showConfirmation = true }
                    )
                }

                // Audit section shown when no threats but audit exists
                if viewModel.threats.isEmpty, let audit = viewModel.auditResult {
                    ScrollView {
                        auditSection(audit)
                    }
                }
            } else {
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
                    buttonTitle: "Start Scan",
                    action: { Task { await viewModel.scan() } }
                )
                Spacer()
            }
        }
        .background(Theme.Colors.background)
        .task {
            await viewModel.checkDependencies()
            viewModel.loadFromStore()
        }
        .confirmationDialog(
            "Remove Selected Threats",
            isPresented: $viewModel.showConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove \(viewModel.threats.filter(\.isSelected).count) threat(s)", role: .destructive) {
                Task { await viewModel.removeThreats() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Selected threats will be moved to Trash. This action cannot be undone.")
        }
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

    private func auditSection(_ audit: AuditResult) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeaderRow(title: "System Audit", trailing: viewModel.isOsqueryInstalled ? "via osquery" : nil)
                .padding(.horizontal, Theme.Spacing.lg)

            // Security status
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: audit.firewallEnabled ? "checkmark.circle" : "xmark.circle")
                        .font(.system(size: 12))
                        .foregroundStyle(audit.firewallEnabled ? Theme.Colors.success : Theme.Colors.warning)
                    Text("Firewall: \(audit.firewallEnabled ? "Enabled" : "Disabled")")
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Colors.foreground)
                }
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: audit.sipEnabled ? "checkmark.circle" : "xmark.circle")
                        .font(.system(size: 12))
                        .foregroundStyle(audit.sipEnabled ? Theme.Colors.success : Theme.Colors.destructive)
                    Text("System Integrity Protection: \(audit.sipEnabled ? "Enabled" : "Disabled")")
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Colors.foreground)
                }
            }
            .cardStyle()
            .padding(.horizontal, Theme.Spacing.lg)

            // Listening ports
            if !audit.listeningPorts.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Listening Ports (\(audit.listeningPorts.count))")
                        .font(Theme.Font.heading)
                        .foregroundStyle(Theme.Colors.foreground)
                    ForEach(audit.listeningPorts.prefix(10)) { port in
                        HStack {
                            Text(":\(port.port)")
                                .font(Theme.Font.mono)
                                .foregroundStyle(Theme.Colors.foreground)
                            Text(port.processName)
                                .font(Theme.Font.body)
                                .foregroundStyle(Theme.Colors.muted)
                            Spacer()
                            Text(port.protocol_)
                                .font(Theme.Font.caption)
                                .foregroundStyle(Theme.Colors.muted)
                        }
                    }
                }
                .cardStyle()
                .padding(.horizontal, Theme.Spacing.lg)
            }

            // Non-Apple launch items
            if !audit.launchItems.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Third-Party Launch Items (\(audit.launchItems.count))")
                        .font(Theme.Font.heading)
                        .foregroundStyle(Theme.Colors.foreground)
                    ForEach(audit.launchItems.prefix(10)) { item in
                        HStack(spacing: Theme.Spacing.sm) {
                            Circle()
                                .fill(item.runAtLoad ? Theme.Colors.success : Theme.Colors.muted.opacity(0.3))
                                .frame(width: 6, height: 6)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.name)
                                    .font(Theme.Font.body)
                                    .foregroundStyle(Theme.Colors.foreground)
                                    .lineLimit(1)
                                Text(item.path)
                                    .font(Theme.Font.caption)
                                    .foregroundStyle(Theme.Colors.muted)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer()
                        }
                    }
                }
                .cardStyle()
                .padding(.horizontal, Theme.Spacing.lg)
            }

            // Browser extensions
            if !audit.browserExtensions.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Browser Extensions (\(audit.browserExtensions.count))")
                        .font(Theme.Font.heading)
                        .foregroundStyle(Theme.Colors.foreground)
                    ForEach(audit.browserExtensions.prefix(10)) { ext in
                        HStack {
                            Text(ext.name)
                                .font(Theme.Font.body)
                                .foregroundStyle(Theme.Colors.foreground)
                            Spacer()
                            Text(ext.browser)
                                .badgeStyle()
                        }
                    }
                }
                .cardStyle()
                .padding(.horizontal, Theme.Spacing.lg)
            }
        }
        .padding(.bottom, Theme.Spacing.lg)
    }
}
