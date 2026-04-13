import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @State private var metrics: SystemMetrics?
    @State private var isMacmonInstalled = false
    @State private var isLoadingMetrics = false

    private let macmonService = MacMonService()

    private var scanSummaries: [ModuleScanSummary] {
        appState.scanStore.orderedSummaries
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // MARK: – System Metrics
            if isMacmonInstalled {
                metricsSection
                Divider().padding(.horizontal, 8)
            }

            // MARK: – Last Scan Results
            if appState.scanStore.hasScanResults {
                VStack(alignment: .leading, spacing: 4) {
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
                    .padding(.bottom, 2)

                    ForEach(scanSummaries) { summary in
                        scanRow(summary)
                    }
                }
                .padding(12)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text("No scan results yet")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .padding(12)
            }

            Divider().padding(.horizontal, 8)

            // MARK: – Actions
            VStack(spacing: 2) {
                menuButton("Open OpenCMM", icon: "macwindow") { activateApp() }
                menuButton("Run Quick Scan", icon: "play.circle") {
                    appState.selectedModule = .smartCare
                    activateApp()
                }

                Divider().padding(.horizontal, 4).padding(.vertical, 4)

                menuButton("Quit OpenCMM", icon: "power") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
        }
        .frame(width: AppConstants.UI.menuBarWidth)
        .task { await refreshMetrics() }
    }

    // MARK: – Metrics Section

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("System")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if isLoadingMetrics {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Button(action: { Task { await refreshMetrics() } }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if let m = metrics {
                HStack(spacing: 12) {
                    miniGauge("CPU", value: m.cpuUsage, detail: String(format: "%.0f°C", m.cpuTemp))
                    miniGauge("GPU", value: m.gpuUsage, detail: String(format: "%.0f°C", m.gpuTemp))
                    miniGauge("RAM", value: m.ramUsagePercent, detail: Formatters.fileSize(m.ramUsed))
                }
            } else if !isLoadingMetrics {
                Text("Tap refresh to load metrics")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
    }

    private func miniGauge(_ label: String, value: Double, detail: String) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: min(value, 1.0))
                    .stroke(gaugeColor(for: value), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(value * 100))%")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
            }
            .frame(width: 36, height: 36)

            Text(label)
                .font(.system(size: 10, weight: .medium))
            Text(detail)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func gaugeColor(for value: Double) -> Color {
        if value > 0.9 { return .red }
        if value > 0.7 { return .orange }
        return .green
    }

    private func refreshMetrics() async {
        isMacmonInstalled = await DependencyManager.shared.isInstalled(.macmon)
        guard isMacmonInstalled else { return }
        isLoadingMetrics = true
        metrics = await macmonService.sample()
        isLoadingMetrics = false
    }

    // MARK: – Components

    private func scanRow(_ summary: ModuleScanSummary) -> some View {
        HStack(spacing: 6) {
            Image(systemName: summary.hasIssues ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                .font(.system(size: 9))
                .foregroundStyle(summary.hasIssues ? Theme.Colors.warning : Theme.Colors.success)
            Text(summary.module.rawValue)
                .font(.system(size: 12))
            Spacer()
            Text(summary.hasIssues ? summaryText(summary) : "OK")
                .font(.system(size: 11))
                .foregroundStyle(summary.hasIssues ? Theme.Colors.muted : Theme.Colors.success)
        }
    }

    private func menuButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .frame(width: 16)
                Text(title)
                    .font(.system(size: 12))
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .cornerRadius(4)
    }

    // MARK: – Helpers

    private func summaryText(_ s: ModuleScanSummary) -> String {
        if s.totalSize > 0 {
            return "\(s.itemCount) items · \(Formatters.fileSize(s.totalSize))"
        }
        return "\(s.itemCount) issue\(s.itemCount == 1 ? "" : "s")"
    }

    private func activateApp() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.canBecomeKey }) {
            window.makeKeyAndOrderFront(nil)
        }
    }
}
