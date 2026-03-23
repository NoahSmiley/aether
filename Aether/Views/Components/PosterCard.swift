import SwiftUI
import NukeUI

/// HBO Max-style poster card. Clean poster art, no text overlay.
/// On focus: subtle scale up with white border highlight.
struct PosterCard: View {
    let item: BaseItemDto

    @Environment(\.isFocused) private var isFocused

    var body: some View {
        LazyImage(url: posterURL) { state in
            if let image = state.image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholder
            }
        }
        .frame(width: LumaTheme.posterWidth, height: LumaTheme.posterHeight)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(isFocused ? 0.4 : 0), lineWidth: 3)
        )
        // Unwatched badge
        .overlay(alignment: .topTrailing) {
            if let count = item.userData?.unplayedItemCount, count > 0 {
                Text("\(count)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(LumaTheme.accent)
                    .clipShape(Capsule())
                    .padding(6)
            }
        }
        // Progress bar
        .overlay(alignment: .bottom) {
            if let progress = item.userData?.progressPercent, progress > 0, progress < 1 {
                GeometryReader { geo in
                    VStack {
                        Spacer()
                        ZStack(alignment: .leading) {
                            Rectangle().fill(Color.white.opacity(0.2))
                            Rectangle().fill(Color.red).frame(width: geo.size.width * progress)
                        }
                        .frame(height: 3)
                    }
                }
            }
        }
        .scaleEffect(isFocused ? 1.05 : 1.0)
        .shadow(
            color: .black.opacity(isFocused ? 0.5 : 0),
            radius: isFocused ? 15 : 0,
            y: isFocused ? 8 : 0
        )
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }

    private var placeholder: some View {
        Rectangle()
            .fill(Color(white: 0.12))
            .overlay {
                Image(systemName: "film")
                    .font(.system(size: 32))
                    .foregroundColor(Color(white: 0.25))
            }
    }

    private var posterURL: URL? {
        ImageURLBuilder.posterURL(
            itemId: item.id,
            maxWidth: Int(LumaTheme.posterWidth * 2),
            tag: item.imageTags?["Primary"]
        )
    }
}
