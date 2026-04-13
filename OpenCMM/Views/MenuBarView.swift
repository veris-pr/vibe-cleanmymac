import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState

    @State private var cpuPercent: Double = 0
    @State private var memPercent: Double = 0
    @State private var diskPercent: Double = 0
    @State private var diskFree: UInt64 = 0
    @State private var memFree: UInt64 = 0

    private let sysInfo = SystemInfoService()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // MARK: – Last Scan Results
            if appState.scanStore.hasScanResults {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Last Scan")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        if let date = appState.scanStore.lastScanDate {
                            Text(Formatters.relativeDate(date))
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                    }

                    ForEach(appState.scanStore.orderedSummaries) { summary in
                        HStack(spacing: 6) {
                            Image(systemName: summary.hasIssues ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(summary.hasIssues ? .orange : .green)
                            Text(summary.module.rawValue)
                                .font(.system(size: 12))
                            Spacer()
                            if summary.hasIssues {
                                Text(summaryText(summary))
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("OK")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)

                Divider()
            } else {
                HStack {
                    Image(systemName: "info.circle")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text("No scan results yet")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)

                Divider()
            }

            // MARK: – System Metrics
            VStack(alignment: .leading, spacing: 6) {
                Text("System")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                metricRow(
                    icon: "internaldrive",
                    label: "Disk",
                    value: "\(Int(diskPercent))% used",
                    detail: "\(Formatters.fileSize(diskFree)) free",
                    percent: diskPercent
                )
                metricRow(
                    icon: "cpu",
                    label: "CPU",
                    value: "\(Int(cpuPercent))%",
                    detail: nil,
                    percent: cpuPercent
                )
                metricRow(
                    icon: "memorychip",
                    label: "RAM",
                    value: "\(Int(memPercent))% used",
                    detail: "\(Formatters.fileSize(memFree)) free",
                    percent: memPercent
                )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            Divider()

            // MARK: – Actions
            Button("Open OpenCMM") {
                activateApp()
            }
            .keyboardShortcut("o")

            Button("Run Quick Scan") {
                appState.selectedModule = .smartCare
                activateApp()
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .task { await refreshMetrics() }
    }

    // MARK: – Helpers

    private func metricRow(icon: String, label: String, value: String, detail: String?, percent: Double) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .frame(width: 14)
            Text(label)
                .font(.system(size: 12))
            Spacer()
            if let detail {
                Text(detail)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(barColor(percent))
        }
    }

    private func barColor(_ percent: Double) -> Color {
        if percent > 90 { return .red }
        if percent > 75 { return .orange }
        return .green
    }

    private func summaryText(_ s: ModuleScanSummary) -> String {
        if s.totalSize > 0 {
            return "\(s.itemCount) items · \(Formatters.fileSize(s.totalSize))"
        }
        return "\(s.itemCount) issue\(s.itemCount == 1 ? "" : "s")"
    }

    private func refreshMetrics() async {
        let status = await sysInfo.getDetailedInfo()
        cpuPercent = status.cpuUsage
        memPercent = status.memoryUsedPercent
        diskPercent = status.diskUsedPercent
        diskFree = status.diskFree
        memFree = status.memoryFree
    }

    private func activateApp() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.canBecomeKey }) {
            window.makeKeyAndOrderFront(nil)
        }
    }
}
