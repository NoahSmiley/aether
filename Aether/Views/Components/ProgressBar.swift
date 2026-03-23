import SwiftUI

/// A thin horizontal progress bar with a translucent track and bright fill.
/// Used for playback progress on thumbnail cards and episode rows.
struct ProgressBar: View {
    /// Progress value between 0.0 and 1.0.
    let progress: Double

    var height: CGFloat = 4
    var accentColor: Color = .red

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.white.opacity(0.2))

                // Fill
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(accentColor)
                    .frame(width: geometry.size.width * clampedProgress)
            }
        }
        .frame(height: height)
    }

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }
}
