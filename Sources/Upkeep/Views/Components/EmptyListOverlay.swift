import SwiftUI

struct EmptyListOverlay: View {
    let icon: String
    let title: String
    let message: String
    let buttonLabel: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.upkeepAmber.opacity(0.5))
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.caption)
                .foregroundStyle(.tertiary)
            Button(buttonLabel, action: action)
                .buttonStyle(.borderedProminent)
                .tint(.upkeepAmber)
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
