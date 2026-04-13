import SwiftUI

struct SpeedView: View {
    @ObservedObject var viewModel: SpeedViewModel

    var body: some View {
        VStack(spacing: 0) {
            moduleHeader(
                icon: "gauge.with.needle",
                title: "Boost",
                subtitle: "System monitoring and startup management"
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
            } else if (!viewModel.hostname.isEmpty && viewModel.hostname != "Mac") || !viewModel.loginItems.isEmpty || viewModel.isMacmonInstalled {
                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        // macmon install banner (if not installed)
                        if !viewModel.isMacmonInstalled {
                            DependencyBanner(
                                toolName: "macmon",
                                description: "Sudoless performance monitor for Apple Silicon. Provides live CPU, GPU, RAM, and temperature metrics.",
                                isInstalled: viewModel.isMacmonInstalled,
                                isInstalling: viewModel.isInstallingMacmon,
                                installError: viewModel.installError,
                                installAction: { Task { await viewModel.installMacmon() } }
                            )
                            .padding(.horizontal, Theme.Spacing.lg)
                        }

                        // Live metrics (if macmon installed)
                        if let metrics = viewModel.metrics {
                            metricsCard(metrics)
                                .padding(.horizontal, Theme.Spacing.lg)
                        }

                        // Startup items
                        startupItemsCard
                            .padding(.horizontal, Theme.Spacing.lg)

                        // System details
                        systemCard
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
                    buttonTitle: "Start Scan",
                    action: { Task { await viewModel.loadData() } }
                )
                Spacer()
            }
        }
        .background(Theme.Colors.background)
        .task {
            if viewModel.hostname == "Mac" && viewModel.loginItems.isEmpty {
                await viewModel.loadData()
            }
        }
    }

    // MARK: - Metrics Card

    private func metricsCard(_ metrics: SystemMetrics) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Text("Performance")
                    .font(Theme.Font.heading)
                    .foregroundStyle(Theme.Colors.foreground)
                Spacer()
                Circle()
                    .fill(Theme.Colors.success)
                    .frame(width: 6, height: 6)
                Text("Live")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Colors.muted)
            }
            .padding(.bottom, Theme.Spacing.xs)

            // CPU & GPU row
            HStack(spacing: Theme.Spacing.lg) {
                metricGauge(
                    label: "CPU",
                    value: metrics.cpuUsage,
                    detail: String(format: "%.1f W · %.0f °C", metrics.cpuPower, metrics.cpuTemp)
                )
                metricGauge(
                    label: "GPU",
                    value: metrics.gpuUsage,
                    detail: String(format: "%.1f W · %.0f °C", metrics.gpuPower, metrics.gpuTemp)
                )
                metricGauge(
                    label: "RAM",
                    value: metrics.ramUsagePercent,
                    detail: "\(Formatters.fileSize(metrics.ramUsed)) / \(Formatters.fileSize(metrics.ramTotal))"
                )
            }

            // Swap info (if any swap in use)
            if metrics.swapUsed > 0 {
                HStack {
                    Text("Swap")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Colors.muted)
                    Spacer()
                    Text("\(Formatters.fileSize(metrics.swapUsed)) / \(Formatters.fileSize(metrics.swapTotal))")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Colors.warning)
                }
            }
        }
        .cardStyle()
    }

    private func metricGauge(label: String, value: Double, detail: String) -> some View {
        VStack(spacing: Theme.Spacing.sm) {
            ZStack {
                Circle()
                    .stroke(Theme.Colors.muted.opacity(0.15), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: min(value, 1.0))
                    .stroke(gaugeColor(for: value), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: value)
                Text("\(Int(value * 100))%")
                    .font(Theme.Font.bodyMedium)
                    .foregroundStyle(Theme.Colors.foreground)
            }
            .frame(width: 64, height: 64)

            Text(label)
                .font(Theme.Font.bodyMedium)
                .foregroundStyle(Theme.Colors.foreground)
            Text(detail)
                .font(.system(size: 9))
                .foregroundStyle(Theme.Colors.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    private func gaugeColor(for value: Double) -> Color {
        if value > 0.9 { return Theme.Colors.destructive }
        if value > 0.7 { return Theme.Colors.warning }
        return Theme.Colors.success
    }

    // MARK: - Startup Items Card

    private var startupItemsCard: some View {
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
    }

    // MARK: - System Card

    private var systemCard: some View {
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
