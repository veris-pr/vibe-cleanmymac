import SwiftUI

struct SpeedView: View {
    @ObservedObject var viewModel: SpeedViewModel

    var body: some View {
        VStack(spacing: 0) {
            moduleHeader(
                icon: "gauge.with.needle",
                title: "Boost",
                subtitle: "Make your slow Mac fast again"
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
            } else if let info = viewModel.systemInfo {
                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        // Dependency banner for mactop
                        if !viewModel.isMactopInstalled {
                            DependencyBanner(
                                toolName: "mactop",
                                description: "Apple Silicon performance monitor for GPU usage, temperature, and per-core metrics.",
                                isInstalled: false,
                                isInstalling: viewModel.isMactopInstalling,
                                installError: viewModel.mactopInstallError,
                                installAction: { Task { await viewModel.installMactop() } }
                            )
                            .padding(.horizontal, Theme.Spacing.lg)
                        }

                        // Gauges
                        HStack(spacing: Theme.Spacing.md) {
                            gaugeCard(
                                label: "CPU",
                                value: Formatters.percentage(info.cpuUsage),
                                progress: info.cpuUsage / 100.0
                            )
                            gaugeCard(
                                label: "Memory",
                                value: "\(Formatters.fileSize(info.memoryUsed)) / \(Formatters.fileSize(info.memoryTotal))",
                                progress: info.memoryUsedPercent / 100.0
                            )
                            gaugeCard(
                                label: "Disk",
                                value: "\(Formatters.fileSize(info.diskFree)) free",
                                progress: info.diskUsedPercent / 100.0
                            )
                        }
                        .padding(.horizontal, Theme.Spacing.lg)

                        // GPU & Temperature from mactop
                        if let metrics = viewModel.mactopMetrics {
                            HStack(spacing: Theme.Spacing.md) {
                                if metrics.gpuUsage > 0 {
                                    gaugeCard(
                                        label: "GPU",
                                        value: Formatters.percentage(metrics.gpuUsage),
                                        progress: metrics.gpuUsage / 100.0
                                    )
                                }
                                if metrics.cpuTemp > 0 {
                                    temperatureCard(label: "CPU Temp", value: metrics.cpuTemp)
                                }
                                if metrics.gpuTemp > 0 {
                                    temperatureCard(label: "GPU Temp", value: metrics.gpuTemp)
                                }
                            }
                            .padding(.horizontal, Theme.Spacing.lg)
                        }

                        // Quick actions grouped under Memory
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            Text("Memory")
                                .font(Theme.Font.heading)
                                .foregroundStyle(Theme.Colors.foreground)

                            HStack(spacing: Theme.Spacing.sm) {
                                Button(action: { Task { await viewModel.purgeMemory() } }) {
                                    Text(viewModel.isPurging ? "Freeing..." : "Free Up RAM")
                                        .font(Theme.Font.bodyMedium)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.regular)
                                .disabled(viewModel.isPurging)

                                Button(action: { Task { await viewModel.refresh() } }) {
                                    Text("Refresh")
                                        .font(Theme.Font.bodyMedium)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.regular)

                                Spacer()

                                Toggle(isOn: Binding(
                                    get: { viewModel.isAutoRefresh },
                                    set: { _ in viewModel.toggleAutoRefresh() }
                                )) {
                                    Text("Auto-refresh")
                                        .font(Theme.Font.bodyMedium)
                                }
                                .toggleStyle(.switch)
                                .controlSize(.small)
                            }
                        }
                        .cardStyle()
                        .padding(.horizontal, Theme.Spacing.lg)

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
                            detailRow("Computer", info.hostname)
                            Divider()
                            detailRow("macOS", info.osVersion)
                            Divider()
                            detailRow("Uptime", Formatters.duration(info.uptime))
                            if let metrics = viewModel.mactopMetrics {
                                Divider()
                                detailRow("Thermal State", metrics.thermalState.capitalized)
                                if metrics.systemPower > 0 {
                                    Divider()
                                    detailRow("System Power", String(format: "%.1f W", metrics.systemPower))
                                }
                            }
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
                    message: "Analyze performance",
                    detail: "View real-time CPU, memory, and disk usage. Manage startup items and free up RAM.",
                    buttonTitle: "Start Scan",
                    action: { Task { await viewModel.loadData() } }
                )
                Spacer()
            }
        }
        .background(Theme.Colors.background)
        .task {
            viewModel.loadFromStore()
            if viewModel.systemInfo == nil {
                return  // show empty state — don't auto-scan
            }
        }
    }

    private func gaugeCard(label: String, value: String, progress: Double) -> some View {
        VStack(spacing: Theme.Spacing.sm) {
            ProgressRing(progress: progress, size: 64, lineWidth: 4, thresholds: true)
            Text(label)
                .font(Theme.Font.heading)
                .foregroundStyle(Theme.Colors.foreground)
            Text(value)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Colors.muted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
    }

    private func temperatureCard(label: String, value: Double) -> some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "thermometer.medium")
                .font(.system(size: 24))
                .foregroundStyle(value > 80 ? Theme.Colors.destructive : value > 60 ? Theme.Colors.warning : Theme.Colors.success)
                .frame(height: 64)
            Text(label)
                .font(Theme.Font.heading)
                .foregroundStyle(Theme.Colors.foreground)
            Text(String(format: "%.0f°C", value))
                .font(Theme.Font.monoSmall)
                .foregroundStyle(Theme.Colors.muted)
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
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
