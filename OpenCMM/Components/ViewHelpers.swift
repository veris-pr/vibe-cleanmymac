import SwiftUI

// Shared view helpers used across module views

func moduleHeader(icon: String, color: Color, title: String, subtitle: String) -> some View {
    HStack(spacing: 12) {
        Image(systemName: icon)
            .font(.system(size: 28))
            .foregroundStyle(color)
            .frame(width: 40)

        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.title2.bold())
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        Spacer()
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 16)
}

func actionBar(label: String, buttonTitle: String, buttonColor: Color, isWorking: Bool, action: @escaping () -> Void) -> some View {
    VStack(spacing: 0) {
        Divider()
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Button(action: action) {
                if isWorking {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.horizontal, 8)
                } else {
                    Text(buttonTitle)
                        .padding(.horizontal, 16)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(buttonColor)
            .disabled(isWorking)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }
    .background(.bar)
}
