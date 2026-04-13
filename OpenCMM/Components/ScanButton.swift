import SwiftUI

struct ScanButton: View {
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: "magnifyingglass")
                .font(.title3)
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .tint(color)
        .controlSize(.large)
    }
}
