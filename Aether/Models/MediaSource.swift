import Foundation

struct MediaSourceInfo: Codable, Hashable {
    let id: String?
    let name: String?
    let container: String?
    let size: Int64?
    let bitrate: Int?
    let path: String?
    let mediaStreams: [MediaStream]?
    let supportsDirectPlay: Bool?
    let supportsDirectStream: Bool?
    let supportsTranscoding: Bool?
    let transcodingUrl: String?
    let defaultAudioStreamIndex: Int?
    let defaultSubtitleStreamIndex: Int?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case container = "Container"
        case size = "Size"
        case bitrate = "Bitrate"
        case path = "Path"
        case mediaStreams = "MediaStreams"
        case supportsDirectPlay = "SupportsDirectPlay"
        case supportsDirectStream = "SupportsDirectStream"
        case supportsTranscoding = "SupportsTranscoding"
        case transcodingUrl = "TranscodingUrl"
        case defaultAudioStreamIndex = "DefaultAudioStreamIndex"
        case defaultSubtitleStreamIndex = "DefaultSubtitleStreamIndex"
    }

    /// Convenience: first video stream's resolution label.
    var resolutionLabel: String? {
        guard let video = mediaStreams?.first(where: { $0.type == .video }) else { return nil }
        guard let h = video.height else { return nil }
        if h >= 2160 { return "4K" }
        if h >= 1080 { return "1080p" }
        if h >= 720 { return "720p" }
        return "\(h)p"
    }
}

struct MediaStream: Codable, Hashable {
    let type: MediaStreamType?
    let codec: String?
    let language: String?
    let displayTitle: String?
    let title: String?
    let isDefault: Bool?
    let isForced: Bool?
    let isExternal: Bool?
    let index: Int?

    // Video-specific
    let width: Int?
    let height: Int?
    let bitRate: Int?
    let videoRange: String?
    let videoRangeType: String?

    // Audio-specific
    let channels: Int?
    let channelLayout: String?
    let sampleRate: Int?

    // Subtitle-specific
    let deliveryMethod: String?
    let deliveryUrl: String?

    enum CodingKeys: String, CodingKey {
        case type = "Type"
        case codec = "Codec"
        case language = "Language"
        case displayTitle = "DisplayTitle"
        case title = "Title"
        case isDefault = "IsDefault"
        case isForced = "IsForced"
        case isExternal = "IsExternal"
        case index = "Index"
        case width = "Width"
        case height = "Height"
        case bitRate = "BitRate"
        case videoRange = "VideoRange"
        case videoRangeType = "VideoRangeType"
        case channels = "Channels"
        case channelLayout = "ChannelLayout"
        case sampleRate = "SampleRate"
        case deliveryMethod = "DeliveryMethod"
        case deliveryUrl = "DeliveryUrl"
    }
}

enum MediaStreamType: String, Codable {
    case video = "Video"
    case audio = "Audio"
    case subtitle = "Subtitle"
    case embeddedImage = "EmbeddedImage"
}
