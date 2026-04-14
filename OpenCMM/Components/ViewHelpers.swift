import SwiftUI

// MARK: - Reveal in Finder Context Menu

extension View {
    func revealInFinderContextMenu(path: String) -> some View {
        self.contextMenu {
            Button {
                NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
            } label: {
                Label("Reveal in Finder", systemImage: "folder")
            }
        }
    }
}

// MARK: - Module Header

func moduleHeader(icon: String, title: String, subtitle: String) -> some View {
    HStack(spacing: Theme.Spacing.md) {
        Image(systemName: icon)
            .font(.system(size: 20, weight: .regular))
            .foregroundStyle(Theme.Colors.secondary)
            .frame(width: 28)

        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(Theme.Font.title)
                .foregroundStyle(Theme.Colors.foreground)
            Text(subtitle)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Colors.muted)
        }
        Spacer()
    }
    .padding(.horizontal, Theme.Spacing.xl)
    .padding(.vertical, Theme.Spacing.lg)
}

// MARK: - Action Bar

func actionBar(label: String, buttonTitle: String, isWorking: Bool, action: @escaping () -> Void, secondaryTitle: String? = nil, secondaryAction: (() -> Void)? = nil) -> some View {
    VStack(spacing: 0) {
        Divider()
        HStack {
            Text(label)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Colors.muted)
            Spacer()
            if let secondaryTitle, let secondaryAction {
                ghostButton(secondaryTitle, action: secondaryAction)
                    .disabled(isWorking)
            }
            Button(action: action) {
                HStack(spacing: 6) {
                    if isWorking {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(isWorking ? "Working..." : buttonTitle)
                        .font(Theme.Font.bodyMedium)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(isWorking ? Color.primary.opacity(0.4) : Color.primary.opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
            }
            .buttonStyle(.plain)
            .disabled(isWorking)
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.md)
    }
    .background(Theme.Colors.background)
}

/// Ghost (secondary) button — used standalone in footers.
func ghostButton(_ title: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Text(title)
            .font(Theme.Font.bodyMedium)
            .foregroundStyle(Theme.Colors.foreground)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Theme.Colors.subtle)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .stroke(Theme.Colors.border, lineWidth: 1)
            )
    }
    .buttonStyle(.plain)
}

/// Standard footer with just a ghost button (for empty/success states).
func footerBar(@ViewBuilder content: () -> some View) -> some View {
    VStack(spacing: 0) {
        Divider()
        HStack {
            Spacer()
            content()
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.md)
    }
    .background(Theme.Colors.background)
}

// MARK: - Empty State

struct EmptyStateView: View {
    let icon: String
    let message: String
    let detail: String

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 36, weight: .thin))
                .foregroundStyle(Theme.Colors.muted)

            VStack(spacing: Theme.Spacing.xs) {
                Text(message)
                    .font(Theme.Font.heading)
                    .foregroundStyle(Theme.Colors.foreground)

                Text(detail)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Colors.muted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }
        }
    }
}

// MARK: - Success State

struct SuccessStateView: View {
    let message: String
    let detail: String?

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "checkmark")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Theme.Colors.success)
                .padding(16)
                .background(Theme.Colors.success.opacity(0.08))
                .clipShape(Circle())

            Text(message)
                .font(Theme.Font.heading)
                .foregroundStyle(Theme.Colors.foreground)

            if let detail {
                Text(detail)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Colors.muted)
            }
        }
    }
}

// MARK: - Section Header Row

struct SectionHeaderRow: View {
    let title: String
    let trailing: String?
    var isOn: Binding<Bool>?

    var body: some View {
        HStack {
            if let isOn {
                Toggle(isOn: isOn) {
                    Text(title)
                        .font(Theme.Font.heading)
                        .foregroundStyle(Theme.Colors.foreground)
                }
                .toggleStyle(.checkbox)
            } else {
                Text(title)
                    .font(Theme.Font.heading)
                    .foregroundStyle(Theme.Colors.foreground)
            }
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(Theme.Font.monoSmall)
                    .foregroundStyle(Theme.Colors.muted)
            }
        }
    }
}

// MARK: - Dependency Banner

struct DependencyBanner: View {
    let toolName: String
    let description: String
    let isInstalled: Bool
    let isInstalling: Bool
    let installError: String?
    let installAction: () -> Void
    var version: String? = nil

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Circle()
                .fill(isInstalled ? Theme.Colors.success : Theme.Colors.muted.opacity(0.3))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(toolName)
                    .font(Theme.Font.bodyMedium)
                    .foregroundStyle(Theme.Colors.foreground)
                Text(description)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Colors.muted)
                    .lineLimit(1)
                if let error = installError {
                    Text(error)
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Colors.destructive)
                        .lineLimit(2)
                }
            }

            Spacer()

            if isInstalled {
                if let version {
                    Text(version)
                        .font(Theme.Font.monoSmall)
                        .foregroundStyle(Theme.Colors.muted)
                        .lineLimit(1)
                }
            } else {
                if isInstalling {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button("Install") {
                        installAction()
                    }
                    .font(Theme.Font.bodyMedium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(Color.primary.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .stroke(Theme.Colors.border, lineWidth: 1)
        )
    }
}

// MARK: - Error Banner

struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 13))
                .foregroundStyle(Theme.Colors.destructive)
            Text(message)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Colors.foreground)
                .lineLimit(2)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.Colors.muted)
            }
            .buttonStyle(.plain)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.destructive.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .stroke(Theme.Colors.destructive.opacity(0.2), lineWidth: 1)
        )
    }
}
