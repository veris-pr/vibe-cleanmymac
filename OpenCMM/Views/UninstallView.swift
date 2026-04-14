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
                VStack(spacing: Theme.Spacing.md) {
                    ProgressView()
                        .controlSize(.regular)
                    Text("Scanning applications...")
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Colors.muted)
                }
                Spacer()
            } else if let app = viewModel.selectedApp {
                appDetailView(app)
            } else if let pkg = viewModel.selectedBrewPackage {
                brewPackageDetailView(pkg)
            } else {
                appListView
            }

            // Freed space confirmation
            if viewModel.lastFreedSize > 0 && viewModel.selectedApp == nil && viewModel.selectedBrewPackage == nil {
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
        .background(Theme.Colors.background)
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
        .confirmationDialog(
            "Uninstall \(viewModel.selectedBrewCount) Package\(viewModel.selectedBrewCount == 1 ? "" : "s")",
            isPresented: $viewModel.showBrewConfirmation,
            titleVisibility: .visible
        ) {
            Button("Uninstall \(viewModel.selectedBrewCount) package\(viewModel.selectedBrewCount == 1 ? "" : "s")", role: .destructive) {
                Task { await viewModel.uninstallSelectedBrew() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Selected Homebrew packages will be removed via brew uninstall. Dependencies not used by other packages will also be removed.")
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
                        .font(Theme.Font.bodySmall)
                    TextField("Search apps & packages...", text: Binding(
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
                                .font(Theme.Font.caption)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Theme.Colors.muted.opacity(0.1))
                .cornerRadius(Theme.Radius.md)

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

            // App list + Brew packages
            if viewModel.filteredApps.isEmpty && viewModel.filteredBrewPackages.isEmpty {
                Spacer()
                EmptyStateView(
                    icon: "app.dashed",
                    message: viewModel.searchText.isEmpty ? "No applications found" : "No matching apps",
                    detail: viewModel.searchText.isEmpty ? "No apps detected in /Applications" : "No apps matching \"\(viewModel.searchText)\""
                )
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Software section
                        if !viewModel.filteredApps.isEmpty {
                            sectionHeader(
                                title: "Software",
                                count: viewModel.filteredApps.count,
                                icon: "app.fill"
                            )
                            ForEach(viewModel.filteredApps) { app in
                                appRow(app)
                                Divider().padding(.leading, 72)
                            }
                        }

                        // Brew packages section
                        if !viewModel.filteredBrewPackages.isEmpty {
                            brewPackagesSection
                        } else if viewModel.isLoadingBrew {
                            HStack(spacing: Theme.Spacing.sm) {
                                ProgressView().controlSize(.small)
                                Text("Loading Homebrew packages...")
                                    .font(Theme.Font.caption)
                                    .foregroundStyle(Theme.Colors.muted)
                            }
                            .padding(Theme.Spacing.lg)
                        }
                    }
                    .padding(.vertical, Theme.Spacing.xs)
                }
            }

            // Action bar
            actionBar(
                label: actionBarLabel,
                buttonTitle: "Uninstall",
                isWorking: viewModel.isUninstalling,
                action: {
                    if viewModel.selectedCount > 0 {
                        viewModel.showBatchConfirmation = true
                    } else if viewModel.selectedBrewCount > 0 {
                        viewModel.showBrewConfirmation = true
                    }
                },
                secondaryTitle: "Rescan",
                secondaryAction: { Task { await viewModel.loadApps() } }
            )
        }
    }

    private var actionBarLabel: String {
        var parts: [String] = []
        if viewModel.selectedCount > 0 {
            parts.append("\(viewModel.selectedCount) app\(viewModel.selectedCount == 1 ? "" : "s")")
        }
        if viewModel.selectedBrewCount > 0 {
            parts.append("\(viewModel.selectedBrewCount) pkg\(viewModel.selectedBrewCount == 1 ? "" : "s")")
        }
        if parts.isEmpty {
            return "\(viewModel.filteredApps.count) apps · \(viewModel.filteredBrewPackages.count) packages"
        }
        let totalSize = viewModel.selectedTotalSize + viewModel.selectedBrewTotalSize
        return parts.joined(separator: " + ") + " · \(Formatters.fileSize(totalSize))"
    }

    private func sectionHeader(title: String, count: Int, icon: String) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Colors.secondary)
            Text(title)
                .font(Theme.Font.bodyMedium)
                .foregroundStyle(Theme.Colors.foreground)
            Text("(\(count))")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Colors.muted)
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.xs)
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
                            .font(.title2)
                            .foregroundStyle(Theme.Colors.muted)
                            .frame(width: 32, height: 32)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: Theme.Spacing.xs) {
                            Text(app.name)
                                .font(Theme.Font.bodyMedium)
                                .foregroundStyle(Theme.Colors.foreground)
                                .lineLimit(1)
                            if app.isBrewCask {
                                Text("Brew")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(Theme.Colors.accent)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Theme.Colors.accent.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                            }
                        }
                        Text(app.bundleIdentifier)
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Colors.muted)
                            .lineLimit(1)
                    }

                    Spacer()

                    Text(Formatters.fileSize(app.size))
                        .font(Theme.Font.monoSmall)
                        .foregroundStyle(Theme.Colors.secondary)

                    Image(systemName: "chevron.right")
                        .font(Theme.Font.smallMedium)
                        .foregroundStyle(Theme.Colors.muted)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.sm)
        .revealInFinderContextMenu(path: app.path)
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
                        .font(Theme.Font.bodySmall.weight(.medium))
                        .foregroundStyle(Theme.Colors.secondary)
                }
                .buttonStyle(.plain)

                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 40, height: 40)
                        .cornerRadius(Theme.Radius.md)
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
                VStack(spacing: Theme.Spacing.md) {
                    ProgressView()
                        .controlSize(.regular)
                    Text("Scanning for leftovers...")
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Colors.muted)
                }
                Spacer()
            } else if viewModel.leftovers.isEmpty {
                Spacer()
                VStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "checkmark.circle")
                        .font(.largeTitle)
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

            if let error = viewModel.errorMessage {
                ErrorBanner(message: error, onDismiss: { viewModel.errorMessage = nil })
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.md)
            }

            // Uninstall action bar
            actionBar(
                label: "Total: \(Formatters.fileSize(app.size + viewModel.totalLeftoverSize))",
                buttonTitle: "Uninstall",
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
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Colors.secondary)
                    .frame(width: 16)
                Text(group.category.rawValue)
                    .font(Theme.Font.bodyMedium)
                Spacer()
                Text(Formatters.fileSize(group.items.reduce(0) { $0 + $1.size }))
                    .font(Theme.Font.monoSmall)
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
                        .font(Theme.Font.monoSmall)
                        .foregroundStyle(Theme.Colors.muted)
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.leading, 20)
                .revealInFinderContextMenu(path: item.path)
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
        case .launchItems: return "gearshape.2"
        case .other: return "ellipsis.circle"
        }
    }

    // MARK: - Brew Packages

    private var brewPackagesSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "mug")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Colors.secondary)
                Text("Homebrew Packages")
                    .font(Theme.Font.bodyMedium)
                    .foregroundStyle(Theme.Colors.foreground)
                Text("(\(viewModel.filteredBrewPackages.count))")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Colors.muted)
                Spacer()
                Picker("", selection: Binding(
                    get: { viewModel.brewFilter },
                    set: { viewModel.updateBrewFilter($0) }
                )) {
                    ForEach(UninstallViewModel.BrewFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.xs)

            ForEach(viewModel.filteredBrewPackages) { pkg in
                brewRow(pkg)
                Divider().padding(.leading, 72)
            }
        }
    }

    private func brewRow(_ pkg: BrewPackage) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Toggle("", isOn: Binding(
                get: { viewModel.isBrewSelected(pkg) },
                set: { _ in viewModel.toggleBrewPackage(pkg) }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()

            Button {
                viewModel.selectBrewPackage(pkg)
            } label: {
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: pkg.installedOnRequest ? "shippingbox.fill" : "shippingbox")
                        .font(.title2)
                        .foregroundStyle(pkg.installedOnRequest ? Theme.Colors.accent : Theme.Colors.secondary)
                        .frame(width: 32, height: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: Theme.Spacing.xs) {
                            Text(pkg.name)
                                .font(Theme.Font.bodyMedium)
                                .foregroundStyle(Theme.Colors.foreground)
                                .lineLimit(1)
                            Text(pkg.version)
                                .font(Theme.Font.caption)
                                .foregroundStyle(Theme.Colors.muted)
                            if !pkg.installedOnRequest {
                                Text("dep")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(Theme.Colors.warning)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Theme.Colors.warning.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                            }
                        }
                        Text(pkg.description)
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Colors.muted)
                            .lineLimit(1)
                    }

                    Spacer()

                    if !pkg.dependencies.isEmpty || !pkg.dependents.isEmpty {
                        Text("\(pkg.dependencies.count + pkg.dependents.count) links")
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Colors.muted)
                    }

                    Text(Formatters.fileSize(pkg.size))
                        .font(Theme.Font.monoSmall)
                        .foregroundStyle(Theme.Colors.secondary)

                    Image(systemName: "chevron.right")
                        .font(Theme.Font.smallMedium)
                        .foregroundStyle(Theme.Colors.muted)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.sm)
    }

    // MARK: - Brew Package Detail

    private func brewPackageDetailView(_ pkg: BrewPackage) -> some View {
        VStack(spacing: 0) {
            // Back button + package info header
            HStack(spacing: Theme.Spacing.md) {
                Button {
                    viewModel.deselectBrewPackage()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(Theme.Font.bodySmall.weight(.medium))
                        .foregroundStyle(Theme.Colors.secondary)
                }
                .buttonStyle(.plain)

                Image(systemName: pkg.installedOnRequest ? "shippingbox.fill" : "shippingbox")
                    .font(.largeTitle)
                    .foregroundStyle(pkg.installedOnRequest ? Theme.Colors.accent : Theme.Colors.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Theme.Spacing.xs) {
                        Text(pkg.name)
                            .font(Theme.Font.title)
                        Text(pkg.version)
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Colors.muted)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.Colors.muted.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
                    }
                    Text(pkg.description)
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Colors.muted)
                        .lineLimit(2)
                }

                Spacer()

                Text(Formatters.fileSize(pkg.size))
                    .font(Theme.Font.mono)
                    .foregroundStyle(Theme.Colors.secondary)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    // Info badges
                    brewInfoBadges(pkg)

                    // Cellar path
                    if let cellarPath = viewModel.cellarPath(for: pkg) {
                        brewInfoRow(icon: "folder", label: "Install path", value: cellarPath)
                    }

                    // Dependencies section
                    if !pkg.dependencies.isEmpty {
                        brewDependencySection(
                            title: "Depends on",
                            icon: "arrow.down.circle",
                            names: pkg.dependencies,
                            accentColor: Theme.Colors.accent
                        )
                    }

                    // Dependents section
                    if !pkg.dependents.isEmpty {
                        brewDependencySection(
                            title: "Required by",
                            icon: "arrow.up.circle",
                            names: pkg.dependents,
                            accentColor: Theme.Colors.warning
                        )
                    }

                    // No relationships
                    if pkg.dependencies.isEmpty && pkg.dependents.isEmpty {
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: "checkmark.seal")
                                .foregroundStyle(Theme.Colors.success)
                            Text("No dependencies — safe to remove independently")
                                .font(Theme.Font.body)
                                .foregroundStyle(Theme.Colors.secondary)
                        }
                        .padding(.horizontal, Theme.Spacing.lg)
                    }
                }
                .padding(.vertical, Theme.Spacing.md)
            }

            if let error = viewModel.errorMessage {
                ErrorBanner(message: error, onDismiss: { viewModel.errorMessage = nil })
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.md)
            }

            // Uninstall action bar
            actionBar(
                label: "Size: \(Formatters.fileSize(pkg.size))" +
                    (pkg.dependents.isEmpty ? "" : " · \(pkg.dependents.count) dependent\(pkg.dependents.count == 1 ? "" : "s")"),
                buttonTitle: pkg.dependents.isEmpty ? "Uninstall" : "Uninstall (has dependents)",
                isWorking: viewModel.isUninstalling,
                action: {
                    viewModel.selectedBrewIds = [pkg.id]
                    viewModel.showBrewConfirmation = true
                }
            )
        }
    }

    private func brewInfoBadges(_ pkg: BrewPackage) -> some View {
        FlowLayout(spacing: Theme.Spacing.sm) {
            brewBadge(
                icon: pkg.installedOnRequest ? "checkmark.circle.fill" : "link",
                text: pkg.installedOnRequest ? "Installed on request" : "Installed as dependency",
                color: pkg.installedOnRequest ? Theme.Colors.success : Theme.Colors.muted
            )
            if pkg.isLeaf {
                brewBadge(icon: "leaf.fill", text: "Top-level (no dependents)", color: Theme.Colors.success)
            }
            if !pkg.dependencies.isEmpty {
                brewBadge(icon: "arrow.down.circle", text: "\(pkg.dependencies.count) dependenc\(pkg.dependencies.count == 1 ? "y" : "ies")", color: Theme.Colors.accent)
            }
            if !pkg.dependents.isEmpty {
                brewBadge(icon: "arrow.up.circle", text: "\(pkg.dependents.count) dependent\(pkg.dependents.count == 1 ? "" : "s")", color: Theme.Colors.warning)
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
    }

    private func brewBadge(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(Theme.Font.caption)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
    }

    private func brewInfoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Colors.secondary)
                .frame(width: 16)
            Text(label)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Colors.muted)
            Text(value)
                .font(Theme.Font.monoSmall)
                .foregroundStyle(Theme.Colors.foreground)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, Theme.Spacing.lg)
    }

    private func brewDependencySection(title: String, icon: String, names: [String], accentColor: Color) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: icon)
                    .font(Theme.Font.caption)
                    .foregroundStyle(accentColor)
                Text(title)
                    .font(Theme.Font.bodyMedium)
                Text("(\(names.count))")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Colors.muted)
            }
            .padding(.horizontal, Theme.Spacing.lg)

            ForEach(names, id: \.self) { name in
                if let resolved = viewModel.brewPackageByName(name) {
                    brewDepRow(resolved, accentColor: accentColor)
                } else {
                    brewDepRowUnresolved(name)
                }
                if name != names.last {
                    Divider().padding(.leading, 72)
                }
            }
        }
    }

    private func brewDepRow(_ pkg: BrewPackage, accentColor: Color) -> some View {
        Button {
            viewModel.selectBrewPackage(pkg)
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "shippingbox")
                    .font(.body)
                    .foregroundStyle(accentColor.opacity(0.7))
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: Theme.Spacing.xs) {
                        Text(pkg.name)
                            .font(Theme.Font.bodyMedium)
                            .foregroundStyle(Theme.Colors.foreground)
                        Text(pkg.version)
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Colors.muted)
                    }
                    if !pkg.description.isEmpty {
                        Text(pkg.description)
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Colors.muted)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Text(Formatters.fileSize(pkg.size))
                    .font(Theme.Font.monoSmall)
                    .foregroundStyle(Theme.Colors.muted)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.Colors.muted)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.leading, Theme.Spacing.md)
        .padding(.vertical, 4)
    }

    private func brewDepRowUnresolved(_ name: String) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "shippingbox")
                .font(.body)
                .foregroundStyle(Theme.Colors.muted.opacity(0.5))
                .frame(width: 24, height: 24)

            Text(name)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Colors.muted)

            Spacer()

            Text("not found")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Colors.muted.opacity(0.6))
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.leading, Theme.Spacing.md)
        .padding(.vertical, 4)
    }
}
