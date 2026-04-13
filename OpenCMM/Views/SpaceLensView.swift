import SwiftUI

struct SpaceLensView: View {
    @ObservedObject var viewModel: SpaceLensViewModel

    var body: some View {
        VStack(spacing: 0) {
            moduleHeader(
                icon: "circle.grid.cross",
                title: "Disk Map",
                subtitle: "See what's taking up space"
            )

            Divider()

            if viewModel.isScanning {
                Spacer()
                VStack(spacing: Theme.Spacing.md) {
                    ProgressView()
                        .controlSize(.regular)
                    Text("Analyzing disk usage...")
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Colors.muted)
                }
                Spacer()
            } else if let root = viewModel.rootNode {
                // Dependency banner
                DependencyBanner(
                    toolName: "gdu",
                    description: "Fast disk usage analyzer for detailed scanning.",
                    isInstalled: viewModel.isGduInstalled,
                    isInstalling: viewModel.isInstallingGdu,
                    installError: viewModel.installError,
                    installAction: { Task { await viewModel.installGdu() } }
                )
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.md)

                // Total size header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(root.name)
                            .font(Theme.Font.heading)
                            .foregroundStyle(Theme.Colors.foreground)
                        Text(Formatters.fileSize(root.size))
                            .font(Theme.Font.mono)
                            .foregroundStyle(Theme.Colors.secondary)
                    }
                    Spacer()
                    Button("Refresh") { Task { await viewModel.scan() } }
                        .font(Theme.Font.bodyMedium)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, Theme.Spacing.md)

                // Directory tree
                List {
                    ForEach(root.children.prefix(50)) { node in
                        SpaceLensRow(node: node, parentSize: root.size, depth: 0)
                    }
                }
                .listStyle(.inset)
            } else {
                // Dependency banner before scan
                DependencyBanner(
                    toolName: "gdu",
                    description: "Fast disk usage analyzer. Without it, a slower native scanner is used.",
                    isInstalled: viewModel.isGduInstalled,
                    isInstalling: viewModel.isInstallingGdu,
                    installError: viewModel.installError,
                    installAction: { Task { await viewModel.installGdu() } }
                )
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.md)

                Spacer()
                EmptyStateView(
                    icon: "circle.grid.cross",
                    message: "Analyze disk usage",
                    detail: "Create a visual map of your hard drive to see which folders and files are taking up the most space.",
                    buttonTitle: "Scan",
                    action: { Task { await viewModel.scan() } }
                )
                Spacer()
            }
        }
        .background(Theme.Colors.background)
        .task { await viewModel.checkDependencies() }
    }
}

struct SpaceLensRow: View {
    let node: SpaceLensService.DiskNode
    let parentSize: Int64
    let depth: Int
    @State private var isExpanded = false

    private var barWidth: CGFloat {
        let pct = node.percentage(of: parentSize)
        return CGFloat(min(max(pct, 2), 100))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { if node.isDirectory && !node.children.isEmpty { isExpanded.toggle() } }) {
                HStack(spacing: Theme.Spacing.sm) {
                    if node.isDirectory && !node.children.isEmpty {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.Colors.muted)
                            .frame(width: 14)
                    } else {
                        Spacer().frame(width: 14)
                    }

                    Image(systemName: node.isDirectory ? "folder" : "doc")
                        .font(.system(size: 12))
                        .foregroundStyle(node.isDirectory ? Theme.Colors.secondary : Theme.Colors.muted)
                        .frame(width: 18)

                    VStack(alignment: .leading, spacing: 2) {
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

                        // Size bar
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Theme.Colors.secondary.opacity(0.3))
                                .frame(width: geo.size.width * barWidth / 100, height: 3)
                        }
                        .frame(height: 3)
                    }
                }
                .padding(.leading, CGFloat(depth) * 16)
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(node.children.prefix(20)) { child in
                    SpaceLensRow(node: child, parentSize: node.size, depth: depth + 1)
                        .padding(.top, 2)
                }
            }
        }
        .contextMenu {
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: node.path)])
            }
        }
    }
}
