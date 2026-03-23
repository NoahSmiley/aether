import SwiftUI

// MARK: - Shimmer Modifier

/// Adds an animated shimmer sweep (light band moving left to right) to any view.
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    let width = geo.size.width
                    LinearGradient(
                        colors: [
                            .clear,
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.08),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: width * 0.6)
                    .offset(x: width * phase)
                }
            )
            .clipped()
            .onAppear {
                withAnimation(
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 2
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Skeleton Card

/// Placeholder card matching `ThumbnailCard` dimensions with shimmer effect.
struct SkeletonCard: View {
    private let skeletonFill = Color.white.opacity(0.06)

    var body: some View {
        VStack(alignment: .leading, spacing: LumaTheme.spacingSM) {
            // Thumbnail placeholder
            RoundedRectangle(cornerRadius: LumaTheme.cardCornerRadius)
                .fill(skeletonFill)
                .frame(width: LumaTheme.thumbnailWidth, height: LumaTheme.thumbnailHeight)
                .shimmer()

            // Title placeholder
            RoundedRectangle(cornerRadius: 4)
                .fill(skeletonFill)
                .frame(width: LumaTheme.thumbnailWidth * 0.6, height: 20)
                .shimmer()

            // Subtitle placeholder
            RoundedRectangle(cornerRadius: 4)
                .fill(skeletonFill)
                .frame(width: LumaTheme.thumbnailWidth * 0.35, height: 16)
                .shimmer()
        }
    }
}

// MARK: - Skeleton Row

/// A horizontal scroll row with a title placeholder and five skeleton cards.
struct SkeletonRow: View {
    private let skeletonFill = Color.white.opacity(0.06)

    var body: some View {
        VStack(alignment: .leading, spacing: LumaTheme.spacingMD) {
            // Row title placeholder
            RoundedRectangle(cornerRadius: 4)
                .fill(skeletonFill)
                .frame(width: 200, height: 24)
                .shimmer()
                .padding(.leading, 50)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 25) {
                    ForEach(0..<5, id: \.self) { _ in
                        SkeletonCard()
                    }
                }
                .padding(.leading, 50)
                .padding(.trailing, 60)
            }
            .disabled(true)
        }
    }
}

// MARK: - Skeleton Home View

/// Full-screen skeleton simulating the home page while content loads.
struct SkeletonHomeView: View {
    private let skeletonFill = Color.white.opacity(0.06)

    var body: some View {
        VStack(spacing: LumaTheme.spacingXXL) {
            // Logo placeholder
            Circle()
                .fill(skeletonFill)
                .frame(width: 50, height: 50)
                .shimmer()
                .padding(.top, LumaTheme.spacingXL)

            ForEach(0..<3, id: \.self) { _ in
                SkeletonRow()
            }

            Spacer()
        }
    }
}

// MARK: - Previews

#Preview("Skeleton Home") {
    SkeletonHomeView()
        .background(LumaTheme.deepBlack)
}

#Preview("Skeleton Card") {
    SkeletonCard()
        .padding()
        .background(LumaTheme.deepBlack)
}
