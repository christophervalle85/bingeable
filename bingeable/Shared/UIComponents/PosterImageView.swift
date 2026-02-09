import SwiftUI

struct PosterImageView: View {
    @Environment(\.displayScale) private var displayScale

    let posterPath: String?
    let width: CGFloat
    let height: CGFloat

    init(posterPath: String?, width: CGFloat = 64, height: CGFloat = 96) {
        self.posterPath = posterPath
        self.width = width
        self.height = height
    }

    var body: some View {
        AsyncImage(url: posterURL) { phase in
            switch phase {
            case let .success(image):
                image
                    .resizable()
                    .scaledToFill()
            case .empty:
                placeholder
            case .failure:
                placeholder
            @unknown default:
                placeholder
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        }
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.quaternary)
            Image(systemName: "tv")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private var posterURL: URL? {
        guard let posterPath, !posterPath.isEmpty else {
            return nil
        }

        let normalizedPath: String
        if posterPath.hasPrefix("/") {
            normalizedPath = String(posterPath.dropFirst())
        } else {
            normalizedPath = posterPath
        }

        // For posters, request based on rendered width and clamp DPR to reduce decode pressure in scrolling lists.
        let requestedPixels = Int(width * min(displayScale, 2.0))
        let size = posterSizeForTMDB(requestedPixels: requestedPixels)

        return AppConfiguration.tmdbImageBaseURL
            .appendingPathComponent(size)
            .appendingPathComponent(normalizedPath)
    }

    private func posterSizeForTMDB(requestedPixels: Int) -> String {
        // TMDB poster size tiers. Pick the smallest tier that satisfies the rendered size.
        let supported = [92, 154, 185, 342, 500]
        if let match = supported.first(where: { requestedPixels <= $0 }) {
            return "w\(match)"
        }
        // Avoid very large poster variants to reduce decode/memory spikes in scrolling views.
        return "w500"
    }
}
