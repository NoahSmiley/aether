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
            .background(AetherTheme.deepBlack.ignoresSafeArea())
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
                        .frame(width: 60, height: 60)
                        .opacity(0.85)
                    Spacer()
                }
                .padding(.bottom, AetherTheme.spacingMD)

                // Continue Watching
                if !viewModel.continueWatching.isEmpty {
                    homeMediaRow(
                        title: "Continue Watching",
                        items: viewModel.continueWatching,
                        style: .thumbnail
                    )
                    .padding(.bottom, AetherTheme.spacingXXL)
                }

                // Next Up
                if !viewModel.nextUp.isEmpty {
                    homeMediaRow(
                        title: "Next Up",
                        items: viewModel.nextUp,
                        style: .thumbnail
                    )
                    .padding(.bottom, AetherTheme.spacingXXL)
                }

                // Live Sports
                if !liveTVViewModel.sportsPrograms.isEmpty {
                    homeLiveTVRow(title: "Live Sports & NFL", items: liveTVViewModel.sportsPrograms)
                        .padding(.bottom, AetherTheme.spacingXXL)
                }

                // Live Now
                if !liveTVViewModel.nowAiring.isEmpty {
                    homeLiveTVRow(title: "Live Now", items: liveTVViewModel.nowAiring)
                        .padding(.bottom, AetherTheme.spacingXXL)
                }

                // Recently Added
                if !viewModel.recentlyAdded.isEmpty {
                    homeMediaRow(
                        title: "Recently Added",
                        items: viewModel.recentlyAdded,
                        style: .poster
                    )
                    .padding(.bottom, AetherTheme.spacingXXL)
                }

                // Library rows
                ForEach(viewModel.libraries, id: \.id) { library in
                    if let items = libraryItems[library.id], !items.isEmpty {
                        homeMediaRow(
                            title: library.name ?? "Library",
                            items: items,
                            style: .poster
                        )
                        .padding(.bottom, AetherTheme.spacingXXL)
                    }
                }

                Spacer()
                    .frame(height: AetherTheme.spacingHuge)
            }
        }
        .ignoresSafeArea(edges: [.horizontal, .top])
    }

    // MARK: - Media Rows

    @ViewBuilder
    private func homeMediaRow(title: String, items: [BaseItemDto], style: HomeRowStyle) -> some View {
        VStack(alignment: .leading, spacing: AetherTheme.spacingSM) {
            Text(title)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(AetherTheme.textPrimary)
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
                .padding(.vertical, AetherTheme.spacingLG)
            }
            .scrollClipDisabled()
        }
    }

    // MARK: - Live TV Rows

    @ViewBuilder
    private func homeLiveTVRow(title: String, items: [MockProgram]) -> some View {
        VStack(alignment: .leading, spacing: AetherTheme.spacingSM) {
            Text(title)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(AetherTheme.textPrimary)
                .padding(.leading, 50)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 25) {
                    ForEach(items) { program in
                        ProgramCard(program: program)
                    }
                }
                .padding(.leading, 50)
                .padding(.trailing, 60)
                .padding(.vertical, AetherTheme.spacingLG)
            }
            .scrollClipDisabled()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AetherTheme.spacingXL) {
            Spacer()
            Image(systemName: "film.stack")
                .font(.system(size: 80, weight: .thin))
                .foregroundColor(AetherTheme.textTertiary)
            VStack(spacing: AetherTheme.spacingMD) {
                Text("Your library is empty")
                    .font(.system(size: AetherTheme.titleSize, weight: .bold))
                    .foregroundColor(AetherTheme.textPrimary)
                Text("Add movies and shows to your Jellyfin server to see them here.")
                    .font(.system(size: AetherTheme.bodySize, weight: .regular))
                    .foregroundColor(AetherTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 600)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
                .tint(AetherTheme.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
