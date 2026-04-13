import SwiftUI

struct ProgressRing: View {
    let progress: Double  // 0.0 to 1.0
    var size: CGFloat = 60
    var lineWidth: CGFloat = 6
    var showPercentage: Bool = true
    var thresholds: Bool = false  // Enable green/yellow/red coloring

    private var ringColor: Color {
        guard thresholds else { return Color.primary.opacity(0.7) }
        let pct = progress * 100
        if pct < 60 { return Theme.Colors.success }
        if pct < 80 { return Theme.Colors.warning }
        return Theme.Colors.destructive
    }

    // Inverted thresholds (for health score: high = good)
    var invertedThresholds: Bool = false
    private var displayColor: Color {
        guard thresholds else { return Color.primary.opacity(0.7) }
        if invertedThresholds {
            let pct = progress * 100
            if pct >= 70 { return Theme.Colors.success }
            if pct >= 40 { return Theme.Colors.warning }
            return Theme.Colors.destructive
        }
        return ringColor
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.Colors.border, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(displayColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(Theme.Animation.slow, value: progress)
            if showPercentage {
                Text("\(Int(progress * 100))")
                    .font(.system(size: size * 0.28, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.Colors.foreground)
            }
        }
        .frame(width: size, height: size)
    }
}
