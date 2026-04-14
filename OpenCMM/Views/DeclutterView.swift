import SwiftUI

struct DeclutterView: View {
    @ObservedObject var viewModel: DeclutterViewModel

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            moduleHeader(
                icon: "doc.on.doc",
                title: "Duplicates",
                subtitle: "Take control of the clutter"
            )

            Divider()

            if let error = viewModel.errorMessage {
                ErrorBanner(message: error, onDismiss: { viewModel.errorMessage = nil })
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.md)
            }

            // MARK: - Body
            if viewModel.isScanning {
                Spacer()
                VStack(spacing: Theme.Spacing.md) {
                    ProgressView()
                        .controlSize(.regular)
                    Text("Scanning for duplicates and large files...")
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Colors.muted)
                }
                Spacer()
            } else if viewModel.scanComplete {
                Picker("", selection: $viewModel.selectedTab) {
                    ForEach(DeclutterTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, Theme.Spacing.md)

                switch viewModel.selectedTab {
                case .duplicates:
                    duplicatesBody
                case .similarImages:
                    similarImagesBody
                case .largeFiles:
                    largeFilesBody
                case .tempFiles:
                    tempFilesBody
                }
            } else {
                VStack(spacing: Theme.Spacing.sm) {
                    DependencyBanner(
                        toolName: "fclones",
                        description: "High-performance duplicate file finder",
                        isInstalled: viewModel.isFclonesInstalled,
                        isInstalling: viewModel.isInstallingFclones,
                        installError: viewModel.installError,
                        installAction: { Task { await viewModel.installFclones() } },
                        version: viewModel.fclonesVersion
                    )

                    DependencyBanner(
                        toolName: "czkawka",
                        description: "Similar images, videos, and temp file detection",
                        isInstalled: viewModel.isCzkawkaInstalled,
                        isInstalling: viewModel.isInstallingCzkawka,
                        installError: viewModel.installError,
                        installAction: { Task { await viewModel.installCzkawka() } },
                        version: viewModel.czkawkaVersion
                    )
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.md)

                Spacer()
                EmptyStateView(
                    icon: "doc.on.doc",
                    message: "Find clutter",
                    detail: "Deep scan for duplicates, large forgotten files, and wasted storage. Uses full file hashing for accurate results."
                )
                Spacer()
            }

            // MARK: - Footer
            if viewModel.isScanning {
                footerBar {
                    ghostButton("Stop") { viewModel.cancelScan() }
                }
            } else if viewModel.scanComplete {
                currentTabFooter
            } else {
                footerBar {
                    ScanButton(title: "Start Scan") { viewModel.startScan() }
                }
            }
        }
        .background(Theme.Colors.background)
        .task {
            await viewModel.checkDependencies()
            viewModel.loadFromStore()
        }
        .confirmationDialog(
            "Remove Selected Items",
            isPresented: $viewModel.showConfirmation,
            titleVisibility: .visible
        ) {
            switch viewModel.selectedTab {
            case .duplicates:
                Button("Remove Duplicates", role: .destructive) {
                    Task { await viewModel.removeDuplicates() }
                }
            case .similarImages:
                Button("Remove Non-Kept Images", role: .destructive) {
                    Task { await viewModel.removeSimilarImages() }
                }
            case .largeFiles:
                Button("Move to Trash", role: .destructive) {
                    Task { await viewModel.removeLargeFiles() }
                }
            case .tempFiles:
                Button("Remove Temp Files", role: .destructive) {
                    Task { await viewModel.removeTempFiles() }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Selected files will be moved to Trash. This action cannot be undone.")
        }
    }

    // MARK: - Tab Footer

    @ViewBuilder
    private var currentTabFooter: some View {
        switch viewModel.selectedTab {
        case .duplicates:
            if viewModel.duplicateGroups.isEmpty {
                footerBar { ghostButton("Rescan") { viewModel.startScan() } }
            } else {
                actionBar(
                    label: "Wasted space: \(Formatters.fileSize(viewModel.totalWastedSpace))",
                    buttonTitle: "Remove",
                    isWorking: viewModel.isRemoving,
                    action: { viewModel.showConfirmation = true },
                    secondaryTitle: "Rescan",
                    secondaryAction: { viewModel.startScan() }
                )
            }
        case .similarImages:
            if viewModel.similarImages.isEmpty {
                footerBar { ghostButton("Rescan") { viewModel.startScan() } }
            } else {
                actionBar(
                    label: "\(viewModel.similarImages.flatMap(\.files).filter { !$0.keepThis }.count) image(s) to remove",
                    buttonTitle: "Remove",
                    isWorking: viewModel.isRemoving,
                    action: { viewModel.showConfirmation = true },
                    secondaryTitle: "Rescan",
                    secondaryAction: { viewModel.startScan() }
                )
            }
        case .largeFiles:
            if viewModel.largeFiles.isEmpty {
                footerBar { ghostButton("Rescan") { viewModel.startScan() } }
            } else {
                actionBar(
                    label: "\(Formatters.fileSize(viewModel.totalLargeFilesSize)) selected",
                    buttonTitle: "Remove",
                    isWorking: viewModel.isRemoving,
                    action: { viewModel.showConfirmation = true },
                    secondaryTitle: "Rescan",
                    secondaryAction: { viewModel.startScan() }
                )
            }
        case .tempFiles:
            if viewModel.tempFiles.isEmpty {
                footerBar { ghostButton("Rescan") { viewModel.startScan() } }
            } else {
                actionBar(
                    label: "\(Formatters.fileSize(viewModel.totalTempFilesSize)) in temp files",
                    buttonTitle: "Remove",
                    isWorking: viewModel.isRemoving,
                    action: { viewModel.showConfirmation = true },
                    secondaryTitle: "Rescan",
                    secondaryAction: { viewModel.startScan() }
                )
            }
        }
    }

    // MARK: - Duplicates Tab

    private var duplicatesBody: some View {
        Group {
            if viewModel.duplicateGroups.isEmpty {
                Spacer()
                SuccessStateView(
                    message: "No duplicates found",
                    detail: nil
                )
                Spacer()
            } else {
                List {
                    ForEach(viewModel.duplicateGroups) { group in
                        Section {
                            ForEach(group.files) { file in
                                HStack(spacing: Theme.Spacing.sm) {
                                    Button {
                                        toggleKeepInDuplicates(groupId: group.id, fileId: file.id)
                                    } label: {
                                        Image(systemName: file.keepThis ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 13))
                                            .foregroundStyle(file.keepThis ? Theme.Colors.success : Theme.Colors.muted)
                                    }
                                    .buttonStyle(.plain)

                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(file.name)
                                            .font(Theme.Font.body)
                                            .foregroundStyle(Theme.Colors.foreground)
                                        Text(file.path)
                                            .font(Theme.Font.caption)
                                            .foregroundStyle(Theme.Colors.muted.opacity(0.7))
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                    Spacer()
                                    Text(Formatters.fileSize(file.size))
                                        .font(Theme.Font.monoSmall)
                                        .foregroundStyle(Theme.Colors.secondary)
                                }
                                .revealInFinderContextMenu(path: file.path)
                            }
                        } header: {
                            SectionHeaderRow(
                                title: "\(group.files.count) duplicates",
                                trailing: "Wasted: \(Formatters.fileSize(group.wastedSpace))"
                            )
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    private func toggleKeepInDuplicates(groupId: UUID, fileId: UUID) {
        if let gIdx = viewModel.duplicateGroups.firstIndex(where: { $0.id == groupId }) {
            if let fIdx = viewModel.duplicateGroups[gIdx].files.firstIndex(where: { $0.id == fileId }) {
                viewModel.duplicateGroups[gIdx].files[fIdx].keepThis.toggle()
            }
        }
    }

    // MARK: - Similar Images Tab

    private var similarImagesBody: some View {
        Group {
            if viewModel.similarImages.isEmpty {
                Spacer()
                VStack(spacing: Theme.Spacing.md) {
                    if !viewModel.isCzkawkaInstalled {
                        Text("Install czkawka to find similar images")
                            .font(Theme.Font.body)
                            .foregroundStyle(Theme.Colors.muted)
                    } else {
                        SuccessStateView(
                            message: "No similar images found",
                            detail: nil
                        )
                    }
                }
                Spacer()
            } else {
                List {
                    ForEach(viewModel.similarImages) { group in
                        Section {
                            ForEach(group.files) { file in
                                HStack(spacing: Theme.Spacing.sm) {
                                    Button {
                                        viewModel.toggleKeep(groupId: group.id, fileId: file.id)
                                    } label: {
                                        Image(systemName: file.keepThis ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 13))
                                            .foregroundStyle(file.keepThis ? Theme.Colors.success : Theme.Colors.muted)
                                    }
                                    .buttonStyle(.plain)

                                    Image(systemName: "photo")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.Colors.muted)
                                        .frame(width: 20)

                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(file.name)
                                            .font(Theme.Font.body)
                                            .foregroundStyle(Theme.Colors.foreground)
                                        Text(file.path)
                                            .font(Theme.Font.caption)
                                            .foregroundStyle(Theme.Colors.muted.opacity(0.7))
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                    Spacer()
                                    Text(Formatters.fileSize(file.size))
                                        .font(Theme.Font.monoSmall)
                                        .foregroundStyle(Theme.Colors.secondary)
                                }
                                .revealInFinderContextMenu(path: file.path)
                            }
                        } header: {
                            SectionHeaderRow(
                                title: "\(group.files.count) similar (\(Int(group.similarity))% match)",
                                trailing: nil
                            )
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    // MARK: - Large Files Tab

    private var largeFilesBody: some View {
        Group {
            if viewModel.largeFiles.isEmpty {
                Spacer()
                SuccessStateView(
                    message: "No large files found",
                    detail: nil
                )
                Spacer()
            } else {
                HStack {
                    Text("Sort by:")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Colors.muted)
                    Picker("", selection: $viewModel.largeSortOrder) {
                        ForEach(LargeSortOrder.allCases, id: \.self) { order in
                            Text(order.rawValue).tag(order)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                    Spacer()
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.xs)

                List {
                    ForEach(viewModel.sortedLargeFiles) { file in
                        HStack(spacing: Theme.Spacing.sm) {
                            Toggle("", isOn: Binding(
                                get: { file.isSelected },
                                set: { _ in viewModel.toggleLargeFile(file.id) }
                            ))
                            .toggleStyle(.checkbox)
                            .labelsHidden()

                            Image(systemName: "doc")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.Colors.muted)
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(file.name)
                                    .font(Theme.Font.body)
                                    .foregroundStyle(Theme.Colors.foreground)
                                HStack(spacing: 4) {
                                    Text(file.path)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Text("·")
                                    Text("Last used \(Formatters.relativeDate(file.lastAccessed))")
                                }
                                .font(Theme.Font.caption)
                                .foregroundStyle(Theme.Colors.muted)
                            }
                            Spacer()
                            Text(Formatters.fileSize(file.size))
                                .font(Theme.Font.mono)
                                .foregroundStyle(Theme.Colors.foreground)
                        }
                        .revealInFinderContextMenu(path: file.path)
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    // MARK: - Temp Files Tab

    private var tempFilesBody: some View {
        Group {
            if viewModel.tempFiles.isEmpty {
                Spacer()
                VStack(spacing: Theme.Spacing.md) {
                    if !viewModel.isCzkawkaInstalled {
                        Text("Install czkawka to find temp files")
                            .font(Theme.Font.body)
                            .foregroundStyle(Theme.Colors.muted)
                    } else {
                        SuccessStateView(
                            message: "No temp files found",
                            detail: nil
                        )
                    }
                }
                Spacer()
            } else {
                List {
                    ForEach(viewModel.tempFiles) { file in
                        HStack(spacing: Theme.Spacing.sm) {
                            Toggle("", isOn: Binding(
                                get: { file.isSelected },
                                set: { _ in viewModel.toggleTempFile(file.id) }
                            ))
                            .toggleStyle(.checkbox)
                            .labelsHidden()

                            Image(systemName: "doc.badge.clock")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.Colors.muted)
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(file.name)
                                    .font(Theme.Font.body)
                                    .foregroundStyle(Theme.Colors.foreground)
                                Text(file.path)
                                    .font(Theme.Font.caption)
                                    .foregroundStyle(Theme.Colors.muted.opacity(0.7))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer()
                            Text(Formatters.fileSize(file.size))
                                .font(Theme.Font.monoSmall)
                                .foregroundStyle(Theme.Colors.secondary)
                        }
                        .revealInFinderContextMenu(path: file.path)
                    }
                }
                .listStyle(.inset)
            }
        }
    }
}
