import SwiftUI

struct CleanView: View {
    @StateObject private var viewModel = CleanViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            moduleHeader(
                icon: "trash",
                color: .orange,
                title: "Clean",
                subtitle: "Free up space for things you truly need"
            )

            Divider()

            if viewModel.isScanning {
                Spacer()
                ProgressView("Scanning for junk files...")
                    .padding()
                Spacer()
            } else if viewModel.scanComplete && !viewModel.scanResults.isEmpty {
                // Results list
                List {
                    ForEach(Array(viewModel.scanResults.enumerated()), id: \.element.id) { index, result in
                        Section {
                            ForEach(result.items) { item in
                                HStack {
                                    Image(systemName: item.category.icon)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 24)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name)
                                            .font(.body)
                                        Text(item.path)
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                    Spacer()
                                    Text(Formatters.fileSize(item.size))
                                        .font(.body.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 2)
                            }
                        } header: {
                            HStack {
                                Toggle(isOn: Binding(
                                    get: { result.isSelected },
                                    set: { _ in viewModel.toggleCategory(index) }
                                )) {
                                    Text(result.category)
                                        .font(.headline)
                                }
                                Spacer()
                                Text(Formatters.fileSize(result.totalSize))
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
                .listStyle(.inset)

                // Bottom bar
                actionBar(
                    label: "\(Formatters.fileSize(viewModel.totalSize)) to clean",
                    buttonTitle: "Clean",
                    buttonColor: .orange,
                    isWorking: viewModel.isCleaning,
                    action: { Task { await viewModel.clean() } }
                )
            } else if viewModel.lastCleanedSize > 0 {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                    Text("Cleaned \(Formatters.fileSize(viewModel.lastCleanedSize))")
                        .font(.title2.bold())
                    Button("Scan Again") { Task { await viewModel.scan() } }
                        .buttonStyle(.bordered)
                }
                Spacer()
            } else {
                Spacer()
                VStack(spacing: 16) {
                    Text("Clear out hidden system junk to make room for your apps, photos, and other important stuff.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)

                    ScanButton(title: "Scan", color: .orange) {
                        Task { await viewModel.scan() }
                    }
                }
                Spacer()
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
