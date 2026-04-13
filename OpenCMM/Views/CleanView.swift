import SwiftUI

struct CleanView: View {
    @StateObject private var viewModel = CleanViewModel()

    var body: some View {
        VStack(spacing: 0) {
            moduleHeader(
                icon: "trash",
                title: "Clean",
                subtitle: "Free up space for things you truly need"
            )

            Divider()

            if viewModel.isScanning {
                Spacer()
                VStack(spacing: Theme.Spacing.md) {
                    ProgressView()
                        .controlSize(.regular)
                    Text("Scanning for junk files...")
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Colors.muted)
                }
                Spacer()
            } else if viewModel.scanComplete && !viewModel.scanResults.isEmpty {
                List {
                    ForEach(Array(viewModel.scanResults.enumerated()), id: \.element.id) { index, result in
                        Section {
                            ForEach(result.items) { item in
                                FileRow(
                                    icon: item.category.icon,
                                    name: item.name,
                                    path: item.path,
                                    trailing: Formatters.fileSize(item.size)
                                )
                            }
                        } header: {
                            SectionHeaderRow(
                                title: result.category,
                                trailing: Formatters.fileSize(result.totalSize),
                                isOn: Binding(
                                    get: { result.isSelected },
                                    set: { _ in viewModel.toggleCategory(index) }
                                )
                            )
                        }
                    }
                }
                .listStyle(.inset)

                actionBar(
                    label: "\(Formatters.fileSize(viewModel.totalSize)) to clean",
                    buttonTitle: "Clean",
                    isWorking: viewModel.isCleaning,
                    action: { Task { await viewModel.clean() } }
                )
            } else if viewModel.lastCleanedSize > 0 {
                Spacer()
                SuccessStateView(
                    message: "Cleaned \(Formatters.fileSize(viewModel.lastCleanedSize))",
                    detail: "Your Mac has more breathing room now.",
                    action: { Task { await viewModel.scan() } }
                )
                Spacer()
            } else {
                Spacer()
                EmptyStateView(
                    icon: "trash",
                    message: "Find hidden junk",
                    detail: "Clear out system caches, browser data, logs, and outdated files to reclaim disk space.",
                    buttonTitle: "Scan",
                    action: { Task { await viewModel.scan() } }
                )
                Spacer()
            }
        }
        .background(Theme.Colors.background)
    }
}
