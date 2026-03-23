import SwiftUI

extension View {
    func aetherFocusStyle(isFocused: Bool) -> some View {
        self
            .scaleEffect(isFocused ? AetherTheme.focusScale : 1.0)
            .shadow(
                color: AetherTheme.accent.opacity(isFocused ? 0.35 : 0),
                radius: isFocused ? AetherTheme.focusShadowRadius : 0
            )
            .shadow(
                color: .black.opacity(isFocused ? 0.6 : 0),
                radius: isFocused ? 15 : 0,
                y: isFocused ? 8 : 0
            )
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isFocused)
    }
}
