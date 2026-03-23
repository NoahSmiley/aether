import Foundation

/// Builds Jellyfin image URLs synchronously from the stored server base URL.
/// This avoids needing to call into the JellyfinAPI actor from SwiftUI view bodies.
enum ImageURLBuilder {
    static var baseURL: URL? {
        guard let urlString = try? KeychainHelper.read(forKey: KeychainHelper.Keys.serverURL) else { return nil }
        return URL(string: urlString)
    }

    // MARK: - Item Images

    static func imageURL(
        itemId: String,
        imageType: String,
        maxWidth: Int? = nil,
        tag: String? = nil
    ) -> URL? {
        guard let base = baseURL else { return nil }
        var components = URLComponents(
            url: base.appendingPathComponent("Items/\(itemId)/Images/\(imageType)"),
            resolvingAgainstBaseURL: false
        )
        var queryItems: [URLQueryItem] = []
        if let maxWidth {
            queryItems.append(URLQueryItem(name: "maxWidth", value: "\(maxWidth)"))
        }
        if let tag {
            queryItems.append(URLQueryItem(name: "tag", value: tag))
        }
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }
        return components?.url
    }

    static func posterURL(itemId: String, maxWidth: Int? = nil, tag: String? = nil) -> URL? {
        imageURL(itemId: itemId, imageType: "Primary", maxWidth: maxWidth, tag: tag)
    }

    static func backdropURL(itemId: String, maxWidth: Int? = nil, tag: String? = nil) -> URL? {
        imageURL(itemId: itemId, imageType: "Backdrop", maxWidth: maxWidth, tag: tag)
    }

    static func thumbURL(itemId: String, maxWidth: Int? = nil, tag: String? = nil) -> URL? {
        imageURL(itemId: itemId, imageType: "Thumb", maxWidth: maxWidth, tag: tag)
    }

    static func logoURL(itemId: String, maxWidth: Int? = nil, tag: String? = nil) -> URL? {
        imageURL(itemId: itemId, imageType: "Logo", maxWidth: maxWidth, tag: tag)
    }

    // MARK: - Person Images

    static func personImageURL(personId: String, tag: String? = nil, maxWidth: Int? = nil) -> URL? {
        guard let base = baseURL else { return nil }
        var components = URLComponents(
            url: base.appendingPathComponent("Items/\(personId)/Images/Primary"),
            resolvingAgainstBaseURL: false
        )
        var queryItems: [URLQueryItem] = []
        if let maxWidth {
            queryItems.append(URLQueryItem(name: "maxWidth", value: "\(maxWidth)"))
        }
        if let tag {
            queryItems.append(URLQueryItem(name: "tag", value: tag))
        }
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }
        return components?.url
    }
}
