import SwiftUI

struct SpeedView: View {
    @StateObject private var viewModel = SpeedViewModel()

    var body: some View {
        VStack(spacing: 0) {
            moduleHeader(
                icon: "gauge.with.dots.needle.67percent",
                color: .purple,
                title: "Speed",
                subtitle: "Make your slow Mac fast again"
            )

            Divider()

            if viewModel.isLoading {
                Spacer()
                ProgressView("Loading system info...")
                Spacer()
            } else if let info = viewModel.systemInfo {
                ScrollView {
                    VStack(spacing: 20) {
                        // System overview cards
                        HStack(spacing: 16) {
                            gaugeCard(
                                title: "CPU",
                                value: info.cpuUsage,
                                detail: Formatters.percentage(info.cpuUsage),
                                color: gaugeColor(info.cpuUsage)
                            )
                            gaugeCard(
                                title: "Memory",
                                value: info.memoryUsedPercent,
                                detail: "\(Formatters.fileSize(info.memoryUsed)) / \(Formatters.fileSize(info.memoryTotal))",
                                color: gaugeColor(info.memoryUsedPercent)
                            )
                            gaugeCard(
                                title: "Disk",
                                value: info.diskUsedPercent,
                                detail: "\(Formatters.fileSize(info.diskFree)) free",
                                color: gaugeColor(info.diskUsedPercent)
                            )
                        }
                        .padding(.horizontal)

                        // Quick actions
                        HStack(spacing: 12) {
                            Button(action: { Task { await viewModel.purgeMemory() } }) {
                                Label(viewModel.isPurging ? "Freeing..." : "Free Up RAM", systemImage: "memorychip")
                            }
                            .buttonStyle(.bordered)
                            .disabled(viewModel.isPurging)

                            Button(action: { Task { await viewModel.refresh() } }) {
                                Label("Refresh", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.horizontal)

                        // Login items
                        GroupBox {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Startup Items")
                                    .font(.headline)
                                    .padding(.bottom, 4)

                                if viewModel.loginItems.isEmpty {
                                    Text("No startup items found")
                                        .foregroundStyle(.secondary)
                                } else {
                                    ForEach(viewModel.loginItems) { item in
                                        HStack {
                                            Circle()
                                                .fill(item.isEnabled ? .green : .gray)
                                                .frame(width: 8, height: 8)
                                            VStack(alignment: .leading, spacing: 1) {
                                                Text(item.name)
                                                    .font(.body)
                                                    .lineLimit(1)
                                                Text(item.kind.rawValue)
                                                    .font(.caption)
                                                    .foregroundStyle(.tertiary)
                                            }
                                            Spacer()
                                            if item.isEnabled {
                                                Button("Disable") { Task { await viewModel.disableLoginItem(item) } }
                                                    .buttonStyle(.bordered)
                                                    .controlSize(.small)
                                            } else {
                                                Button("Enable") { Task { await viewModel.enableLoginItem(item) } }
                                                    .buttonStyle(.bordered)
                                                    .controlSize(.small)
                                            }
                                        }
                                        .padding(.vertical, 2)
                                        Divider()
                                    }
                                }
                            }
                            .padding(8)
                        }
                        .padding(.horizontal)

                        // System details
                        GroupBox {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("System Details")
                                    .font(.headline)
                                    .padding(.bottom, 4)
                                detailRow("Computer", info.hostname)
                                detailRow("macOS", info.osVersion)
                                detailRow("Uptime", Formatters.duration(info.uptime))
                            }
                            .padding(8)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            } else {
                Spacer()
                VStack(spacing: 16) {
                    Text("Multitasking, editing, or whatever you're doing — your Mac will run efficiently. Control memory and CPU load to keep your Mac productive.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)

                    ScanButton(title: "Analyze", color: .purple) {
                        Task { await viewModel.loadData() }
                    }
                }
                Spacer()
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func gaugeCard(title: String, value: Double, detail: String, color: Color) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 6)
                Circle()
                    .trim(from: 0, to: value / 100.0)
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(Formatters.percentage(value))
                    .font(.system(.body, design: .rounded, weight: .semibold))
            }
            .frame(width: 80, height: 80)
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }

    private func gaugeColor(_ value: Double) -> Color {
        if value >= 80 { return .red }
        if value >= 60 { return .orange }
        return .green
    }
}
