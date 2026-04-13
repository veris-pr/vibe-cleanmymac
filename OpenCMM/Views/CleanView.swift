import SwiftUI

struct CleanView: View {
    @ObservedObject var viewModel: CleanViewModel

    var body: some View {
        VStack(spacing: 0) {
            moduleHeader(
                icon: "trash",
                title: "Sweep",
                subtitle: "Free up space for things you truly need"
            )

            Divider()

            if let error = viewModel.errorMessage {
                ErrorBanner(message: error, onDismiss: { viewModel.errorMessage = nil })
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.md)
            }

            if viewModel.isScanning {
                Spacer()
                VStack(spacing: Theme.Spacing.md) {
                    ProgressView()
                        .controlSize(.regular)
                    Text("Scanning for junk files...")
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Colors.muted)
                    Button("Stop") { viewModel.cancelScan() }
                        .font(Theme.Font.bodyMedium)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                Spacer()
            } else if viewModel.scanComplete && !viewModel.scanResults.isEmpty {
                List {
                    ForEach(Array(viewModel.scanResults.enumerated()), id: \.element.id) { index, result in
                        Section {
                            // Disclosure triangle header
                            Button {
                                withAnimation(Theme.Animation.standard) {
                                    viewModel.toggleSection(result.id)
                                }
                            } label: {
                                HStack(spacing: Theme.Spacing.sm) {
                                    Image(systemName: viewModel.expandedSections.contains(result.id) ? "chevron.down" : "chevron.right")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(Theme.Colors.muted)
                                        .frame(width: 12)

                                    Toggle("", isOn: Binding(
                                        get: { result.isSelected },
                                        set: { _ in viewModel.toggleCategory(index) }
                                    ))
                                    .toggleStyle(.checkbox)
                                    .labelsHidden()

                                    Text(result.category)
                                        .font(Theme.Font.heading)
                                        .foregroundStyle(Theme.Colors.foreground)

                                    Spacer()

                                    Text("\(result.items.count) items")
                                        .font(Theme.Font.caption)
                                        .foregroundStyle(Theme.Colors.muted)

                                    Text(Formatters.fileSize(result.totalSize))
                                        .font(Theme.Font.monoSmall)
                                        .foregroundStyle(Theme.Colors.muted)
                                }
                            }
                            .buttonStyle(.plain)

                            // Expanded items
                            if viewModel.expandedSections.contains(result.id) {
                                ForEach(result.items) { item in
                                    HStack(spacing: Theme.Spacing.sm) {
                                        Toggle("", isOn: Binding(
                                            get: { item.isSelected },
                                            set: { _ in viewModel.toggleItem(item.id) }
                                        ))
                                        .toggleStyle(.checkbox)
                                        .labelsHidden()

                                        Image(systemName: item.category.icon)
                                            .font(.system(size: 12, weight: .regular))
                                            .foregroundStyle(Theme.Colors.muted)
                                            .frame(width: 20)

                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(item.name)
                                                .font(Theme.Font.body)
                                                .foregroundStyle(Theme.Colors.foreground)
                                            Text(item.path)
                                                .font(Theme.Font.caption)
                                                .foregroundStyle(Theme.Colors.muted.opacity(0.7))
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                        }

                                        Spacer()

                                        Text(Formatters.fileSize(item.size))
                                            .font(Theme.Font.monoSmall)
                                            .foregroundStyle(Theme.Colors.secondary)
                                    }
                                    .padding(.vertical, 2)
                                    .padding(.leading, Theme.Spacing.lg)
                                    .revealInFinderContextMenu(path: item.path)
                                }
                            }
                        }
                    }
                }
                .listStyle(.inset)

                actionBar(
                    label: "\(Formatters.fileSize(viewModel.totalSize)) to clean (\(viewModel.totalItems) items)",
                    buttonTitle: "Remove",
                    isWorking: viewModel.isCleaning,
                    action: { viewModel.showConfirmation = true },
                    secondaryTitle: "Rescan",
                    secondaryAction: { viewModel.startScan() }
                )
            } else if viewModel.lastCleanedSize > 0 {
                Spacer()
                SuccessStateView(
                    message: "Cleaned \(Formatters.fileSize(viewModel.lastCleanedSize))",
                    detail: "Your Mac has more breathing room now.",
                    action: { viewModel.startScan() }
                )
                Spacer()
            } else {
                Spacer()
                EmptyStateView(
                    icon: "trash",
                    message: "Find hidden junk",
                    detail: "Clear out system caches, browser data, logs, and outdated files to reclaim disk space.",
                    buttonTitle: "Start Scan",
                    action: { viewModel.startScan() }
                )
                Spacer()
            }
        }
        .background(Theme.Colors.background)
        .task {
            viewModel.loadFromStore()
        }
        .confirmationDialog(
            "Remove Selected Items",
            isPresented: $viewModel.showConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove \(Formatters.fileSize(viewModel.totalSize))", role: .destructive) {
                Task { await viewModel.clean() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(viewModel.totalItems) item(s) will be moved to Trash.")
        }
    }
}
