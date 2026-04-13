import SwiftUI

struct ScanButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Font.bodyMedium)
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Color.primary.opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        }
        .buttonStyle(.plain)
    }
}
