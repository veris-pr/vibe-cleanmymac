import SwiftUI

struct SmartCareView: View {
    @ObservedObject var viewModel: SmartCareViewModel
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var scanStore: ScanStore

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            moduleHeader(
                icon: "square.grid.2x2",
                title: "Overview",
                subtitle: "One scan. Five routines."
            )

            Divider()

            if let error = viewModel.errorMessage {
                ErrorBanner(message: error, onDismiss: { viewModel.errorMessage = nil })
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.md)
            }

            // MARK: - Body
            if viewModel.isScanning {
                scanningView
            } else if scanStore.hasScanResults {
                resultsBody
            } else {
                Spacer()
                EmptyStateView(
                    icon: "square.grid.2x2",
                    message: "System Scan",
                    detail: "Run all five maintenance routines in one scan: clean junk, detect threats, check performance, find updates, and remove clutter."
                )
                Spacer()
            }

            // MARK: - Footer
            if !viewModel.isScanning {
                footerBar {
                    if scanStore.hasScanResults {
                        ghostButton("Rescan") { viewModel.startScan() }
                    } else {
                        ScanButton(title: "Start Scan") { viewModel.startScan() }
                    }
                }
            }
        }
        .background(Theme.Colors.background)
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
            }
            Spacer()

            footerBar {
                ghostButton("Stop") { viewModel.cancelScan() }
            }
        }
    }

    // MARK: - Results Body

    private var resultsBody: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                if let lastDate = scanStore.lastScanDate {
                    Text("Last scanned \(Formatters.relativeDate(lastDate))")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Colors.muted.opacity(0.7))
                        .padding(.top, Theme.Spacing.md)
                }

                ForEach(scanStore.orderedSummaries) { summary in
                    ModuleCard(summary: summary) {
                        appState.selectedModule = summary.module
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
            }
            .padding(.bottom, Theme.Spacing.md)
        }
    }
}
