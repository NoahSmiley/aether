import SwiftUI
import NukeUI

struct SearchView: View {
    @State private var viewModel = SearchViewModel()

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AetherTheme.spacingXL) {
                if viewModel.query.isEmpty {
                    emptyState
                } else if viewModel.isSearching && viewModel.movies.isEmpty && viewModel.shows.isEmpty && viewModel.episodes.isEmpty {
                    loadingState
                } else if !viewModel.movies.isEmpty || !viewModel.shows.isEmpty || !viewModel.episodes.isEmpty {
                    searchResults
                } else if !viewModel.isSearching {
                    noResults
                }
            }
        }
        .background(AetherTheme.deepBlack)
        .searchable(text: $viewModel.query, prompt: "Search movies, shows, episodes...")
        .navigationTitle("Search")
        .navigationDestination(for: String.self) { itemId in
            DetailView(itemId: itemId)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AetherTheme.spacingLG) {
            // Large magnifying glass icon
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 140, height: 140)

                Image(systemName: "magnifyingglass")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(AetherTheme.textTertiary)
            }

            Text("Search your library")
                .font(.system(size: AetherTheme.headlineSize, weight: .semibold))
                .foregroundStyle(AetherTheme.textPrimary)

            Text("Find movies, TV shows, and episodes")
                .font(.system(size: AetherTheme.captionSize))
                .foregroundStyle(AetherTheme.textTertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 500)
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: AetherTheme.spacingMD) {
            ProgressView()
                .tint(.white)
                .scaleEffect(1.3)
            Text("Searching...")
                .font(.system(size: AetherTheme.captionSize))
                .foregroundStyle(AetherTheme.textTertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 400)
    }

    // MARK: - No Results

    private var noResults: some View {
        VStack(spacing: AetherTheme.spacingMD) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(AetherTheme.textTertiary)
            Text("No results for \"\(viewModel.query)\"")
                .font(.system(size: AetherTheme.bodySize))
                .foregroundStyle(AetherTheme.textSecondary)
            Text("Try a different search term")
                .font(.system(size: AetherTheme.captionSize))
                .foregroundStyle(AetherTheme.textTertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 400)
    }

    // MARK: - Search Results (Categorized Rows)

    private var searchResults: some View {
        Group {
            // Movies category
            if !viewModel.movies.isEmpty {
                resultRow(title: "Movies", items: viewModel.movies, style: .poster)
            }

            // TV Shows category
            if !viewModel.shows.isEmpty {
                resultRow(title: "TV Shows", items: viewModel.shows, style: .poster)
            }

            // Episodes category
            if !viewModel.episodes.isEmpty {
                resultRow(title: "Episodes", items: viewModel.episodes, style: .thumbnail)
            }
        }
    }

    @ViewBuilder
    private func resultRow(title: String, items: [BaseItemDto], style: SearchRowStyle) -> some View {
        VStack(alignment: .leading, spacing: AetherTheme.spacingMD) {
            // Section title with count
            HStack(spacing: AetherTheme.spacingSM) {
                Text(title)
                    .font(.system(size: 31, weight: .semibold))
                    .foregroundStyle(AetherTheme.textPrimary)

                Text("\(items.count)")
                    .font(.system(size: AetherTheme.captionSize, weight: .medium))
                    .foregroundStyle(AetherTheme.textTertiary)
            }
            .padding(.leading, 80)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 40) {
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
                .padding(.leading, 80)
                .padding(.trailing, 40)
                .padding(.vertical, AetherTheme.spacingXL)
            }
            .scrollClipDisabled()
        }
    }
}

private enum SearchRowStyle {
    case poster
    case thumbnail
}
