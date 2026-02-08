import SwiftUI

struct DiscoverQuickSaveButton: View {
    let isSaved: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isSaved ? "bookmark.fill" : "plus.circle.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(isSaved ? Color.yellow : Color.white)
                .frame(width: 38, height: 38)
                .background(.ultraThinMaterial, in: Circle())
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.32), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSaved ? "Remove from library" : "Save to library")
    }
}
