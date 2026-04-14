import SwiftUI

struct SpeedView: View {
    @ObservedObject var viewModel: SpeedViewModel

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            moduleHeader(
                icon: "gauge.with.needle",
                title: "Boost",
                subtitle: "Monitor, tune, and optimize your Mac"
            )

            Divider()

            if let error = viewModel.errorMessage {
                ErrorBanner(message: error, onDismiss: { viewModel.errorMessage = nil })
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.md)
            }

            // MARK: - Body
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
            } else if viewModel.isOptimizing || viewModel.optimizationComplete {
                optimizationView
            } else if (!viewModel.hostname.isEmpty && viewModel.hostname != "Mac") || !viewModel.loginItems.isEmpty || viewModel.isMacmonInstalled {
                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        if !viewModel.isMoleInstalled {
                            DependencyBanner(
                                toolName: "Mole",
                                description: "System optimizer — deep clean, optimize, and analyze your Mac. Provides enhanced optimization with 14+ tasks.",
                                isInstalled: viewModel.isMoleInstalled,
                                isInstalling: viewModel.isInstallingMole,
                                installError: viewModel.installError,
                                installAction: { Task { await viewModel.installMole() } }
                            )
                            .padding(.horizontal, Theme.Spacing.lg)
                        }

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

                        if let metrics = viewModel.metrics {
                            metricsCard(metrics)
                                .padding(.horizontal, Theme.Spacing.lg)
                        }

                        startupItemsCard
                            .padding(.horizontal, Theme.Spacing.lg)

                        systemCard
                            .padding(.horizontal, Theme.Spacing.lg)
                    }
                    .padding(.vertical, Theme.Spacing.lg)
                }
            } else {
                Spacer()
                EmptyStateView(
                    icon: "gauge.with.needle",
                    message: "Monitor and optimize",
                    detail: "View live performance metrics, manage startup items, and run system optimizations."
                )
                Spacer()
            }

            // MARK: - Footer
            if !viewModel.isLoading {
                if viewModel.isOptimizing {
                    // No footer during optimization
                } else if viewModel.optimizationComplete {
                    footerBar {
                        ghostButton("Done") {
                            viewModel.optimizationComplete = false
                            viewModel.optimizationSteps = []
                        }
                    }
                } else {
                    footerBar {
                        ghostButton("Rescan") { Task { await viewModel.loadData() } }
                        ScanButton(title: "Optimize") { Task { await viewModel.optimize() } }
                    }
                }
            }
        }
        .background(Theme.Colors.background)
        .task {
            if viewModel.hostname == "Mac" && viewModel.loginItems.isEmpty {
                await viewModel.loadData()
            }
        }
    }

    // MARK: - Optimization View

    private var optimizationView: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(viewModel.optimizationSteps) { step in
                    HStack(spacing: Theme.Spacing.md) {
                        // Status indicator
                        Group {
                            switch step.status {
                            case .pending:
                                Image(systemName: "circle")
                                    .foregroundStyle(Theme.Colors.muted.opacity(0.3))
                            case .running:
                                ProgressView()
                                    .controlSize(.small)
                            case .completed:
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Theme.Colors.success)
                            case .failed:
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(Theme.Colors.warning)
                            }
                        }
                        .frame(width: 16)

                        Image(systemName: step.icon)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.Colors.muted)
                            .frame(width: 18)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(step.name)
                                .font(Theme.Font.body)
                                .foregroundStyle(Theme.Colors.foreground)
                            if let detail = step.detail {
                                Text(detail)
                                    .font(Theme.Font.caption)
                                    .foregroundStyle(step.status == .failed ? Theme.Colors.warning : Theme.Colors.muted)
                            }
                        }

                        Spacer()
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.vertical, Theme.Spacing.sm)

                    if step.id != viewModel.optimizationSteps.last?.id {
                        Divider().padding(.horizontal, Theme.Spacing.lg)
                    }
                }
            }
            .padding(.vertical, Theme.Spacing.md)
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
                .font(Theme.Font.mini)
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
            if let score = viewModel.moleHealthScore {
                Divider()
                HStack {
                    Text("Health")
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Colors.muted)
                    Spacer()
                    Text("\(score)/100")
                        .font(Theme.Font.bodyMedium)
                        .foregroundStyle(score >= 80 ? Theme.Colors.success : score >= 50 ? Theme.Colors.warning : Theme.Colors.destructive)
                    if let msg = viewModel.moleHealthMsg {
                        Text("· \(msg)")
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Colors.muted)
                    }
                }
            }
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
