import SwiftUI

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

func actionBar(label: String, buttonTitle: String, isWorking: Bool, action: @escaping () -> Void) -> some View {
    VStack(spacing: 0) {
        Divider()
        HStack {
            Text(label)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Colors.muted)
            Spacer()
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

// MARK: - Empty State

struct EmptyStateView: View {
    let icon: String
    let message: String
    let detail: String
    let buttonTitle: String
    var buttonIcon: String = "arrow.right"
    let action: () -> Void

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

            ScanButton(title: buttonTitle, icon: buttonIcon, action: action)
                .padding(.top, Theme.Spacing.sm)
        }
    }
}

// MARK: - Success State

struct SuccessStateView: View {
    let message: String
    let detail: String?
    let action: () -> Void

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

            Button("Scan Again", action: action)
                .font(Theme.Font.bodyMedium)
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .padding(.top, Theme.Spacing.xs)
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

// MARK: - File Row

struct FileRow: View {
    let icon: String
    let name: String
    let path: String
    let trailing: String

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Theme.Colors.muted)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Colors.foreground)
                Text(path)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Colors.muted.opacity(0.7))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Text(trailing)
                .font(Theme.Font.monoSmall)
                .foregroundStyle(Theme.Colors.secondary)
        }
        .padding(.vertical, 2)
    }
}
