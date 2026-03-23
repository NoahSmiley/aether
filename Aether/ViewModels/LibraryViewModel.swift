import Foundation

@MainActor
@Observable
class LibraryViewModel {
    var items: [BaseItemDto] = []
    var totalCount = 0
    var isLoading = false
    var isLoadingMore = false
    var sortBy: String = "SortName"
    var sortOrder: String = "Ascending"
    var selectedGenre: String?
    var error: String?

    private let api = JellyfinAPI.shared
    private let parentId: String
    private let includeTypes: [String]?
    private var startIndex = 0

    init(parentId: String, includeTypes: [String]? = nil) {
        self.parentId = parentId
        self.includeTypes = includeTypes
    }

    func loadItems() async {
        isLoading = true
        error = nil
        startIndex = 0
        items = []

        do {
            let result = try await api.getItems(
                parentId: parentId,
                includeTypes: includeTypes,
                sortBy: sortBy,
                sortOrder: sortOrder,
                limit: LumaConfig.pageSize,
                startIndex: 0,
                genres: selectedGenre
            )
            items = result.items
            totalCount = result.totalRecordCount
            startIndex = result.items.count
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func loadMoreIfNeeded(currentItem: BaseItemDto) async {
        // Trigger when within the last 10 items
        guard let index = items.firstIndex(where: { $0.id == currentItem.id }) else { return }
        let threshold = items.count - 10
        guard index >= threshold else { return }
        guard !isLoadingMore, startIndex < totalCount else { return }

        isLoadingMore = true

        do {
            let result = try await api.getItems(
                parentId: parentId,
                includeTypes: includeTypes,
                sortBy: sortBy,
                sortOrder: sortOrder,
                limit: LumaConfig.pageSize,
                startIndex: startIndex,
                genres: selectedGenre
            )
            items.append(contentsOf: result.items)
            totalCount = result.totalRecordCount
            startIndex += result.items.count
        } catch {
            self.error = error.localizedDescription
        }
        isLoadingMore = false
    }

    func changeSort(_ sort: String) async {
        sortBy = sort
        await loadItems()
    }

    func toggleSortOrder() async {
        sortOrder = sortOrder == "Ascending" ? "Descending" : "Ascending"
        await loadItems()
    }

    func filterByGenre(_ genre: String?) async {
        selectedGenre = genre
        await loadItems()
    }
}
