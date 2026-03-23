import SwiftUI
import AVKit

struct PlayerView: View {
    let item: BaseItemDto
    @State private var viewModel = PlayerViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player = viewModel.player {
                TVPlayerViewController(player: player)
                    .ignoresSafeArea()
            }

            // Clean resume prompt overlay with blurred background
            if viewModel.showResumePrompt {
                resumePromptOverlay
                    .transition(.opacity)
            }

            if viewModel.isLoading {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.showResumePrompt)
        .onAppear {
            Task { await viewModel.prepareToPlay(item: item) }
        }
        .onDisappear {
            viewModel.stop()
        }
    }

    // MARK: - Resume Prompt

    private var resumePromptOverlay: some View {
        ZStack {
            // Full-screen blurred backdrop
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                // Title
                Text("Resume Playback")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(.white)

                // Time indicator
                Text("You stopped at \(formatTime(viewModel.resumePositionTicks))")
                    .font(.system(size: LumaTheme.bodySize))
                    .foregroundStyle(LumaTheme.textSecondary)

                // Two clear buttons
                HStack(spacing: 32) {
                    // Resume — primary white button
                    AccentButton(title: "Resume", icon: "play.fill", style: .primary) {
                        viewModel.play(fromBeginning: false)
                    }

                    // Start Over — secondary outlined button
                    AccentButton(title: "Start Over", icon: "arrow.counterclockwise", style: .secondary) {
                        viewModel.play(fromBeginning: true)
                    }
                }
            }
            .padding(60)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.5), radius: 40, y: 10)
        }
    }

    // MARK: - Helpers

    private func formatTime(_ ticks: Int64) -> String {
        let totalSeconds = Int(ticks.asSeconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

// MARK: - AVPlayerViewController Wrapper

struct TVPlayerViewController: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}
}
