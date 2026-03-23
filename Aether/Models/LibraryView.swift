import Foundation

struct LibraryView: Codable, Identifiable {
    let id: String
    let name: String?
    let collectionType: String?
    let imageTags: [String: String]?
    let etag: String?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case collectionType = "CollectionType"
        case imageTags = "ImageTags"
        case etag = "Etag"
    }
}
