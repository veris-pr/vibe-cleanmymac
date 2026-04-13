import SwiftUI

struct SmartCareView: View {
    @StateObject private var viewModel = SmartCareViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                if viewModel.isScanning {
                    scanningSection
                } else if viewModel.scanComplete {
                    resultsSection
                } else {
                    welcomeSection
                }
            }
            .padding(32)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(.blue)
                .opacity(viewModel.isScanning ? 0.6 : 1.0)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: viewModel.isScanning)

            Text("Smart Care")
                .font(.largeTitle.bold())

            Text("One scan. Five routines.")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private var welcomeSection: some View {
        VStack(spacing: 20) {
            Text("Smart Care scans your Mac for junk files, threats, performance issues, updates, and clutter — all at once.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 500)

            Button(action: { Task { await viewModel.runSmartCare() } }) {
                Label("Start Smart Care", systemImage: "play.fill")
                    .font(.title3)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private var scanningSection: some View {
        VStack(spacing: 16) {
            ProgressRing(progress: viewModel.progress, size: 120)
                .padding()

            Text(viewModel.currentStep)
                .font(.headline)
                .foregroundStyle(.secondary)

            ProgressView(value: viewModel.progress)
                .frame(maxWidth: 400)
        }
    }

    private var resultsSection: some View {
        VStack(spacing: 20) {
            // Health Score
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 8)
                    .frame(width: 100, height: 100)
                Circle()
                    .trim(from: 0, to: Double(viewModel.healthScore) / 100.0)
                    .stroke(healthColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 100, height: 100)
                VStack(spacing: 0) {
                    Text("\(viewModel.healthScore)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    Text("Health")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if viewModel.totalIssues == 0 {
                Text("Your Mac is in great shape!")
                    .font(.title3)
                    .foregroundStyle(.green)
            } else {
                Text("\(viewModel.totalIssues) items need attention")
                    .font(.title3)
            }

            // Module summary cards
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], spacing: 16) {
                if let clean = viewModel.cleanSummary {
                    ModuleCard(summary: clean)
                }
                if let protect = viewModel.protectSummary {
                    ModuleCard(summary: protect)
                }
                if let speed = viewModel.speedSummary {
                    ModuleCard(summary: speed)
                }
                if let update = viewModel.updateSummary {
                    ModuleCard(summary: update)
                }
                if let declutter = viewModel.declutterSummary {
                    ModuleCard(summary: declutter)
                }
            }

            Button(action: { Task { await viewModel.runSmartCare() } }) {
                Label("Scan Again", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
    }

    private var healthColor: Color {
        if viewModel.healthScore >= 80 { return .green }
        if viewModel.healthScore >= 50 { return .orange }
        return .red
    }
}
