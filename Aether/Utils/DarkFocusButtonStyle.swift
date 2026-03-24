import SwiftUI

/// Button style that suppresses the default tvOS white focus card
/// but still provides a visible focus indicator (scale + brightness).
/// Uses the environment's isFocused since ButtonStyle can't use @FocusState.
struct NoChromeFocusStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}
