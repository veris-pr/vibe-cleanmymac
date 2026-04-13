import SwiftUI

// MARK: - Design Tokens

enum Theme {
    // Typography
    enum Font {
        static let largeTitle = SwiftUI.Font.system(size: 28, weight: .semibold, design: .default)
        static let title = SwiftUI.Font.system(size: 20, weight: .semibold, design: .default)
        static let heading = SwiftUI.Font.system(size: 15, weight: .medium, design: .default)
        static let body = SwiftUI.Font.system(size: 13, weight: .regular, design: .default)
        static let bodyMedium = SwiftUI.Font.system(size: 13, weight: .medium, design: .default)
        static let caption = SwiftUI.Font.system(size: 11, weight: .regular, design: .default)
        static let mono = SwiftUI.Font.system(size: 13, weight: .medium, design: .monospaced)
        static let monoSmall = SwiftUI.Font.system(size: 11, weight: .regular, design: .monospaced)
        static let stat = SwiftUI.Font.system(size: 32, weight: .semibold, design: .rounded)
    }

    // Colors — greyscale with minimal accent
    enum Colors {
        static let foreground = Color.primary
        static let secondary = Color.secondary
        static let muted = Color.primary.opacity(0.45)
        static let subtle = Color.primary.opacity(0.06)
        static let border = Color.primary.opacity(0.08)
        static let cardBackground = Color(nsColor: .controlBackgroundColor)
        static let background = Color(nsColor: .windowBackgroundColor)
        static let destructive = Color(red: 0.9, green: 0.26, blue: 0.2)
        static let success = Color(red: 0.18, green: 0.72, blue: 0.35)
        static let warning = Color(red: 0.95, green: 0.68, blue: 0.0)  // Amber
        static let info = Color(red: 0.45, green: 0.55, blue: 0.65)     // Blue-grey
        static let accent = Color.primary.opacity(0.85)
    }

    // Spacing
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48
    }

    // Animation
    enum Animation {
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.25)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.5)
        static let spring = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.8)
    }

    // Radii
    enum Radius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
    }
}

// MARK: - Reusable Modifiers

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Theme.Spacing.lg)
            .background(Theme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .stroke(Theme.Colors.border, lineWidth: 1)
            )
    }
}

struct BadgeStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(Theme.Font.caption)
            .foregroundStyle(Theme.Colors.muted)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Theme.Colors.subtle)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
    }
}

extension View {
    func cardStyle() -> some View { modifier(CardStyle()) }
    func badgeStyle() -> some View { modifier(BadgeStyle()) }
}
