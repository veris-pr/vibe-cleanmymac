import SwiftUI

struct ModuleCard: View {
    let summary: ModuleScanSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: summary.module.icon)
                    .font(.title3)
                    .foregroundStyle(summary.module.color)
                Text(summary.module.rawValue)
                    .font(.headline)
                Spacer()
                if summary.hasIssues {
                    Text("\(summary.itemCount)")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(summary.module.color.opacity(0.2))
                        .clipShape(Capsule())
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            if summary.totalSize > 0 {
                Text(Formatters.fileSize(summary.totalSize))
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(summary.module.color)
            }

            if !summary.issues.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(summary.issues.prefix(3), id: \.self) { issue in
                        Text("• \(issue)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            } else {
                Text("No issues found")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
