import SwiftUI

enum AetherTheme {
    // Colors
    static let background = Color("Background", bundle: nil)
    static let surface = Color("Surface", bundle: nil)
    static let accent = Color.accentColor
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.7)
    static let textTertiary = Color.white.opacity(0.4)

    // Netflix/HBO cinematic dark tones
    static let deepBlack = Color(red: 0.04, green: 0.04, blue: 0.04)
    static let cardSurface = Color(white: 0.10)
    static let divider = Color.white.opacity(0.08)
    static let glowColor = Color.white.opacity(0.15)

    // Spacing (8pt grid)
    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 16
    static let spacingLG: CGFloat = 24
    static let spacingXL: CGFloat = 32
    static let spacingXXL: CGFloat = 48
    static let spacingHuge: CGFloat = 64

    // Poster sizes (slightly larger for cinematic feel)
    static let posterWidth: CGFloat = 240
    static let posterHeight: CGFloat = 360  // 2:3 ratio
    static let thumbnailWidth: CGFloat = 400
    static let thumbnailHeight: CGFloat = 225  // 16:9 ratio

    // Focus
    static let focusScale: CGFloat = 1.08
    static let focusShadowRadius: CGFloat = 25

    // Corner radius
    static let cardCornerRadius: CGFloat = 12

    // Typography
    static let titleSize: CGFloat = 48
    static let headlineSize: CGFloat = 38
    static let subheadlineSize: CGFloat = 29
    static let bodySize: CGFloat = 29
    static let captionSize: CGFloat = 23

    // Hero banner
    static let heroBannerHeight: CGFloat = 700
    static let heroLogoMaxWidth: CGFloat = 500
    static let heroLogoMaxHeight: CGFloat = 160
    static let heroTitleSize: CGFloat = 64
}

enum AetherConfig {
    static let pageSize = 50
    static let progressReportInterval: TimeInterval = 10
    static let searchDebounceInterval: TimeInterval = 0.5
    static let heroBannerInterval: TimeInterval = 8
    static let imageCacheSizeMB = 500
}
