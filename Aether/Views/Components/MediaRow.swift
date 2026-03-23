import SwiftUI

/// A horizontal scrolling row with a bold section title and media cards.
/// Supports both poster (2:3) and thumbnail (16:9) card styles.
struct MediaRow: View {
    let title: String
    let items: [BaseItemDto]
    let style: CardStyle
    var onItemSelected: ((BaseItemDto) -> Void)? = nil

    enum CardStyle {
        case poster
        case thumbnail
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AetherTheme.spacingMD) {
            // Section title
            Text(title)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(AetherTheme.textPrimary)
                .padding(.leading, 80)

            // Horizontal scroll of cards
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: style == .poster ? 12 : 20) {
                    ForEach(items) { item in
                        Button {
                            onItemSelected?(item)
                        } label: {
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
                .padding(.leading, 90)
                .padding(.trailing, 60)
                .padding(.vertical, AetherTheme.spacingLG)
            }
            .scrollClipDisabled()
        }
    }
}
