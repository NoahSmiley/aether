import Foundation

struct PersonInfo: Codable, Identifiable, Hashable {
    let name: String?
    let id: String?
    let role: String?
    let type: PersonType?
    let primaryImageTag: String?

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case id = "Id"
        case role = "Role"
        case type = "Type"
        case primaryImageTag = "PrimaryImageTag"
    }
}

enum PersonType: String, Codable {
    case actor = "Actor"
    case director = "Director"
    case writer = "Writer"
    case producer = "Producer"
    case unknown

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = PersonType(rawValue: value) ?? .unknown
    }
}
