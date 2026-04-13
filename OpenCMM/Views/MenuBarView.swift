import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState

    private var scanSummaries: [ModuleScanSummary] {
        appState.scanStore.orderedSummaries
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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
        .frame(width: 260)
    }

    // MARK: – Components

    private func scanRow(_ summary: ModuleScanSummary) -> some View {
        HStack(spacing: 6) {
            Image(systemName: summary.hasIssues ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                .font(.system(size: 9))
                .foregroundStyle(summary.hasIssues ? .orange : .green)
            Text(summary.module.rawValue)
                .font(.system(size: 12))
            Spacer()
            Text(summary.hasIssues ? summaryText(summary) : "OK")
                .font(.system(size: 11))
                .foregroundStyle(summary.hasIssues ? Color.secondary : Color.green)
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
