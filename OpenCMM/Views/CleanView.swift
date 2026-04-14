import SwiftUI

struct CleanView: View {
    @ObservedObject var viewModel: CleanViewModel

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
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

            DependencyBanner(
                toolName: "Mole",
                description: "Deep clean, optimize, and analyze your Mac",
                isInstalled: viewModel.isMoleInstalled,
                isInstalling: viewModel.isInstallingMole,
                installError: viewModel.installError,
                installAction: { Task { await viewModel.installMole() } },
                version: viewModel.moleVersion
            )
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.md)

            // MARK: - Body
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
                resultsList
            } else if viewModel.lastCleanedSize > 0 {
                Spacer()
                SuccessStateView(
                    message: "Cleaned \(Formatters.fileSize(viewModel.lastCleanedSize))",
                    detail: "Your Mac has more breathing room now."
                )
                Spacer()
            } else {
                Spacer()
                EmptyStateView(
                    icon: "trash",
                    message: "Find hidden junk",
                    detail: "Clear out system caches, browser data, logs, and outdated files to reclaim disk space."
                )
                Spacer()
            }

            // MARK: - Footer
            if viewModel.isScanning {
                footerBar {
                    ghostButton("Stop") { viewModel.cancelScan() }
                }
            } else if viewModel.scanComplete && !viewModel.scanResults.isEmpty {
                actionBar(
                    label: "\(Formatters.fileSize(viewModel.totalSize)) to clean (\(viewModel.totalItems) items)",
                    buttonTitle: "Remove",
                    isWorking: viewModel.isCleaning,
                    action: { viewModel.showConfirmation = true },
                    secondaryTitle: "Rescan",
                    secondaryAction: { viewModel.startScan() }
                )
            } else {
                footerBar {
                    ScanButton(title: viewModel.lastCleanedSize > 0 ? "Rescan" : "Start Scan") {
                        viewModel.startScan()
                    }
                }
            }
        }
        .background(Theme.Colors.background)
        .task {
            viewModel.loadFromStore()
            await viewModel.checkDependencies()
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

    // MARK: - Results List

    private var resultsList: some View {
        List {
            ForEach(Array(viewModel.scanResults.enumerated()), id: \.element.id) { index, result in
                Section {
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
    }
}
