import SwiftUI
import NukeUI

struct MovieDetailView: View {
    let item: BaseItemDto
    @Bindable var viewModel: MediaDetailViewModel

    @State private var showFullOverview = false
    @State private var playbackItem: BaseItemDto?

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(alignment: .leading, spacing: 0) {
                // Full-bleed backdrop header (65% of screen)
                headerSection

                // Content below the hero
                VStack(alignment: .leading, spacing: AetherTheme.spacingXL) {
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

                    // Cast & Crew
                    if let people = item.people, !people.isEmpty {
                        castSection(people: people)
                    }

                    // More Like This
                    if !viewModel.similarItems.isEmpty {
                        moreLikeThisSection
                    }
                }
                .padding(.top, AetherTheme.spacingLG)
                .padding(.bottom, AetherTheme.spacingHuge)
            }
        }
        .background(AetherTheme.deepBlack)
        .navigationDestination(for: String.self) { itemId in
            DetailView(itemId: itemId)
        }
        .fullScreenCover(item: $playbackItem) { movie in
            PlayerView(item: movie)
        }
    }

    // MARK: - Header (Full-Bleed Backdrop)

    private var headerSection: some View {
        ZStack(alignment: .bottomLeading) {
            // Backdrop filling top 65% of screen
            LazyImage(url: ImageURLBuilder.backdropURL(itemId: item.id, maxWidth: 1920)) { state in
                if let image = state.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(AetherTheme.deepBlack)
                }
            }
            .frame(height: 700)
            .clipped()

            // Heavy gradient overlay: transparent at top -> black at bottom
            VStack(spacing: 0) {
                // Top vignette (subtle)
                LinearGradient(
                    stops: [
                        .init(color: AetherTheme.deepBlack.opacity(0.3), location: 0),
                        .init(color: .clear, location: 0.3)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 200)

                Spacer()

                // Bottom gradient — heavy
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: AetherTheme.deepBlack.opacity(0.6), location: 0.3),
                        .init(color: AetherTheme.deepBlack, location: 0.85)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 400)
            }

            // Left gradient for text legibility
            LinearGradient(
                stops: [
                    .init(color: AetherTheme.deepBlack.opacity(0.6), location: 0),
                    .init(color: .clear, location: 0.4)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )

            // Content overlay: logo/title + metadata
            VStack(alignment: .leading, spacing: 14) {
                // Logo or large bold title
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

                // Metadata row: year, runtime, rating badge, community rating
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
            if let year = item.productionYear {
                Text(String(year))
                    .font(.system(size: AetherTheme.captionSize, weight: .medium))
                    .foregroundStyle(AetherTheme.textSecondary)
            }

            if let rating = item.officialRating {
                Text(rating)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AetherTheme.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
            }

            if let ticks = item.runTimeTicks {
                Text(ticks.asDuration)
                    .font(.system(size: AetherTheme.captionSize))
                    .foregroundStyle(AetherTheme.textSecondary)
            }

            if let rating = item.communityRating {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.yellow)
                    Text(String(format: "%.1f", rating))
                        .font(.system(size: AetherTheme.captionSize, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: AetherTheme.spacingLG) {
            // Play button — white filled, play triangle icon
            AccentButton(title: playButtonTitle, icon: "play.fill", style: .primary) {
                playbackItem = item
            }

            // Add to List / Favorite
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
                    .foregroundStyle(item.userData?.played == true ? AetherTheme.accent : AetherTheme.textTertiary)
                    .frame(width: 60, height: 60)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 80)
    }

    private var playButtonTitle: String {
        if let progress = item.userData?.progressPercent, progress > 0, progress < 1 {
            return "Resume"
        }
        return "Play"
    }

    // MARK: - Synopsis with "more" expansion

    private func synopsisSection(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: AetherTheme.spacingSM) {
            Text(text)
                .font(.system(size: 26))
                .foregroundStyle(AetherTheme.textSecondary)
                .lineLimit(showFullOverview ? nil : 3)
                .frame(maxWidth: 900, alignment: .leading)

            if text.count > 200 {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showFullOverview.toggle()
                    }
                } label: {
                    Text(showFullOverview ? "Show less" : "More")
                        .font(.system(size: AetherTheme.captionSize, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
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
                        .foregroundStyle(AetherTheme.textSecondary)
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

    // MARK: - Cast (Circular Headshots)

    private func castSection(people: [PersonInfo]) -> some View {
        VStack(alignment: .leading, spacing: AetherTheme.spacingMD) {
            Text("Cast & Crew")
                .font(.system(size: 31, weight: .semibold))
                .foregroundStyle(AetherTheme.textPrimary)
                .padding(.leading, 80)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 28) {
                    ForEach(people.prefix(20)) { person in
                        CastCard(person: person)
                    }
                }
                .padding(.horizontal, 80)
                .padding(.vertical, AetherTheme.spacingSM)
            }
        }
    }

    // MARK: - More Like This

    private var moreLikeThisSection: some View {
        VStack(alignment: .leading, spacing: AetherTheme.spacingMD) {
            Text("More Like This")
                .font(.system(size: 31, weight: .semibold))
                .foregroundStyle(AetherTheme.textPrimary)
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
                .padding(.vertical, AetherTheme.spacingXL)
            }
            .scrollClipDisabled()
        }
    }
}
