import SwiftUI
import NukeUI

struct HeroBanner: View {
    let items: [BaseItemDto]
    @Binding var currentIndex: Int
    let onPlay: (BaseItemDto) -> Void
    let onMoreInfo: (BaseItemDto) -> Void

    @Environment(\.isFocused) private var isFocused

    private var currentItem: BaseItemDto? {
        guard !items.isEmpty else { return nil }
        let index = min(currentIndex, items.count - 1)
        return items[index]
    }

    var body: some View {
        if let item = currentItem {
            NavigationLink(value: item.id) {
                heroContent(for: item)
            }
            .buttonStyle(HeroBannerButtonStyle())
            .animation(.easeInOut(duration: 0.8), value: currentIndex)
        }
    }

    // MARK: - Hero Content

    @ViewBuilder
    private func heroContent(for item: BaseItemDto) -> some View {
        ZStack(alignment: .bottomLeading) {
            // Full-bleed backdrop
            backdropImage(for: item)
                .id(item.id)
                .transition(.opacity)

            // Single bottom gradient — fades image to background
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: .clear, location: 0.6),
                    .init(color: AetherTheme.deepBlack.opacity(0.5), location: 0.78),
                    .init(color: AetherTheme.deepBlack, location: 0.95)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Content overlay
            VStack(alignment: .leading, spacing: 12) {
                Spacer()

                // Content logo or title
                if let logoURL = ImageURLBuilder.logoURL(itemId: item.id, maxWidth: 1000) {
                    LazyImage(url: logoURL) { state in
                        if let image = state.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } else {
                            heroTitle(for: item)
                        }
                    }
                    .frame(
                        maxWidth: AetherTheme.heroLogoMaxWidth,
                        maxHeight: AetherTheme.heroLogoMaxHeight
                    )
                } else {
                    heroTitle(for: item)
                }

                // Inline metadata
                metadataLine(for: item)

                // Description
                if let overview = item.overview, !overview.isEmpty {
                    Text(overview)
                        .font(.system(size: 22, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(3)
                        .frame(maxWidth: 650, alignment: .leading)
                }
            }
            .padding(.leading, 80)
            .padding(.bottom, 100)
            .padding(.trailing, 200)
            .id(item.id)
            .transition(.opacity)

            // Page indicator dots
            if items.count > 1 {
                VStack {
                    Spacer()
                    HStack(spacing: 10) {
                        ForEach(0..<items.count, id: \.self) { index in
                            Capsule()
                                .fill(index == currentIndex ? Color.white : Color.white.opacity(0.35))
                                .frame(
                                    width: index == currentIndex ? 28 : 10,
                                    height: 4
                                )
                                .animation(.easeInOut(duration: 0.3), value: currentIndex)
                        }
                    }
                    .padding(.bottom, 30)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 80)
            }
        }
        .frame(height: AetherTheme.heroBannerHeight)
    }

    // MARK: - Subviews

    @ViewBuilder
    private func backdropImage(for item: BaseItemDto) -> some View {
        let backdropURL = ImageURLBuilder.backdropURL(itemId: item.id, maxWidth: 1920)
        LazyImage(url: backdropURL) { state in
            if let image = state.image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(AetherTheme.deepBlack)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func heroTitle(for item: BaseItemDto) -> some View {
        Text(item.name ?? "Untitled")
            .font(.system(size: AetherTheme.heroTitleSize, weight: .bold))
            .foregroundColor(.white)
            .shadow(color: .black.opacity(0.7), radius: 8, y: 4)
    }

    @ViewBuilder
    private func metadataLine(for item: BaseItemDto) -> some View {
        let parts = buildMetadataParts(for: item)
        if !parts.isEmpty {
            Text(parts.joined(separator: "  \u{2022}  "))
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(.white.opacity(0.55))
        }
    }

    private func buildMetadataParts(for item: BaseItemDto) -> [String] {
        var parts: [String] = []
        if let rating = item.officialRating, !rating.isEmpty {
            parts.append(rating)
        }
        if let year = item.productionYear {
            parts.append(String(year))
        }
        if let ticks = item.runTimeTicks {
            parts.append(ticks.asDuration)
        }
        if let genres = item.genres, !genres.isEmpty {
            parts.append(contentsOf: genres.prefix(2))
        }
        return parts
    }
}

// MARK: - Hero Button Style

/// Custom button style that keeps the hero looking clean on focus —
/// no default tvOS chrome, just a subtle scale + brightness shift.
private struct HeroBannerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}
