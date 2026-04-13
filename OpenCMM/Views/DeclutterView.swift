import SwiftUI

struct DeclutterView: View {
    @ObservedObject var viewModel: DeclutterViewModel

    var body: some View {
        VStack(spacing: 0) {
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
                // Tab picker
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
                    duplicatesView
                case .similarImages:
                    similarImagesView
                case .largeFiles:
                    largeFilesView
                case .tempFiles:
                    tempFilesView
                }
            } else {
                // Dependency banners
                VStack(spacing: Theme.Spacing.sm) {
                    DependencyBanner(
                        toolName: "fclones",
                        description: "High-performance duplicate file finder. Without it, a slower native hash-based scanner is used.",
                        isInstalled: viewModel.isFclonesInstalled,
                        isInstalling: viewModel.isInstallingFclones,
                        installError: viewModel.installError,
                        installAction: { Task { await viewModel.installFclones() } }
                    )

                    DependencyBanner(
                        toolName: "czkawka",
                        description: "Similar images, videos, and temp file detection. Enables the Similar Images and Temp Files tabs.",
                        isInstalled: viewModel.isCzkawkaInstalled,
                        isInstalling: false,
                        installError: nil,
                        installAction: {}
                    )
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.md)

                Spacer()
                EmptyStateView(
                    icon: "doc.on.doc",
                    message: "Find clutter",
                    detail: "Deep scan for duplicates, large forgotten files, and wasted storage. Uses full file hashing for accurate results.",
                    buttonTitle: "Deep Scan",
                    action: { Task { await viewModel.scan() } }
                )
                Spacer()
            }
        }
        .background(Theme.Colors.background)
        .task { await viewModel.checkDependencies() }
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

    // MARK: - Duplicates Tab

    private var duplicatesView: some View {
        Group {
            if viewModel.duplicateGroups.isEmpty {
                Spacer()
                SuccessStateView(
                    message: "No duplicates found",
                    detail: nil,
                    action: { Task { await viewModel.scan() } }
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
                                .contextMenu {
                                    Button {
                                        NSWorkspace.shared.selectFile(file.path, inFileViewerRootedAtPath: "")
                                    } label: {
                                        Label("Reveal in Finder", systemImage: "folder")
                                    }
                                }
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

                actionBar(
                    label: "Wasted space: \(Formatters.fileSize(viewModel.totalWastedSpace))",
                    buttonTitle: "Remove Duplicates",
                    isWorking: viewModel.isRemoving,
                    action: { viewModel.showConfirmation = true }
                )
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

    private var similarImagesView: some View {
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
                            detail: nil,
                            action: { Task { await viewModel.scan() } }
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
                                .contextMenu {
                                    Button {
                                        NSWorkspace.shared.selectFile(file.path, inFileViewerRootedAtPath: "")
                                    } label: {
                                        Label("Reveal in Finder", systemImage: "folder")
                                    }
                                }
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

                actionBar(
                    label: "\(viewModel.similarImages.flatMap(\.files).filter { !$0.keepThis }.count) image(s) to remove",
                    buttonTitle: "Remove Non-Kept",
                    isWorking: viewModel.isRemoving,
                    action: { viewModel.showConfirmation = true }
                )
            }
        }
    }

    // MARK: - Large Files Tab

    private var largeFilesView: some View {
        Group {
            if viewModel.largeFiles.isEmpty {
                Spacer()
                SuccessStateView(
                    message: "No large files found",
                    detail: nil,
                    action: { Task { await viewModel.scan() } }
                )
                Spacer()
            } else {
                // Sort picker
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
                        .contextMenu {
                            Button {
                                NSWorkspace.shared.selectFile(file.path, inFileViewerRootedAtPath: "")
                            } label: {
                                Label("Reveal in Finder", systemImage: "folder")
                            }
                        }
                    }
                }
                .listStyle(.inset)

                actionBar(
                    label: "\(Formatters.fileSize(viewModel.totalLargeFilesSize)) selected",
                    buttonTitle: "Move to Trash",
                    isWorking: viewModel.isRemoving,
                    action: { viewModel.showConfirmation = true }
                )
            }
        }
    }

    // MARK: - Temp Files Tab

    private var tempFilesView: some View {
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
                            detail: nil,
                            action: { Task { await viewModel.scan() } }
                        )
                    }
                }
                Spacer()
            } else {
                List {
                    ForEach(viewModel.tempFiles) { file in
                        HStack(spacing: Theme.Spacing.sm) {
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
                        .contextMenu {
                            Button {
                                NSWorkspace.shared.selectFile(file.path, inFileViewerRootedAtPath: "")
                            } label: {
                                Label("Reveal in Finder", systemImage: "folder")
                            }
                        }
                    }
                }
                .listStyle(.inset)

                actionBar(
                    label: "\(Formatters.fileSize(viewModel.totalTempFilesSize)) in temp files",
                    buttonTitle: "Remove Temp Files",
                    isWorking: viewModel.isRemoving,
                    action: { viewModel.showConfirmation = true }
                )
            }
        }
    }
}
