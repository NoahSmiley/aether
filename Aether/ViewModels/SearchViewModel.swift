import Foundation

@MainActor
@Observable
class SearchViewModel {
    var query: String = "" {
        didSet {
            debounceSearch()
        }
    }
    var results: [BaseItemDto] = []
    var isSearching = false
    var error: String?

    var movies: [BaseItemDto] {
        results.filter { $0.type == .movie }
    }

    var shows: [BaseItemDto] {
        results.filter { $0.type == .series }
    }

    var episodes: [BaseItemDto] {
        results.filter { $0.type == .episode }
    }

    private let api = JellyfinAPI.shared
    private var debounceTask: Task<Void, Never>?

    func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            return
        }

        isSearching = true
        error = nil

        do {
            results = try await api.search(term: trimmed, limit: 50).items
        } catch {
            self.error = error.localizedDescription
        }
        isSearching = false
    }

    private func debounceSearch() {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: .seconds(LumaConfig.searchDebounceInterval))
            guard !Task.isCancelled else { return }
            await search()
        }
    }
}
