import SwiftUI

struct SmartCareView: View {
    @StateObject private var viewModel = SmartCareViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xl) {
                if viewModel.isScanning {
                    scanningSection
                } else if viewModel.scanComplete {
                    resultsSection
                } else {
                    welcomeSection
                }
            }
            .padding(Theme.Spacing.xxl)
        }
        .background(Theme.Colors.background)
    }

    // MARK: - Welcome

    private var welcomeSection: some View {
        VStack(spacing: Theme.Spacing.xxl) {
            Spacer().frame(height: 40)

            VStack(spacing: Theme.Spacing.md) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 40, weight: .thin))
                    .foregroundStyle(Theme.Colors.muted)

                Text("Smart Care")
                    .font(Theme.Font.largeTitle)
                    .foregroundStyle(Theme.Colors.foreground)

                Text("One scan. Five routines.")
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Colors.muted)
            }

            Text("Scans your Mac for junk files, threats, performance issues, outdated apps, and clutter — all at once.")
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Colors.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            ScanButton(title: "Start Smart Care", action: {
                Task { await viewModel.runSmartCare() }
            })

            Spacer().frame(height: 40)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Scanning

    private var scanningSection: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer().frame(height: 60)

            ProgressRing(progress: viewModel.progress, size: 100, lineWidth: 5)

            VStack(spacing: Theme.Spacing.xs) {
                Text(viewModel.currentStep)
                    .font(Theme.Font.heading)
                    .foregroundStyle(Theme.Colors.foreground)

                Text("This may take a moment")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Colors.muted)
            }

            ProgressView(value: viewModel.progress)
                .tint(Color.primary.opacity(0.5))
                .frame(maxWidth: 320)

            Spacer().frame(height: 60)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Results

    private var resultsSection: some View {
        VStack(spacing: Theme.Spacing.xl) {
            // Health score
            VStack(spacing: Theme.Spacing.sm) {
                healthRing

                Text(healthLabel)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Colors.secondary)
            }

            // Module summary cards
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: Theme.Spacing.md)], spacing: Theme.Spacing.md) {
                if let clean = viewModel.cleanSummary { ModuleCard(summary: clean) }
                if let protect = viewModel.protectSummary { ModuleCard(summary: protect) }
                if let speed = viewModel.speedSummary { ModuleCard(summary: speed) }
                if let update = viewModel.updateSummary { ModuleCard(summary: update) }
                if let declutter = viewModel.declutterSummary { ModuleCard(summary: declutter) }
            }

            Button(action: { Task { await viewModel.runSmartCare() } }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .medium))
                    Text("Scan Again")
                        .font(Theme.Font.bodyMedium)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
        }
    }

    private var healthRing: some View {
        ZStack {
            Circle()
                .stroke(Theme.Colors.border, lineWidth: 5)
                .frame(width: 88, height: 88)
            Circle()
                .trim(from: 0, to: Double(viewModel.healthScore) / 100.0)
                .stroke(Color.primary.opacity(0.7), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 88, height: 88)
            VStack(spacing: 0) {
                Text("\(viewModel.healthScore)")
                    .font(Theme.Font.stat)
                    .foregroundStyle(Theme.Colors.foreground)
                Text("health")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Colors.muted)
            }
        }
    }

    private var healthLabel: String {
        if viewModel.totalIssues == 0 { return "Your Mac is in great shape." }
        return "\(viewModel.totalIssues) items need attention"
    }
}
