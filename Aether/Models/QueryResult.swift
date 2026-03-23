import Foundation

struct QueryResult<T: Codable>: Codable {
    let items: [T]
    let totalRecordCount: Int
    let startIndex: Int?

    enum CodingKeys: String, CodingKey {
        case items = "Items"
        case totalRecordCount = "TotalRecordCount"
        case startIndex = "StartIndex"
    }
}
