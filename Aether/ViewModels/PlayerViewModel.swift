import Foundation
import AVFoundation
import AVKit

@MainActor
@Observable
class PlayerViewModel {
    var player: AVPlayer?
    var isPlaying = false
    var currentTime: Double = 0
    var duration: Double = 0
    var isLoading = true
    var showResumePrompt = false
    var resumePositionTicks: Int64 = 0
    var error: String?

    private let api = JellyfinAPI.shared
    private var reporter: PlaybackReporter?
    private var timeObserverToken: Any?
    private var currentItem: BaseItemDto?
    private var mediaSourceId: String?
    var streamURL: URL?
    private var playSessionId: String = UUID().uuidString

    func prepareToPlay(item: BaseItemDto) async {
        isLoading = true
        error = nil
        currentItem = item
        playSessionId = UUID().uuidString

        do {
            // Get the stream URL from JellyfinAPI
            let mediaSource = item.mediaSources?.first
            mediaSourceId = mediaSource?.id ?? item.id

            streamURL = await api.streamURL(
                itemId: item.id,
                mediaSourceId: mediaSourceId ?? item.id
            )

            #if DEBUG
            print("[Player] Stream URL: \(streamURL?.absoluteString ?? "nil")")
            print("[Player] MediaSource ID: \(mediaSourceId ?? "nil")")
            print("[Player] Has mediaSources: \(item.mediaSources?.count ?? 0)")
            #endif

            // Determine duration from the item
            if let ticks = item.runTimeTicks {
                duration = ticks.asSeconds
            }

            // Check for resume position
            let positionTicks = item.userData?.playbackPositionTicks ?? 0
            if positionTicks > 0 {
                resumePositionTicks = positionTicks
                showResumePrompt = true
                isLoading = false
            } else {
                isLoading = false
                play(fromBeginning: true)
            }
        }
    }

    func play(fromBeginning: Bool) {
        guard let streamURL else {
            error = "No stream URL available"
            return
        }

        let playerItem = AVPlayerItem(url: streamURL)
        let avPlayer = AVPlayer(playerItem: playerItem)
        self.player = avPlayer

        showResumePrompt = false

        // Seek to resume position if not starting from the beginning
        if !fromBeginning, resumePositionTicks > 0 {
            let resumeSeconds = Double(resumePositionTicks) / 10_000_000.0
            let seekTime = CMTime(seconds: resumeSeconds, preferredTimescale: 600)
            avPlayer.seek(to: seekTime)
        }

        // Set up periodic time observer
        let interval = CMTime(seconds: 1.0, preferredTimescale: 600)
        timeObserverToken = avPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                self?.onTimeUpdate(time)
            }
        }

        // Create and start the playback reporter
        if let currentItem, let mediaSourceId {
            let r = PlaybackReporter()
            reporter = r
            let startTicks = fromBeginning ? 0 : resumePositionTicks
            r.start(itemId: currentItem.id, mediaSourceId: mediaSourceId, positionTicks: startTicks)
        }

        // Observe for errors
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { notification in
            if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
                print("[Player] Playback error: \(error.localizedDescription)")
            }
        }

        avPlayer.play()
        isPlaying = true

        #if DEBUG
        // Log player status after a delay
        Task {
            try? await Task.sleep(for: .seconds(3))
            print("[Player] Status: \(avPlayer.status.rawValue), timeControl: \(avPlayer.timeControlStatus.rawValue)")
            print("[Player] Item status: \(avPlayer.currentItem?.status.rawValue ?? -1)")
            if let error = avPlayer.currentItem?.error {
                print("[Player] Item error: \(error.localizedDescription)")
            }
        }
        #endif
    }

    func stop() {
        player?.pause()
        isPlaying = false

        // Report playback stopped
        let positionTicks = currentTime.asTicks
        reporter?.stop(at: positionTicks)

        // Clean up the time observer
        if let token = timeObserverToken, let player {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }

        player = nil
        reporter = nil
    }

    func onTimeUpdate(_ time: CMTime) {
        let seconds = CMTimeGetSeconds(time)
        guard seconds.isFinite else { return }

        currentTime = seconds

        // Update duration from player item if available
        if let playerDuration = player?.currentItem?.duration {
            let d = CMTimeGetSeconds(playerDuration)
            if d.isFinite && d > 0 {
                duration = d
            }
        }

        // Feed the reporter with updated position
        reporter?.updatePosition(seconds.asTicks)
    }
}

