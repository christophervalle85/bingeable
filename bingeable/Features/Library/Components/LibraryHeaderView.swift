import SwiftUI

struct LibraryHeaderView: View {
    let summary: LibraryViewModel.LibrarySummary
    let isHydrating: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("LIBRARY HUB")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)

                    Text("Your Queue")
                        .font(.system(.largeTitle, design: .serif).weight(.bold))
                        .foregroundStyle(.primary)

                    Text(summary.totalCount == 1 ? "1 show tracked" : "\(summary.totalCount) shows tracked")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("library-total-count")
                }

                Spacer(minLength: 12)

                if isHydrating {
                    Label("Updating", systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.16), in: Capsule())
                        .accessibilityIdentifier("library-hydrating")
                }
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 104), spacing: 10)],
                spacing: 10
            ) {
                statCard(
                    title: "Ready",
                    value: summary.readyCount,
                    systemImage: "sparkles.tv",
                    tint: .green,
                    identifier: "library-stat-ready"
                )

                statCard(
                    title: "Watching",
                    value: summary.watchingCount,
                    systemImage: "play.circle.fill",
                    tint: .blue,
                    identifier: "library-stat-watching"
                )

                statCard(
                    title: "Waiting",
                    value: summary.waitingCount,
                    systemImage: "clock.fill",
                    tint: .orange,
                    identifier: "library-stat-waiting"
                )
            }
        }
        .padding(18)
        .background(headerBackground)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("library-header")
    }

    private func statCard(
        title: String,
        value: Int,
        systemImage: String,
        tint: Color,
        identifier: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: systemImage)
                Text(title)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)

            Text("\(value)")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .fontWidth(.condensed)
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .frame(minHeight: 64, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tint.opacity(0.2), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }

    private var headerBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            }
    }
}
