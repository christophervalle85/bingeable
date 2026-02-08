import SwiftUI

struct BingeableBadgeView: View {
    let state: BingeableState

    var body: some View {
        Text(state.title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor.opacity(0.15), in: Capsule())
            .foregroundStyle(backgroundColor)
    }

    private var backgroundColor: Color {
        switch state {
        case .ready:
            return .green
        case .notYet:
            return .orange
        case .tbd:
            return .gray
        }
    }
}
