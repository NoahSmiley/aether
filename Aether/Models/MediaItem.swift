import Foundation

struct BaseItemDto: Codable, Identifiable, Hashable {
    // Identity
    let id: String
    let name: String?
    let originalTitle: String?
    let serverId: String?
    let type: ItemType?

    // Metadata
    let overview: String?
    let taglines: [String]?
    let genres: [String]?
    let studios: [StudioInfo]?
    let people: [PersonInfo]?
    let communityRating: Double?
    let criticRating: Double?
    let officialRating: String?
    let premiereDate: String?
    let productionYear: Int?
    let endDate: String?

    // Duration & Progress
    let runTimeTicks: Int64?
    let userData: UserData?

    // Series / Season / Episode
    let seriesId: String?
    let seriesName: String?
    let seasonId: String?
    let seasonName: String?
    let indexNumber: Int?
    let parentIndexNumber: Int?

    // Media Info
    let mediaSources: [MediaSourceInfo]?
    let mediaType: String?
    let container: String?

    // Images
    let imageTags: [String: String]?
    let backdropImageTags: [String]?
    let parentBackdropImageTags: [String]?
    let primaryImageAspectRatio: Double?

    // Hierarchy
    let parentId: String?
    let collectionType: String?

    // Counts
    let childCount: Int?
    let recursiveItemCount: Int?

    // Status
    let status: String?
    let airDays: [String]?
    let airTime: String?

    // Live TV
    let channelNumber: String?
    let channelName: String?
    let currentProgram: LiveTVProgram?
    let startDate: String?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case originalTitle = "OriginalTitle"
        case serverId = "ServerId"
        case type = "Type"
        case overview = "Overview"
        case taglines = "Taglines"
        case genres = "Genres"
        case studios = "Studios"
        case people = "People"
        case communityRating = "CommunityRating"
        case criticRating = "CriticRating"
        case officialRating = "OfficialRating"
        case premiereDate = "PremiereDate"
        case productionYear = "ProductionYear"
        case endDate = "EndDate"
        case runTimeTicks = "RunTimeTicks"
        case userData = "UserData"
        case seriesId = "SeriesId"
        case seriesName = "SeriesName"
        case seasonId = "SeasonId"
        case seasonName = "SeasonName"
        case indexNumber = "IndexNumber"
        case parentIndexNumber = "ParentIndexNumber"
        case mediaSources = "MediaSources"
        case mediaType = "MediaType"
        case container = "Container"
        case imageTags = "ImageTags"
        case backdropImageTags = "BackdropImageTags"
        case parentBackdropImageTags = "ParentBackdropImageTags"
        case primaryImageAspectRatio = "PrimaryImageAspectRatio"
        case parentId = "ParentId"
        case collectionType = "CollectionType"
        case childCount = "ChildCount"
        case recursiveItemCount = "RecursiveItemCount"
        case status = "Status"
        case airDays = "AirDays"
        case airTime = "AirTime"
        case channelNumber = "ChannelNumber"
        case channelName = "ChannelName"
        case currentProgram = "CurrentProgram"
        case startDate = "StartDate"
    }

    static func == (lhs: BaseItemDto, rhs: BaseItemDto) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

enum ItemType: String, Codable {
    case movie = "Movie"
    case series = "Series"
    case season = "Season"
    case episode = "Episode"
    case boxSet = "BoxSet"
    case person = "Person"
    case musicAlbum = "MusicAlbum"
    case musicArtist = "MusicArtist"
    case audio = "Audio"
    case folder = "Folder"
    case collectionFolder = "CollectionFolder"
    case tvChannel = "TvChannel"
    case liveTvChannel = "LiveTvChannel"
    case program = "Program"
    case liveTvProgram = "LiveTvProgram"
    case unknown

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = ItemType(rawValue: value) ?? .unknown
    }
}

struct LiveTVProgram: Codable, Hashable {
    let id: String?
    let name: String?
    let overview: String?
    let startDate: String?
    let endDate: String?
    let channelId: String?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case overview = "Overview"
        case startDate = "StartDate"
        case endDate = "EndDate"
        case channelId = "ChannelId"
    }
}

struct StudioInfo: Codable, Hashable {
    let name: String?
    let id: String?

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case id = "Id"
    }
}
