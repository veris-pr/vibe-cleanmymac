import SwiftUI

struct SmartCareView: View {
    @ObservedObject var viewModel: SmartCareViewModel
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var scanStore: ScanStore

    var body: some View {
        VStack(spacing: 0) {
            moduleHeader(
                icon: "square.grid.2x2",
                title: "Overview",
                subtitle: "One scan. Five routines."
            )

            Divider()

            if viewModel.isScanning {
                scanningView
            } else if scanStore.hasScanResults {
                resultsView
            } else {
                welcomeView
            }
        }
        .background(Theme.Colors.background)
    }

    // MARK: - Welcome

    private var welcomeView: some View {
        VStack {
            Spacer()
            EmptyStateView(
                icon: "square.grid.2x2",
                message: "System Scan",
                detail: "Run all five maintenance routines in one scan: clean junk, detect threats, check performance, find updates, and remove clutter.",
                buttonTitle: "Start Scan",
                action: { viewModel.startScan() }
            )
            Spacer()
        }
    }

    // MARK: - Scanning

    private var scanningView: some View {
        VStack {
            Spacer()
            VStack(spacing: Theme.Spacing.xl) {
                ProgressRing(progress: viewModel.progress, size: 100, lineWidth: 8, invertedThresholds: true)

                VStack(spacing: Theme.Spacing.xs) {
                    Text(viewModel.currentStep)
                        .font(Theme.Font.heading)
                        .foregroundStyle(Theme.Colors.foreground)
                    Text("Scanning \(Int(viewModel.progress * 5)) of 5 modules")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Colors.muted)
                }

                ProgressView(value: viewModel.progress)
                    .progressViewStyle(.linear)
                    .frame(maxWidth: 280)
                    .tint(Theme.Colors.secondary)

                Button("Cancel") { viewModel.cancelScan() }
                    .font(Theme.Font.bodyMedium)
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
            }
            Spacer()
        }
    }

    // MARK: - Results

    private var resultsView: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xl) {
                // Health score
                VStack(spacing: Theme.Spacing.md) {
                    ProgressRing(
                        progress: Double(scanStore.healthScore) / 100.0,
                        size: 88, lineWidth: 7,
                        thresholds: true, invertedThresholds: true
                    )
                    Text("Health Score")
                        .font(Theme.Font.heading)
                        .foregroundStyle(Theme.Colors.foreground)
                    if scanStore.totalIssues > 0 {
                        Text("\(scanStore.totalIssues) issue(s) found")
                            .font(Theme.Font.body)
                            .foregroundStyle(Theme.Colors.muted)
                    } else {
                        Text("Your Mac is in great shape")
                            .font(Theme.Font.body)
                            .foregroundStyle(Theme.Colors.success)
                    }

                    // Last scanned date
                    if let lastDate = scanStore.lastScanDate {
                        Text("Last scanned \(Formatters.relativeDate(lastDate))")
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Colors.muted.opacity(0.7))
                    }
                }
                .padding(.top, Theme.Spacing.lg)

                // Module cards grid
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: Theme.Spacing.md)], spacing: Theme.Spacing.md) {
                    ForEach(scanStore.orderedSummaries) { summary in
                        ModuleCard(summary: summary) {
                            appState.selectedModule = summary.module
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)

                // Rescan
                Button("Rescan") { viewModel.startScan() }
                    .font(Theme.Font.bodyMedium)
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .padding(.bottom, Theme.Spacing.xl)
            }
        }
    }
}
