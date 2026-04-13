import SwiftUI

struct UninstallView: View {
    @ObservedObject var viewModel: UninstallViewModel

    var body: some View {
        VStack(spacing: 0) {
            moduleHeader(
                icon: "trash.square",
                title: "Uninstaller",
                subtitle: "Completely remove apps and their leftovers"
            )

            Divider()

            if viewModel.isLoading {
                Spacer()
                ProgressView("Scanning applications...")
                    .font(Theme.Font.body)
                Spacer()
            } else if let app = viewModel.selectedApp {
                appDetailView(app)
            } else {
                appListView
            }

            // Freed space confirmation
            if viewModel.lastFreedSize > 0 && viewModel.selectedApp == nil {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.Colors.success)
                    Text("Freed \(Formatters.fileSize(viewModel.lastFreedSize))")
                        .font(Theme.Font.bodyMedium)
                        .foregroundStyle(Theme.Colors.success)
                }
                .padding()
            }
        }
        .task {
            if viewModel.apps.isEmpty {
                await viewModel.loadApps()
            }
        }
        .alert("Uninstall App", isPresented: $viewModel.showConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Move to Trash", role: .destructive) {
                Task { await viewModel.uninstallSelected() }
            }
        } message: {
            if let app = viewModel.selectedApp {
                Text("This will move \(app.name) and \(viewModel.leftovers.count) leftover items to Trash.\n\nThis action can be undone from Trash.")
            }
        }
        .confirmationDialog(
            "Uninstall \(viewModel.selectedCount) App\(viewModel.selectedCount == 1 ? "" : "s")",
            isPresented: $viewModel.showBatchConfirmation,
            titleVisibility: .visible
        ) {
            Button("Uninstall \(viewModel.selectedCount) app\(viewModel.selectedCount == 1 ? "" : "s")", role: .destructive) {
                Task { await viewModel.uninstallBatch() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Selected apps and their leftover files will be moved to Trash.")
        }
    }

    // MARK: - App List

    private var appListView: some View {
        VStack(spacing: 0) {
            // Search & Sort bar
            HStack(spacing: Theme.Spacing.sm) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Theme.Colors.muted)
                        .font(.system(size: 12))
                    TextField("Search apps...", text: Binding(
                        get: { viewModel.searchText },
                        set: { viewModel.updateSearch($0) }
                    ))
                    .textFieldStyle(.plain)
                    .font(Theme.Font.body)

                    if !viewModel.searchText.isEmpty {
                        Button {
                            viewModel.updateSearch("")
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Theme.Colors.muted)
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Theme.Colors.muted.opacity(0.1))
                .cornerRadius(8)

                Picker("Sort", selection: Binding(
                    get: { viewModel.sortOrder },
                    set: { viewModel.updateSort($0) }
                )) {
                    ForEach(UninstallViewModel.SortOrder.allCases, id: \.self) { order in
                        Text(order.rawValue).tag(order)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.sm)

            Divider()

            // App list
            if viewModel.filteredApps.isEmpty {
                Spacer()
                EmptyStateView(
                    icon: "app.dashed",
                    message: viewModel.searchText.isEmpty ? "No applications found" : "No matching apps",
                    detail: viewModel.searchText.isEmpty ? "No apps detected in /Applications" : "No apps matching \"\(viewModel.searchText)\"",
                    buttonTitle: nil,
                    action: {}
                )
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.filteredApps) { app in
                            appRow(app)
                            Divider().padding(.leading, 72)
                        }
                    }
                    .padding(.vertical, Theme.Spacing.xs)
                }
            }

            // Action bar
            actionBar(
                label: viewModel.selectedCount > 0
                    ? "\(viewModel.selectedCount) app\(viewModel.selectedCount == 1 ? "" : "s") · \(Formatters.fileSize(viewModel.selectedTotalSize))"
                    : "\(viewModel.filteredApps.count) apps",
                buttonTitle: "Uninstall",
                isWorking: viewModel.isUninstalling,
                action: {
                    if viewModel.selectedCount > 0 {
                        viewModel.showBatchConfirmation = true
                    }
                },
                secondaryTitle: "Rescan",
                secondaryAction: { Task { await viewModel.loadApps() } }
            )
        }
    }

    private func appRow(_ app: InstalledApp) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Toggle("", isOn: Binding(
                get: { viewModel.isAppSelected(app) },
                set: { _ in viewModel.toggleApp(app) }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()

            Button {
                Task { await viewModel.selectApp(app) }
            } label: {
                HStack(spacing: Theme.Spacing.md) {
                    // App icon
                    if let icon = app.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 32, height: 32)
                            .cornerRadius(6)
                    } else {
                        Image(systemName: "app.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Theme.Colors.muted)
                            .frame(width: 32, height: 32)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(app.name)
                            .font(Theme.Font.bodyMedium)
                            .foregroundStyle(Theme.Colors.foreground)
                            .lineLimit(1)
                        Text(app.bundleIdentifier)
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Colors.muted)
                            .lineLimit(1)
                    }

                    Spacer()

                    Text(Formatters.fileSize(app.size))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Theme.Colors.secondary)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.Colors.muted)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.sm)
    }

    // MARK: - App Detail

    private func appDetailView(_ app: InstalledApp) -> some View {
        VStack(spacing: 0) {
            // Back button + App info
            HStack(spacing: Theme.Spacing.md) {
                Button {
                    viewModel.deselectApp()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.Colors.secondary)
                }
                .buttonStyle(.plain)

                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 40, height: 40)
                        .cornerRadius(8)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(Theme.Font.title)
                    Text(app.bundleIdentifier)
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Colors.muted)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("App: \(Formatters.fileSize(app.size))")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Colors.muted)
                    if !viewModel.leftovers.isEmpty {
                        Text("Leftovers: \(Formatters.fileSize(viewModel.totalLeftoverSize))")
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Colors.warning)
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)

            Divider()

            if viewModel.isScanning {
                Spacer()
                ProgressView("Scanning for leftovers...")
                    .font(Theme.Font.body)
                Spacer()
            } else if viewModel.leftovers.isEmpty {
                Spacer()
                VStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 32))
                        .foregroundStyle(Theme.Colors.success)
                    Text("No leftover files found")
                        .font(Theme.Font.bodyMedium)
                    Text("Only the app bundle (\(Formatters.fileSize(app.size))) will be removed")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Colors.muted)
                }
                Spacer()
            } else {
                leftoversList
            }

            if viewModel.errorMessage != nil {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Theme.Colors.warning)
                    Text(viewModel.errorMessage ?? "")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Colors.warning)
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, Theme.Spacing.xs)
            }

            // Uninstall action bar
            actionBar(
                label: "Total: \(Formatters.fileSize(app.size + viewModel.totalLeftoverSize))",
                buttonTitle: viewModel.isUninstalling ? "Removing..." : "Uninstall",
                isWorking: viewModel.isUninstalling,
                action: { viewModel.showConfirmation = true }
            )
        }
    }

    private var leftoversList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Text("Leftover Files")
                        .font(Theme.Font.bodyMedium)
                    Spacer()
                    Text("\(viewModel.leftovers.count) items · \(Formatters.fileSize(viewModel.totalLeftoverSize))")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Colors.muted)
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.md)

                ForEach(groupedLeftovers, id: \.category) { group in
                    leftoverSection(group)
                }
            }
            .padding(.bottom, Theme.Spacing.md)
        }
    }

    private var groupedLeftovers: [(category: AppLeftover.LeftoverCategory, items: [AppLeftover])] {
        let grouped = Dictionary(grouping: viewModel.leftovers, by: \.category)
        return AppLeftover.LeftoverCategory.allCases.compactMap { cat in
            guard let items = grouped[cat], !items.isEmpty else { return nil }
            return (category: cat, items: items)
        }
    }

    private func leftoverSection(_ group: (category: AppLeftover.LeftoverCategory, items: [AppLeftover])) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: categoryIcon(group.category))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.Colors.secondary)
                    .frame(width: 16)
                Text(group.category.rawValue)
                    .font(Theme.Font.bodyMedium)
                Spacer()
                Text(Formatters.fileSize(group.items.reduce(0) { $0 + $1.size }))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Theme.Colors.muted)
            }
            .padding(.horizontal, Theme.Spacing.lg)

            ForEach(group.items) { item in
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Colors.foreground)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Text(Formatters.fileSize(item.size))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Theme.Colors.muted)
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.leading, 20)
            }
        }
        .padding(.vertical, 4)
    }

    private func categoryIcon(_ category: AppLeftover.LeftoverCategory) -> String {
        switch category {
        case .appSupport: return "folder"
        case .caches: return "internaldrive"
        case .preferences: return "slider.horizontal.3"
        case .logs: return "doc.text"
        case .containers: return "shippingbox"
        case .crashReports: return "exclamationmark.triangle"
        case .savedState: return "bookmark"
        case .other: return "ellipsis.circle"
        }
    }
}
