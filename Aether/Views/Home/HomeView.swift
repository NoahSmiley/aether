import SwiftUI
import NukeUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @State private var liveTVViewModel = LiveTVViewModel()
    @State private var libraryItems: [String: [BaseItemDto]] = [:]

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.heroItems.isEmpty && viewModel.continueWatching.isEmpty {
                    loadingState
                } else if isLibraryEmpty {
                    emptyState
                } else {
                    contentView
                }
            }
            .background(LumaTheme.deepBlack.ignoresSafeArea())
            .navigationDestination(for: String.self) { itemId in
                DetailView(itemId: itemId)
            }
        }
        .task {
            await viewModel.loadAll()
            viewModel.startHeroTimer()
            await liveTVViewModel.loadAll()
            await loadLibraryItems()
        }
        .onDisappear {
            viewModel.stopHeroTimer()
        }
    }

    // MARK: - Content View

    private var contentView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 0) {
                // Logo centered at top
                HStack {
                    Spacer()
                    Image("LogoWhite")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 35, height: 35)
                        .opacity(0.85)
                    Spacer()
                }
                .padding(.bottom, LumaTheme.spacingMD)

                // Continue Watching
                if !viewModel.continueWatching.isEmpty {
                    homeMediaRow(
                        title: "Continue Watching",
                        items: viewModel.continueWatching,
                        style: .thumbnail
                    )
                    .padding(.bottom, LumaTheme.spacingXXL)
                }

                // Next Up
                if !viewModel.nextUp.isEmpty {
                    homeMediaRow(
                        title: "Next Up",
                        items: viewModel.nextUp,
                        style: .thumbnail
                    )
                    .padding(.bottom, LumaTheme.spacingXXL)
                }

                // Live TV — single highlights row on home
                if liveTVViewModel.isLoading {
                    SkeletonRow()
                        .padding(.bottom, LumaTheme.spacingXXL)
                } else {
                    let allLive = liveTVViewModel.nflChannels
                        + liveTVViewModel.golfChannels
                        + liveTVViewModel.sportsChannels
                    if !allLive.isEmpty {
                        homeLiveTVRow(title: "Live TV", channels: allLive)
                            .padding(.bottom, LumaTheme.spacingXXL)
                    }
                }

                // Recently Added
                if !viewModel.recentlyAdded.isEmpty {
                    homeMediaRow(
                        title: "Recently Added",
                        items: viewModel.recentlyAdded,
                        style: .poster
                    )
                    .padding(.bottom, LumaTheme.spacingXXL)
                }

                // Library rows
                ForEach(viewModel.libraries, id: \.id) { library in
                    if let items = libraryItems[library.id], !items.isEmpty {
                        homeMediaRow(
                            title: library.name ?? "Library",
                            items: items,
                            style: .poster
                        )
                        .padding(.bottom, LumaTheme.spacingXXL)
                    }
                }

                Spacer()
                    .frame(height: LumaTheme.spacingHuge)
            }
        }
        .ignoresSafeArea(edges: [.horizontal, .top])
    }

    // MARK: - Media Rows

    @ViewBuilder
    private func homeMediaRow(title: String, items: [BaseItemDto], style: HomeRowStyle) -> some View {
        VStack(alignment: .leading, spacing: LumaTheme.spacingSM) {
            Text(title)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(LumaTheme.textPrimary)
                .padding(.leading, 50)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: style == .poster ? 30 : 35) {
                    ForEach(items) { item in
                        NavigationLink(value: item.id) {
                            switch style {
                            case .poster:
                                PosterCard(item: item)
                            case .thumbnail:
                                ThumbnailCard(item: item)
                            }
                        }
                        .buttonStyle(.card)
                    }
                }
                .padding(.leading, 50)
                .padding(.trailing, 60)
                .padding(.vertical, LumaTheme.spacingLG)
            }
            .scrollClipDisabled()
        }
    }

    // MARK: - Live TV Rows

    @ViewBuilder
    private func homeLiveTVRow(title: String, channels: [LiveChannel]) -> some View {
        VStack(alignment: .leading, spacing: LumaTheme.spacingSM) {
            Text(title)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(LumaTheme.textPrimary)
                .padding(.leading, 50)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 25) {
                    ForEach(channels) { channel in
                        LiveChannelCard(channel: channel, viewModel: liveTVViewModel)
                    }
                }
                .padding(.leading, 50)
                .padding(.trailing, 60)
                .padding(.vertical, LumaTheme.spacingLG)
            }
            .scrollClipDisabled()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: LumaTheme.spacingXL) {
            Spacer()
            Image(systemName: "film.stack")
                .font(.system(size: 80, weight: .thin))
                .foregroundColor(LumaTheme.textTertiary)
            VStack(spacing: LumaTheme.spacingMD) {
                Text("Your library is empty")
                    .font(.system(size: LumaTheme.titleSize, weight: .bold))
                    .foregroundColor(LumaTheme.textPrimary)
                Text("Add movies and shows to your Jellyfin server to see them here.")
                    .font(.system(size: LumaTheme.bodySize, weight: .regular))
                    .foregroundColor(LumaTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 600)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Loading State

    private var loadingState: some View {
        ScrollView(.vertical, showsIndicators: false) {
            SkeletonHomeView()
        }
        .ignoresSafeArea(edges: [.horizontal, .top])
    }

    // MARK: - Helpers

    private var isLibraryEmpty: Bool {
        !viewModel.isLoading
            && viewModel.heroItems.isEmpty
            && viewModel.continueWatching.isEmpty
            && viewModel.nextUp.isEmpty
            && viewModel.recentlyAdded.isEmpty
            && libraryItems.values.allSatisfy { $0.isEmpty }
    }

    private func loadLibraryItems() async {
        let api = JellyfinAPI.shared
        for library in viewModel.libraries {
            guard let collectionType = library.collectionType,
                  collectionType == "movies" || collectionType == "tvshows" else { continue }
            do {
                let items = try await api.getLatestItems(parentId: library.id, limit: 20)
                libraryItems[library.id] = items
            } catch {
                // Non-critical; skip this library
            }
        }
    }
}

private enum HomeRowStyle {
    case poster
    case thumbnail
}
