import SwiftUI

@main
struct LumaApp: App {
    @State private var authViewModel = AuthViewModel()

    init() {
        ImageService.configure()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.isAuthenticated {
                    ContentView()
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                } else if authViewModel.isConnected {
                    LoginView(viewModel: authViewModel)
                        .transition(.opacity)
                } else {
                    ServerSetupView(viewModel: authViewModel)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.5), value: authViewModel.isAuthenticated)
            .animation(.easeInOut(duration: 0.4), value: authViewModel.isConnected)
            .preferredColorScheme(.dark)
            .task { await authViewModel.restoreSession() }
        }
    }
}
