import SwiftUI

struct ModuleCard: View {
    let summary: ModuleScanSummary

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: summary.module.icon)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Theme.Colors.secondary)
                Text(summary.module.rawValue)
                    .font(Theme.Font.heading)
                    .foregroundStyle(Theme.Colors.foreground)
                Spacer()
                if summary.hasIssues {
                    Text("\(summary.itemCount)")
                        .badgeStyle()
                } else {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.Colors.success)
                }
            }

            if summary.totalSize > 0 {
                Text(Formatters.fileSize(summary.totalSize))
                    .font(Theme.Font.mono)
                    .foregroundStyle(Theme.Colors.foreground)
            }

            if !summary.issues.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(summary.issues.prefix(3), id: \.self) { issue in
                        Text(issue)
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Colors.muted)
                            .lineLimit(1)
                    }
                }
            } else {
                Text("No issues found")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Colors.success)
            }
        }
        .cardStyle()
    }
}
