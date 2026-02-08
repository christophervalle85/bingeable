import Foundation
import Combine

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var results: [Show] = []
    @Published var isSearching = false
    @Published var errorMessage: String?

    func search(using repository: ShowRepository) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            errorMessage = nil
            return
        }

        isSearching = true
        errorMessage = nil

        do {
            results = try await repository.searchShows(query: trimmed)
        } catch {
            errorMessage = error.localizedDescription
            results = []
        }

        isSearching = false
    }
}
