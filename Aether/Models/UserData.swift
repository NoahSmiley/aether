import Foundation

struct UserData: Codable, Hashable {
    let playbackPositionTicks: Int64?
    let playCount: Int?
    let isFavorite: Bool?
    let played: Bool?
    let unplayedItemCount: Int?
    let lastPlayedDate: String?
    let playedPercentage: Double?

    enum CodingKeys: String, CodingKey {
        case playbackPositionTicks = "PlaybackPositionTicks"
        case playCount = "PlayCount"
        case isFavorite = "IsFavorite"
        case played = "Played"
        case unplayedItemCount = "UnplayedItemCount"
        case lastPlayedDate = "LastPlayedDate"
        case playedPercentage = "PlayedPercentage"
    }

    /// Progress as a value between 0.0 and 1.0.
    var progressPercent: Double {
        (playedPercentage ?? 0) / 100.0
    }

    /// Playback resume position converted from ticks to seconds.
    var resumePositionSeconds: Double {
        Double(playbackPositionTicks ?? 0) / 10_000_000.0
    }
}
