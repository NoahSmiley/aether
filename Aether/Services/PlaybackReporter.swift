import Foundation

@MainActor
final class PlaybackReporter {
    private var itemId: String = ""
    private var mediaSourceId: String = ""
    private var positionTicks: Int64 = 0
    private var isPaused: Bool = false
    private var timer: Timer?

    private let api = JellyfinAPI.shared

    // MARK: - Start

    func start(itemId: String, mediaSourceId: String, positionTicks: Int64 = 0) {
        self.itemId = itemId
        self.mediaSourceId = mediaSourceId
        self.positionTicks = positionTicks
        self.isPaused = false

        let info = PlaybackStartInfo(
            itemId: itemId,
            mediaSourceId: mediaSourceId,
            audioStreamIndex: nil,
            subtitleStreamIndex: nil,
            playMethod: "Transcode",
            playSessionId: nil,
            canSeek: true,
            isPaused: false,
            positionTicks: positionTicks
        )

        Task {
            try? await api.reportPlaybackStart(info)
        }

        startTimer()
    }

    // MARK: - Position Updates

    func updatePosition(_ ticks: Int64) {
        self.positionTicks = ticks
    }

    // MARK: - Progress Reporting

    func reportProgress() {
        let info = PlaybackProgressInfo(
            itemId: itemId,
            mediaSourceId: mediaSourceId,
            audioStreamIndex: nil,
            subtitleStreamIndex: nil,
            positionTicks: positionTicks,
            isPaused: isPaused,
            isMuted: false,
            playMethod: "Transcode",
            playSessionId: nil,
            canSeek: true,
            volumeLevel: nil
        )

        Task {
            try? await api.reportPlaybackProgress(info)
        }
    }

    // MARK: - Pause / Resume

    func pause(at ticks: Int64) {
        self.positionTicks = ticks
        self.isPaused = true
        reportProgress()
        stopTimer()
    }

    func resume(at ticks: Int64) {
        self.positionTicks = ticks
        self.isPaused = false
        reportProgress()
        startTimer()
    }

    // MARK: - Stop

    func stop(at ticks: Int64) {
        self.positionTicks = ticks
        stopTimer()

        let info = PlaybackStopInfo(
            itemId: itemId,
            mediaSourceId: mediaSourceId,
            positionTicks: ticks,
            playSessionId: nil
        )

        Task {
            try? await api.reportPlaybackStopped(info)
        }
    }

    // MARK: - Timer Management

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(
            withTimeInterval: AetherConfig.progressReportInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.reportProgress()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
