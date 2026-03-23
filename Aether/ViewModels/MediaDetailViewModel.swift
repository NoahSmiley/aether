import Foundation

@MainActor
@Observable
class MediaDetailViewModel {
    var item: BaseItemDto?
    var seasons: [BaseItemDto] = []
    var episodes: [BaseItemDto] = []
    var similarItems: [BaseItemDto] = []
    var selectedSeasonId: String?
    var isLoading = false
    var error: String?

    private let api = JellyfinAPI.shared

    func loadItem(id: String) async {
        isLoading = true
        error = nil

        do {
            item = try await api.getItem(id: id)

            // If this is a series, also load seasons and similar items
            if let item, item.type == .series {
                async let seasonsResult: Void = loadSeasons(seriesId: item.id)
                async let similarResult: Void = loadSimilar(itemId: item.id)
                _ = await (seasonsResult, similarResult)
            } else if let item, item.type == .movie {
                await loadSimilar(itemId: item.id)
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func loadSeasons(seriesId: String) async {
        do {
            seasons = try await api.getSeasons(seriesId: seriesId).items

            // Select the first unwatched season, or the first season
            if let firstUnwatched = seasons.first(where: { $0.userData?.played != true }) {
                selectedSeasonId = firstUnwatched.id
            } else {
                selectedSeasonId = seasons.first?.id
            }

            // Load episodes for the selected season
            if let seasonId = selectedSeasonId {
                await loadEpisodes(seriesId: seriesId, seasonId: seasonId)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadEpisodes(seriesId: String, seasonId: String) async {
        do {
            episodes = try await api.getEpisodes(seriesId: seriesId, seasonId: seasonId).items
        } catch {
            self.error = error.localizedDescription
        }
    }

    func selectSeason(_ seasonId: String) async {
        guard seasonId != selectedSeasonId else { return }
        selectedSeasonId = seasonId

        if let seriesId = item?.id ?? item?.seriesId {
            await loadEpisodes(seriesId: seriesId, seasonId: seasonId)
        }
    }

    func loadSimilar(itemId: String) async {
        do {
            similarItems = try await api.getSimilar(itemId: itemId, limit: 12).items
        } catch {
            // Similar items are non-critical; silently ignore errors
        }
    }

    func toggleWatched() async {
        guard let item else { return }
        let isPlayed = item.userData?.played ?? false

        do {
            if isPlayed {
                try await api.markUnplayed(itemId: item.id)
            } else {
                try await api.markPlayed(itemId: item.id)
            }
            // Refresh item to get updated userData
            await loadItem(id: item.id)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func toggleFavorite() async {
        guard let item else { return }
        let isFavorite = item.userData?.isFavorite ?? false

        do {
            try await api.toggleFavorite(itemId: item.id, isFavorite: !isFavorite)
            // Refresh item to get updated userData
            await loadItem(id: item.id)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
