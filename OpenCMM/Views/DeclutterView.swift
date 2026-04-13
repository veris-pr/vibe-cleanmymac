import SwiftUI

struct DeclutterView: View {
    @StateObject private var viewModel = DeclutterViewModel()

    var body: some View {
        VStack(spacing: 0) {
            moduleHeader(
                icon: "doc.on.doc",
                title: "Declutter",
                subtitle: "Take control of the clutter"
            )

            Divider()

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
                case .largeFiles:
                    largeFilesView
                }
            } else {
                // Dependency banner
                DependencyBanner(
                    toolName: "fclones",
                    description: "High-performance duplicate file finder. Without it, a slower native hash-based scanner is used.",
                    isInstalled: viewModel.isFclonesInstalled,
                    isInstalling: viewModel.isInstallingFclones,
                    installError: viewModel.installError,
                    installAction: { Task { await viewModel.installFclones() } }
                )
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.md)

                Spacer()
                EmptyStateView(
                    icon: "doc.on.doc",
                    message: "Find clutter",
                    detail: "Remove duplicates, discover large forgotten files, and reclaim wasted storage space.",
                    buttonTitle: "Scan",
                    action: { Task { await viewModel.scan() } }
                )
                Spacer()
            }
        }
        .background(Theme.Colors.background)
        .task { await viewModel.checkDependencies() }
    }

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
                                    Image(systemName: file.keepThis ? "checkmark.circle" : "circle")
                                        .font(.system(size: 13))
                                        .foregroundStyle(file.keepThis ? Theme.Colors.success : Theme.Colors.muted)
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
                    action: { Task { await viewModel.removeDuplicates() } }
                )
            }
        }
    }

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
                List {
                    ForEach(viewModel.largeFiles) { file in
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
                    }
                }
                .listStyle(.inset)

                actionBar(
                    label: "\(Formatters.fileSize(viewModel.totalLargeFilesSize)) selected",
                    buttonTitle: "Move to Trash",
                    isWorking: viewModel.isRemoving,
                    action: { Task { await viewModel.removeLargeFiles() } }
                )
            }
        }
    }
}
