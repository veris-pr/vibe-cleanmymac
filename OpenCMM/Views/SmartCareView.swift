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

            if let error = viewModel.errorMessage {
                ErrorBanner(message: error, onDismiss: { viewModel.errorMessage = nil })
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.md)
            }

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

                Button("Stop") { viewModel.cancelScan() }
                    .font(Theme.Font.bodyMedium)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            Spacer()
        }
    }

    // MARK: - Results

    private var resultsView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    // Last scanned date
                    if let lastDate = scanStore.lastScanDate {
                        Text("Last scanned \(Formatters.relativeDate(lastDate))")
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Colors.muted.opacity(0.7))
                            .padding(.top, Theme.Spacing.md)
                    }

                    // Module cards — full width
                    ForEach(scanStore.orderedSummaries) { summary in
                        ModuleCard(summary: summary) {
                            appState.selectedModule = summary.module
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                }
                .padding(.bottom, Theme.Spacing.md)
            }

            // Footer
            Divider()
            HStack {
                Spacer()
                Button(action: { viewModel.startScan() }) {
                    Text("Rescan")
                        .font(Theme.Font.bodyMedium)
                        .foregroundStyle(Theme.Colors.foreground)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Theme.Colors.subtle)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                .stroke(Theme.Colors.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
        }
    }
}
