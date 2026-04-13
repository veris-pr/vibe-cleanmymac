import SwiftUI

struct ModuleCard: View {
    let summary: ModuleScanSummary
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button(action: { onTap?() }) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: summary.module.icon)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Theme.Colors.secondary)
                        .frame(width: 24)
                    Text(summary.module.rawValue)
                        .font(Theme.Font.heading)
                        .foregroundStyle(Theme.Colors.foreground)
                    Spacer()
                    if summary.hasIssues {
                        Text("\(summary.itemCount)")
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Colors.muted)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Theme.Colors.subtle)
                            .clipShape(Capsule())
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.Colors.success)
                    }
                }

                if summary.totalSize > 0 {
                    Text(Formatters.fileSize(summary.totalSize))
                        .font(Theme.Font.mono)
                        .foregroundStyle(Theme.Colors.secondary)
                }

                if !summary.issues.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(summary.issues.prefix(3), id: \.self) { issue in
                            Text("· \(issue)")
                                .font(Theme.Font.caption)
                                .foregroundStyle(Theme.Colors.muted)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .cardStyle()
        }
        .buttonStyle(.plain)
    }
}
