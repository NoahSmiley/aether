import SwiftUI

/// Button style that suppresses the default tvOS white focus card
/// but still provides a visible focus indicator (scale + brightness).
struct NoChromeFocusStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        NoChromeFocusInner(configuration: configuration)
    }
}

/// Inner view that can use @FocusState to track focus.
private struct NoChromeFocusInner: View {
    let configuration: ButtonStyleConfiguration
    @FocusState private var isFocused: Bool

    var body: some View {
        configuration.label
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .brightness(isFocused ? 0.2 : 0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeOut(duration: 0.15), value: isFocused)
            .focused($isFocused)
    }
}
