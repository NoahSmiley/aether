import SwiftUI
import NukeUI

struct ShowDetailView: View {
    let item: BaseItemDto
    @Bindable var viewModel: MediaDetailViewModel

    @State private var playbackItem: BaseItemDto?
    @State private var showFullOverview = false

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(alignment: .leading, spacing: 0) {
                // Full-bleed backdrop header (same as movie)
                headerSection
                    .focusable()

                // Content below the hero
                VStack(alignment: .leading, spacing: LumaTheme.spacingXL) {
                    // Action buttons
                    actionButtons

                    // Synopsis
                    if let overview = item.overview, !overview.isEmpty {
                        synopsisSection(overview)
                    }

                    // Genre pills
                    if let genres = item.genres, !genres.isEmpty {
                        genrePills(genres)
                    }

                    // Season selector (horizontal scrollable pills)
                    if !viewModel.seasons.isEmpty {
                        seasonPicker
                    }

                    // Episode list
                    if !viewModel.episodes.isEmpty {
                        episodeList
                    }

                    // More Like This
                    if !viewModel.similarItems.isEmpty {
                        moreLikeThisSection
                    }
                }
                .padding(.top, LumaTheme.spacingLG)
                .padding(.bottom, 200)
            }
        }
        .background(LumaTheme.deepBlack)
        .navigationDestination(for: String.self) { itemId in
            DetailView(itemId: itemId)
        }
        .fullScreenCover(item: $playbackItem) { episode in
            PlayerView(item: episode)
        }
    }

    // MARK: - Header (Full-Bleed Backdrop)

    private var headerSection: some View {
        ZStack(alignment: .bottomLeading) {
            // Backdrop
            LazyImage(url: ImageURLBuilder.backdropURL(itemId: item.id, maxWidth: 1920)) { state in
                if let image = state.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(LumaTheme.deepBlack)
                }
            }
            .frame(height: 700)
            .clipped()

            // Heavy gradient overlays
            VStack(spacing: 0) {
                LinearGradient(
                    stops: [
                        .init(color: LumaTheme.deepBlack.opacity(0.3), location: 0),
                        .init(color: .clear, location: 0.3)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 200)

                Spacer()

                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: LumaTheme.deepBlack.opacity(0.6), location: 0.3),
                        .init(color: LumaTheme.deepBlack, location: 0.85)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 400)
            }

            // Left gradient for text legibility
            LinearGradient(
                stops: [
                    .init(color: LumaTheme.deepBlack.opacity(0.6), location: 0),
                    .init(color: .clear, location: 0.4)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )

            // Content overlay
            VStack(alignment: .leading, spacing: 14) {
                // Logo or title
                if let logoURL = ImageURLBuilder.logoURL(itemId: item.id, maxWidth: 900) {
                    LazyImage(url: logoURL) { state in
                        if let image = state.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } else {
                            titleText
                        }
                    }
                    .frame(maxWidth: 500, maxHeight: 140)
                } else {
                    titleText
                }

                // Metadata row
                metadataRow
            }
            .padding(.leading, 80)
            .padding(.bottom, 50)
        }
    }

    private var titleText: some View {
        Text(item.name ?? "Untitled")
            .font(.system(size: 56, weight: .bold))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.7), radius: 4)
    }

    // MARK: - Metadata Row

    private var metadataRow: some View {
        HStack(spacing: 14) {
            // Year range
            if let year = item.productionYear {
                if let endDate = item.endDate, item.status == "Ended" {
                    let endYear = String(endDate.prefix(4))
                    Text("\(year)-\(endYear)")
                } else {
                    Text("\(year)-")
                }
            }

            if let rating = item.officialRating {
                Text(rating)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(LumaTheme.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
            }

            if let seasonCount = item.childCount, seasonCount > 0 {
                Text("\(seasonCount) Season\(seasonCount == 1 ? "" : "s")")
            }

            if let rating = item.communityRating {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.yellow)
                    Text(String(format: "%.1f", rating))
                        .font(.system(size: LumaTheme.captionSize, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .font(.system(size: LumaTheme.captionSize, weight: .medium))
        .foregroundStyle(LumaTheme.textSecondary)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: LumaTheme.spacingLG) {
            // Play button
            AccentButton(title: playButtonLabel, icon: "play.fill", style: .primary) {
                if let nextEp = viewModel.episodes.first(where: { $0.userData?.played != true }) {
                    playbackItem = nextEp
                } else if let firstEp = viewModel.episodes.first {
                    playbackItem = firstEp
                }
            }

            // Favorite / My List
            AccentButton(
                title: item.userData?.isFavorite == true ? "Favorited" : "My List",
                icon: item.userData?.isFavorite == true ? "heart.fill" : "plus",
                style: .secondary
            ) {
                Task { await viewModel.toggleFavorite() }
            }

            // Watched toggle
            Button {
                Task { await viewModel.toggleWatched() }
            } label: {
                Image(systemName: item.userData?.played == true ? "checkmark.circle.fill" : "checkmark.circle")
                    .font(.system(size: 30))
                    .foregroundStyle(item.userData?.played == true ? LumaTheme.accent : LumaTheme.textTertiary)
                    .frame(width: 60, height: 60)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            }
            .buttonStyle(NoChromeFocusStyle())
        }
        .padding(.horizontal, 80)
    }

    private var playButtonLabel: String {
        if let nextEp = viewModel.episodes.first(where: { $0.userData?.played != true }) {
            let s = nextEp.parentIndexNumber ?? 1
            let e = nextEp.indexNumber ?? 1
            return "Play S\(s):E\(e)"
        }
        return "Play S1:E1"
    }

    // MARK: - Synopsis with "more" expansion

    private func synopsisSection(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: LumaTheme.spacingSM) {
            Text(text)
                .font(.system(size: 26))
                .foregroundStyle(LumaTheme.textSecondary)
                .lineLimit(showFullOverview ? nil : 3)
                .frame(maxWidth: 900, alignment: .leading)

            if text.count > 200 {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showFullOverview.toggle()
                    }
                } label: {
                    Text(showFullOverview ? "Show less" : "More")
                        .font(.system(size: LumaTheme.captionSize, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .buttonStyle(NoChromeFocusStyle())
            }
        }
        .padding(.horizontal, 80)
    }

    // MARK: - Genre Pills

    private func genrePills(_ genres: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(genres, id: \.self) { genre in
                    Text(genre)
                        .font(.system(size: 21, weight: .medium))
                        .foregroundStyle(LumaTheme.textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, 80)
        }
    }

    // MARK: - Season Picker (Horizontal Scrollable Pills)

    private var seasonPicker: some View {
        VStack(alignment: .leading, spacing: LumaTheme.spacingMD) {
            Text("Seasons")
                .font(.system(size: 31, weight: .semibold))
                .foregroundStyle(LumaTheme.textPrimary)
                .padding(.leading, 80)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.seasons) { season in
                        Button {
                            Task { await viewModel.selectSeason(season.id) }
                        } label: {
                            Text(season.name ?? "Season")
                                .font(.system(size: LumaTheme.captionSize, weight: viewModel.selectedSeasonId == season.id ? .bold : .medium))
                                .foregroundStyle(viewModel.selectedSeasonId == season.id ? .black : LumaTheme.textSecondary)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(
                                    viewModel.selectedSeasonId == season.id
                                        ? Color.white
                                        : Color.white.opacity(0.08)
                                )
                                .clipShape(Capsule())
                                .overlay(
                                    viewModel.selectedSeasonId != season.id
                                        ? Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1)
                                        : nil
                                )
                        }
                        .buttonStyle(NoChromeFocusStyle())
                    }
                }
                .padding(.horizontal, 80)
            }
        }
    }

    // MARK: - Episode List

    private var episodeList: some View {
        VStack(alignment: .leading, spacing: LumaTheme.spacingMD) {
            Text("Episodes")
                .font(.system(size: 31, weight: .semibold))
                .foregroundStyle(LumaTheme.textPrimary)
                .padding(.leading, 80)

            VStack(spacing: 2) {
                ForEach(viewModel.episodes) { episode in
                    EpisodeRow(item: episode) {
                        playbackItem = episode
                    }
                    .padding(.horizontal, 80)

                    if episode.id != viewModel.episodes.last?.id {
                        Rectangle()
                            .fill(LumaTheme.divider)
                            .frame(height: 1)
                            .padding(.horizontal, 80)
                    }
                }
            }
        }
    }

    // MARK: - Cast

    private func castSection(people: [PersonInfo]) -> some View {
        VStack(alignment: .leading, spacing: LumaTheme.spacingMD) {
            Text("Cast & Crew")
                .font(.system(size: 31, weight: .semibold))
                .foregroundStyle(LumaTheme.textPrimary)
                .padding(.leading, 80)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 28) {
                    ForEach(people.prefix(20)) { person in
                        CastCard(person: person)
                    }
                }
                .padding(.horizontal, 80)
                .padding(.vertical, LumaTheme.spacingSM)
            }
        }
    }

    // MARK: - More Like This

    private var moreLikeThisSection: some View {
        VStack(alignment: .leading, spacing: LumaTheme.spacingMD) {
            Text("More Like This")
                .font(.system(size: 31, weight: .semibold))
                .foregroundStyle(LumaTheme.textPrimary)
                .padding(.leading, 80)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 40) {
                    ForEach(viewModel.similarItems) { similarItem in
                        NavigationLink(value: similarItem.id) {
                            PosterCard(item: similarItem)
                        }
                        .buttonStyle(.card)
                    }
                }
                .padding(.leading, 80)
                .padding(.trailing, 40)
                .padding(.vertical, LumaTheme.spacingXL)
            }
            .scrollClipDisabled()
        }
    }
}
