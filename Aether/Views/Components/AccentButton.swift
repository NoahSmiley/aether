import SwiftUI

/// A Netflix/HBO-styled button with two distinct styles:
/// - `.primary`: White filled background with black text (like Netflix's "Play" button)
/// - `.secondary`: Semi-transparent with white border (like "My List" or "More Info")
struct AccentButton: View {
    let title: String
    var icon: String? = nil
    var style: Style = .primary
    var action: () -> Void

    @FocusState private var isFocused: Bool

    enum Style {
        case primary
        case secondary
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: LumaTheme.spacingSM) {
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
        .buttonStyle(NoChromeFocusStyle())
        .focused($isFocused)
        .scaleEffect(isFocused ? 1.08 : 1.0)
        .shadow(
            color: shadowColor,
            radius: isFocused ? 16 : 0,
            y: isFocused ? 8 : 0
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
    }

    private var foregroundColor: Color {
        switch style {
        case .primary: return .black
        case .secondary: return .white
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .primary:
            Color.white.opacity(isFocused ? 1.0 : 0.85)
        case .secondary:
            Color.white.opacity(isFocused ? 0.25 : 0.1)
        }
    }

    private var borderColor: Color {
        Color.white.opacity(isFocused ? 0.7 : 0.3)
    }

    private var shadowColor: Color {
        switch style {
        case .primary:
            return Color.white.opacity(isFocused ? 0.4 : 0)
        case .secondary:
            return Color.black.opacity(isFocused ? 0.4 : 0)
        }
    }
}
