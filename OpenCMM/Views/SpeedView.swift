import SwiftUI

struct SpeedView: View {
    @StateObject private var viewModel = SpeedViewModel()

    var body: some View {
        VStack(spacing: 0) {
            moduleHeader(
                icon: "gauge.with.needle",
                title: "Speed",
                subtitle: "Make your slow Mac fast again"
            )

            Divider()

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
                        // Gauges
                        HStack(spacing: Theme.Spacing.md) {
                            statCard(
                                label: "CPU",
                                value: Formatters.percentage(info.cpuUsage),
                                progress: info.cpuUsage / 100.0
                            )
                            statCard(
                                label: "Memory",
                                value: "\(Formatters.fileSize(info.memoryUsed)) / \(Formatters.fileSize(info.memoryTotal))",
                                progress: info.memoryUsedPercent / 100.0
                            )
                            statCard(
                                label: "Disk",
                                value: "\(Formatters.fileSize(info.diskFree)) free",
                                progress: info.diskUsedPercent / 100.0
                            )
                        }
                        .padding(.horizontal, Theme.Spacing.lg)

                        // Quick actions
                        HStack(spacing: Theme.Spacing.sm) {
                            Button(action: { Task { await viewModel.purgeMemory() } }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "memorychip")
                                        .font(.system(size: 11))
                                    Text(viewModel.isPurging ? "Freeing..." : "Free Up RAM")
                                        .font(Theme.Font.bodyMedium)
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                            .disabled(viewModel.isPurging)

                            Button(action: { Task { await viewModel.refresh() } }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 11))
                                    Text("Refresh")
                                        .font(Theme.Font.bodyMedium)
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                        }
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
                    buttonTitle: "Analyze",
                    action: { Task { await viewModel.loadData() } }
                )
                Spacer()
            }
        }
        .background(Theme.Colors.background)
    }

    private func statCard(label: String, value: String, progress: Double) -> some View {
        VStack(spacing: Theme.Spacing.sm) {
            ZStack {
                Circle()
                    .stroke(Theme.Colors.border, lineWidth: 4)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.primary.opacity(0.6), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(Formatters.percentage(progress * 100))
                    .font(Theme.Font.monoSmall)
                    .foregroundStyle(Theme.Colors.foreground)
            }
            .frame(width: 64, height: 64)
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
