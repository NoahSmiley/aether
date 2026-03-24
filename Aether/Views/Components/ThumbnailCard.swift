import SwiftUI
import NukeUI

/// A 16:9 thumbnail card for Continue Watching / Next Up rows.
/// Episode info overlaid at bottom with gradient. Thin accent-colored progress bar.
struct ThumbnailCard: View {
    let item: BaseItemDto

    @Environment(\.isFocused) private var isFocused

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thumbnail with overlays
            ZStack(alignment: .bottom) {
                LazyImage(url: thumbnailURL) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else if state.error != nil {
                        placeholder
                    } else {
                        placeholder
                    }
                }
                .frame(width: LumaTheme.thumbnailWidth, height: LumaTheme.thumbnailHeight)
                .clipShape(RoundedRectangle(cornerRadius: LumaTheme.cardCornerRadius))

                // Bottom gradient overlay (visual only, no text)
                VStack(spacing: 0) {
                    Spacer()
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .black.opacity(0.7), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 60)
                }
                .clipShape(RoundedRectangle(cornerRadius: LumaTheme.cardCornerRadius))

                // Thin accent-colored progress bar at the very bottom
                if let progress = item.userData?.progressPercent, progress > 0, progress < 1 {
                    VStack {
                        Spacer()
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.white.opacity(0.15))
                                Rectangle()
                                    .fill(LumaTheme.accent)
                                    .frame(width: geo.size.width * min(max(progress, 0), 1))
                            }
                        }
                        .frame(height: 3)
                    }
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 0,
                            bottomLeadingRadius: LumaTheme.cardCornerRadius,
                            bottomTrailingRadius: LumaTheme.cardCornerRadius,
                            topTrailingRadius: 0
                        )
                    )
                }
            }
            .frame(width: LumaTheme.thumbnailWidth, height: LumaTheme.thumbnailHeight)

            // Title and episode info below the card
            VStack(alignment: .leading, spacing: 3) {
                if item.type == .episode, let seriesName = item.seriesName {
                    Text(seriesName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(LumaTheme.textPrimary)
                        .lineLimit(1)
                    Text(titleText)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(LumaTheme.textSecondary)
                        .lineLimit(1)
                } else {
                    Text(item.name ?? "Unknown")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(LumaTheme.textPrimary)
                        .lineLimit(1)
                }
            }
            .padding(.top, 8)
            .frame(width: LumaTheme.thumbnailWidth, alignment: .leading)
        }
        .frame(width: LumaTheme.thumbnailWidth)
        .lumaFocusStyle(isFocused: isFocused)
    }

    // MARK: - Private

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: LumaTheme.cardCornerRadius)
            .fill(LumaTheme.cardSurface)
            .overlay {
                Image(systemName: "play.rectangle")
                    .font(.system(size: 36))
                    .foregroundColor(LumaTheme.textTertiary)
            }
    }

    /// For episodes: "S2:E5 Episode Title". For movies: the movie title.
    private var titleText: String {
        if item.type == .episode,
           let season = item.parentIndexNumber,
           let episode = item.indexNumber {
            let episodeTitle = item.name ?? ""
            return "S\(season):E\(episode) \(episodeTitle)"
        }
        return item.name ?? "Unknown"
    }

    /// Prefer Thumb image, fall back to Backdrop, then Primary.
    private var thumbnailURL: URL? {
        if let tag = item.imageTags?["Thumb"] {
            return ImageURLBuilder.thumbURL(
                itemId: item.id,
                maxWidth: Int(LumaTheme.thumbnailWidth * 2),
                tag: tag
            )
        }
        if let tags = item.backdropImageTags, let tag = tags.first {
            return ImageURLBuilder.backdropURL(
                itemId: item.id,
                maxWidth: Int(LumaTheme.thumbnailWidth * 2),
                tag: tag
            )
        }
        if let tag = item.imageTags?["Primary"] {
            return ImageURLBuilder.posterURL(
                itemId: item.id,
                maxWidth: Int(LumaTheme.thumbnailWidth * 2),
                tag: tag
            )
        }
        // Fallback: try parent backdrop for episodes
        if item.type == .episode, let seriesId = item.seriesId,
           let tags = item.parentBackdropImageTags, let tag = tags.first {
            return ImageURLBuilder.backdropURL(
                itemId: seriesId,
                maxWidth: Int(LumaTheme.thumbnailWidth * 2),
                tag: tag
            )
        }
        return nil
    }
}
