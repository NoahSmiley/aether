import Foundation

struct PlaybackStartInfo: Encodable {
    let itemId: String
    let mediaSourceId: String?
    let audioStreamIndex: Int?
    let subtitleStreamIndex: Int?
    let playMethod: String?
    let playSessionId: String?
    let canSeek: Bool
    let isPaused: Bool
    let positionTicks: Int64?

    enum CodingKeys: String, CodingKey {
        case itemId = "ItemId"
        case mediaSourceId = "MediaSourceId"
        case audioStreamIndex = "AudioStreamIndex"
        case subtitleStreamIndex = "SubtitleStreamIndex"
        case playMethod = "PlayMethod"
        case playSessionId = "PlaySessionId"
        case canSeek = "CanSeek"
        case isPaused = "IsPaused"
        case positionTicks = "PositionTicks"
    }
}

struct PlaybackProgressInfo: Encodable {
    let itemId: String
    let mediaSourceId: String?
    let audioStreamIndex: Int?
    let subtitleStreamIndex: Int?
    let positionTicks: Int64?
    let isPaused: Bool
    let isMuted: Bool?
    let playMethod: String?
    let playSessionId: String?
    let canSeek: Bool
    let volumeLevel: Int?

    enum CodingKeys: String, CodingKey {
        case itemId = "ItemId"
        case mediaSourceId = "MediaSourceId"
        case audioStreamIndex = "AudioStreamIndex"
        case subtitleStreamIndex = "SubtitleStreamIndex"
        case positionTicks = "PositionTicks"
        case isPaused = "IsPaused"
        case isMuted = "IsMuted"
        case playMethod = "PlayMethod"
        case playSessionId = "PlaySessionId"
        case canSeek = "CanSeek"
        case volumeLevel = "VolumeLevel"
    }
}

struct PlaybackStopInfo: Encodable {
    let itemId: String
    let mediaSourceId: String?
    let positionTicks: Int64?
    let playSessionId: String?

    enum CodingKeys: String, CodingKey {
        case itemId = "ItemId"
        case mediaSourceId = "MediaSourceId"
        case positionTicks = "PositionTicks"
        case playSessionId = "PlaySessionId"
    }
}
