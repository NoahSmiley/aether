import SwiftUI

/// A Netflix/HBO-styled button with two distinct styles:
/// - `.primary`: White filled background with black text (like Netflix's "Play" button)
/// - `.secondary`: Semi-transparent with white border (like "My List" or "More Info")
struct AccentButton: View {
    let title: String
    var icon: String? = nil
    var style: Style = .primary
    var action: () -> Void

    @Environment(\.isFocused) private var isFocused

    enum Style {
        case primary    // White filled, black text — the main CTA
        case secondary  // Semi-transparent, white border — secondary actions
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: AetherTheme.spacingSM) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .bold))
                }
                Text(title)
                    .font(.system(size: 26, weight: .bold))
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 16)
            .foregroundColor(foregroundColor)
            .background(backgroundView)
            .clipShape(Capsule())
            .overlay {
                if style == .secondary {
                    Capsule()
                        .stroke(borderColor, lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isFocused ? 1.06 : 1.0)
        .brightness(isFocused ? 0.1 : 0)
        .shadow(
            color: shadowColor,
            radius: isFocused ? 16 : 0,
            y: isFocused ? 8 : 0
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
    }

    // MARK: - Private

    private var foregroundColor: Color {
        switch style {
        case .primary:
            return .black
        case .secondary:
            return .white
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .primary:
            Color.white
        case .secondary:
            Color.white.opacity(isFocused ? 0.2 : 0.1)
        }
    }

    private var borderColor: Color {
        Color.white.opacity(isFocused ? 0.6 : 0.3)
    }

    private var shadowColor: Color {
        switch style {
        case .primary:
            return Color.white.opacity(isFocused ? 0.3 : 0)
        case .secondary:
            return Color.black.opacity(isFocused ? 0.4 : 0)
        }
    }
}
