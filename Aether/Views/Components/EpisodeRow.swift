import SwiftUI
import NukeUI

/// A Netflix/HBO-style episode list row.
/// Thumbnail on left with play icon overlay on focus, episode badge, title, duration,
/// synopsis preview, and watched indicator.
struct EpisodeRow: View {
    let item: BaseItemDto
    var onSelect: (() -> Void)? = nil

    private let thumbWidth: CGFloat = 300
    private let thumbHeight: CGFloat = 169 // 16:9

    @FocusState private var buttonFocused: Bool

    var body: some View {
        Button {
            onSelect?()
        } label: {
            HStack(alignment: .top, spacing: LumaTheme.spacingLG) {
                // Thumbnail with play overlay
                ZStack {
                    LazyImage(url: thumbnailURL) { state in
                        if let image = state.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            thumbnailPlaceholder
                        }
                    }
                    .frame(width: thumbWidth, height: thumbHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    // Play icon overlay on focus
                    if buttonFocused {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.4))
                            .frame(width: thumbWidth, height: thumbHeight)

                        Image(systemName: "play.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.5), radius: 4)
                    }

                    // Progress bar at bottom
                    if let progress = item.userData?.progressPercent, progress > 0, progress < 1 {
                        VStack {
                            Spacer()
                            ProgressBar(progress: progress, accentColor: .red)
                                .padding(.horizontal, 6)
                                .padding(.bottom, 6)
                        }
                        .frame(width: thumbWidth, height: thumbHeight)
                    }
                }

                // Episode info
                VStack(alignment: .leading, spacing: 8) {
                    // Episode badge + title + duration row
                    HStack(spacing: 12) {
                        // Episode number badge
                        if let num = item.indexNumber {
                            Text("E\(num)")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.9))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }

                        // Title
                        Text(item.name ?? "Unknown Episode")
                            .font(.system(size: 27, weight: .semibold))
                            .foregroundColor(buttonFocused ? .white : LumaTheme.textPrimary)
                            .lineLimit(1)

                        Spacer()

                        // Duration
                        if let ticks = item.runTimeTicks {
                            Text(ticks.asDuration)
                                .font(.system(size: LumaTheme.captionSize))
                                .foregroundColor(LumaTheme.textTertiary)
                        }
                    }

                    // Synopsis preview
                    if let overview = item.overview, !overview.isEmpty {
                        Text(overview)
                            .font(.system(size: LumaTheme.captionSize))
                            .foregroundColor(LumaTheme.textSecondary)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Spacer(minLength: 0)

                    // Watched indicator
                    if item.userData?.played == true {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(LumaTheme.accent)
                            Text("Watched")
                                .font(.system(size: 20))
                                .foregroundColor(LumaTheme.textTertiary)
                        }
                    } else if let progress = item.userData?.progressPercent, progress > 0 {
                        ProgressBar(progress: progress, height: 3, accentColor: LumaTheme.accent)
                            .frame(maxWidth: 200)
                    }
                }
                .padding(.vertical, 6)
            }
            .padding(.horizontal, LumaTheme.spacingLG)
            .padding(.vertical, LumaTheme.spacingMD)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(buttonFocused ? Color.white.opacity(0.12) : Color.white.opacity(0.03))
            )
            .scaleEffect(buttonFocused ? 1.02 : 1.0)
            .animation(.easeOut(duration: 0.15), value: buttonFocused)
        }
        .buttonStyle(NoChromeFocusStyle())
        .focused($buttonFocused)
    }

    // MARK: - Private

    private var thumbnailPlaceholder: some View {
        Rectangle()
            .fill(LumaTheme.cardSurface)
            .overlay {
                Image(systemName: "play.rectangle")
                    .font(.system(size: 30))
                    .foregroundColor(LumaTheme.textTertiary)
            }
    }

    private var thumbnailURL: URL? {
        if let tag = item.imageTags?["Primary"] {
            return ImageURLBuilder.posterURL(
                itemId: item.id,
                maxWidth: Int(thumbWidth * 2),
                tag: tag
            )
        }
        if let tags = item.backdropImageTags, let tag = tags.first {
            return ImageURLBuilder.backdropURL(
                itemId: item.id,
                maxWidth: Int(thumbWidth * 2),
                tag: tag
            )
        }
        if let seriesId = item.seriesId,
           let tags = item.parentBackdropImageTags, let tag = tags.first {
            return ImageURLBuilder.backdropURL(
                itemId: seriesId,
                maxWidth: Int(thumbWidth * 2),
                tag: tag
            )
        }
        return nil
    }
}

