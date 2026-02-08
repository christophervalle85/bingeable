import SwiftUI

struct DiscoverTopTabsView: View {
    @Binding var activeSection: DiscoverViewModel.DiscoverActiveSection

    var body: some View {
        HStack(spacing: 8) {
            ForEach(DiscoverViewModel.DiscoverActiveSection.allCases) { section in
                Button {
                    activeSection = section
                } label: {
                    Text(section.title)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(activeSection == section ? Color.white : Color.primary)
                        .background {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(activeSection == section ? Color.blue.opacity(0.95) : Color.secondary.opacity(0.14))
                        }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("discover-tab-\(section.rawValue)")
                .accessibilityLabel(section.title)
                .accessibilityValue(activeSection == section ? "Selected" : "Not selected")
            }
        }
    }
}
