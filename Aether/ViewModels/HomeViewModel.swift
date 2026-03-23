import SwiftUI

@MainActor
@Observable
class HomeViewModel {
    var continueWatching: [BaseItemDto] = []
    var nextUp: [BaseItemDto] = []
    var recentlyAdded: [BaseItemDto] = []
    var libraries: [BaseItemDto] = []
    var heroItems: [BaseItemDto] = []
    var currentHeroIndex: Int = 0
    var isLoading = false
    var error: String?

    private let api = JellyfinAPI.shared
    private var heroTimer: Timer?

    func loadAll() async {
        isLoading = true
        error = nil

        do {
            async let watchingResult = loadContinueWatching()
            async let nextUpResult = loadNextUp()
            async let recentResult = loadRecentlyAdded()
            async let librariesResult = loadLibraries()

            _ = await (watchingResult, nextUpResult, recentResult, librariesResult)
        }

        // Build hero items from recently added that have backdrop images
        heroItems = recentlyAdded
            .filter { $0.backdropImageTags?.isEmpty == false || $0.parentBackdropImageTags?.isEmpty == false }
            .prefix(6)
            .map { $0 }

        // Reset index if needed
        if currentHeroIndex >= heroItems.count {
            currentHeroIndex = 0
        }

        isLoading = false
    }

    func loadContinueWatching() async {
        do {
            continueWatching = try await api.getResumeItems(limit: 20).items
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadNextUp() async {
        do {
            nextUp = try await api.getNextUp(limit: 20).items
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadRecentlyAdded() async {
        do {
            recentlyAdded = try await api.getLatestItems(parentId: nil, limit: 20)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadLibraries() async {
        do {
            libraries = try await api.getLibraries()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func startHeroTimer() {
        stopHeroTimer()
        guard heroItems.count > 1 else { return }

        heroTimer = Timer.scheduledTimer(withTimeInterval: AetherConfig.heroBannerInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.heroItems.isEmpty else { return }
                withAnimation(.easeInOut(duration: 0.8)) {
                    self.currentHeroIndex = (self.currentHeroIndex + 1) % self.heroItems.count
                }
            }
        }
    }

    func stopHeroTimer() {
        heroTimer?.invalidate()
        heroTimer = nil
    }
}
