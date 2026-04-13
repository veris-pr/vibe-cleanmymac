import SwiftUI

struct SpaceLensView: View {
    @ObservedObject var viewModel: SpaceLensViewModel

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            moduleHeader(
                icon: "circle.grid.cross",
                title: "Disk Map",
                subtitle: "See what's taking up space"
            )

            Divider()

            if let error = viewModel.errorMessage {
                ErrorBanner(message: error, onDismiss: { viewModel.errorMessage = nil })
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.md)
            }

            // MARK: - Body
            if viewModel.isScanning && viewModel.currentNode == nil {
                Spacer()
                VStack(spacing: Theme.Spacing.md) {
                    ProgressView()
                        .controlSize(.regular)
                    Text("Analyzing disk usage...")
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Colors.muted)
                }
                Spacer()
            } else if let current = viewModel.currentNode {
                breadcrumbBar
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.vertical, Theme.Spacing.sm)

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(current.name)
                            .font(Theme.Font.heading)
                            .foregroundStyle(Theme.Colors.foreground)
                        Text(Formatters.fileSize(current.size))
                            .font(Theme.Font.mono)
                            .foregroundStyle(Theme.Colors.secondary)
                    }
                    Spacer()
                    if viewModel.isScanning {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, Theme.Spacing.sm)

                List {
                    ForEach(current.children) { node in
                        SpaceLensRow(
                            node: node,
                            parentSize: current.size,
                            onTap: {
                                if node.isDirectory {
                                    viewModel.expandDirectory(node)
                                }
                            }
                        )
                    }
                }
                .listStyle(.inset)
            } else {
                Spacer()
                EmptyStateView(
                    icon: "circle.grid.cross",
                    message: "Analyze disk usage",
                    detail: "Scan your home folder to see which directories and files are taking up the most space. Click any folder to explore deeper."
                )
                Spacer()
            }

            // MARK: - Footer
            if viewModel.isScanning && viewModel.currentNode == nil {
                footerBar {
                    ghostButton("Stop") { viewModel.cancelScan() }
                }
            } else if viewModel.currentNode != nil {
                footerBar {
                    ghostButton("Rescan") { viewModel.startScan() }
                }
            } else {
                footerBar {
                    ScanButton(title: "Start Scan") { viewModel.startScan() }
                }
            }
        }
        .background(Theme.Colors.background)
    }

    // MARK: - Breadcrumbs

    private var breadcrumbBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(viewModel.breadcrumbs.enumerated()), id: \.offset) { index, crumb in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.Colors.muted)
                    }

                    Button {
                        viewModel.navigateTo(index: index)
                    } label: {
                        Text(crumb.name)
                            .font(Theme.Font.caption)
                            .foregroundStyle(index == viewModel.breadcrumbs.count - 1 ? Theme.Colors.foreground : Theme.Colors.secondary)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Row

struct SpaceLensRow: View {
    let node: DiskNode
    let parentSize: Int64
    let onTap: () -> Void

    private var barFraction: CGFloat {
        let pct = node.percentage(of: parentSize)
        return CGFloat(min(max(pct, 1), 100)) / 100
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: node.isDirectory ? "folder.fill" : "doc")
                    .font(.system(size: 14))
                    .foregroundStyle(node.isDirectory ? Theme.Colors.secondary : Theme.Colors.muted)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(node.name)
                            .font(Theme.Font.body)
                            .foregroundStyle(Theme.Colors.foreground)
                            .lineLimit(1)
                        Spacer()
                        Text(Formatters.fileSize(node.size))
                            .font(Theme.Font.monoSmall)
                            .foregroundStyle(Theme.Colors.secondary)
                        Text(String(format: "%.1f%%", node.percentage(of: parentSize)))
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Colors.muted)
                            .frame(width: 48, alignment: .trailing)
                    }

                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(node.isDirectory ? Theme.Colors.secondary.opacity(0.4) : Theme.Colors.muted.opacity(0.3))
                            .frame(width: geo.size.width * barFraction, height: 3)
                    }
                    .frame(height: 3)
                }

                if node.isDirectory {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.Colors.muted)
                }
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .revealInFinderContextMenu(path: node.path)
    }
}
