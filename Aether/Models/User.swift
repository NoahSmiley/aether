import Foundation

struct UserDto: Codable {
    let name: String
    let id: String
    let serverId: String?
    let hasPassword: Bool?
    let primaryImageTag: String?
    let configuration: UserConfiguration?
    let policy: UserPolicy?

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case id = "Id"
        case serverId = "ServerId"
        case hasPassword = "HasPassword"
        case primaryImageTag = "PrimaryImageTag"
        case configuration = "Configuration"
        case policy = "Policy"
    }
}

struct UserConfiguration: Codable {
    let playDefaultAudioTrack: Bool?
    let subtitleLanguagePreference: String?
    let subtitleMode: String?

    enum CodingKeys: String, CodingKey {
        case playDefaultAudioTrack = "PlayDefaultAudioTrack"
        case subtitleLanguagePreference = "SubtitleLanguagePreference"
        case subtitleMode = "SubtitleMode"
    }
}

struct UserPolicy: Codable {
    let isAdministrator: Bool?
    let isDisabled: Bool?
    let enableAllFolders: Bool?

    enum CodingKeys: String, CodingKey {
        case isAdministrator = "IsAdministrator"
        case isDisabled = "IsDisabled"
        case enableAllFolders = "EnableAllFolders"
    }
}
