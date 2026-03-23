import Foundation

actor JellyfinAPI {
    static let shared = JellyfinAPI()

    private var baseURL: URL?
    private var accessToken: String?
    private var userId: String?
    private let deviceId: String
    private let session: URLSession

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private init() {
        // Load persisted deviceId or generate a new one
        if let existingId = try? KeychainHelper.read(forKey: KeychainHelper.Keys.deviceId) {
            self.deviceId = existingId
        } else {
            let newId = UUID().uuidString
            try? KeychainHelper.save(newId, forKey: KeychainHelper.Keys.deviceId)
            self.deviceId = newId
        }

        // Restore credentials from Keychain
        self.accessToken = try? KeychainHelper.read(forKey: KeychainHelper.Keys.accessToken)
        self.userId = try? KeychainHelper.read(forKey: KeychainHelper.Keys.userId)

        if let urlString = try? KeychainHelper.read(forKey: KeychainHelper.Keys.serverURL) {
            self.baseURL = URL(string: urlString)
        }

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }

    // MARK: - Configuration

    func configure(baseURL: URL) {
        self.baseURL = baseURL
    }

    func setAuth(token: String, userId: String) {
        self.accessToken = token
        self.userId = userId
    }

    func clearAuth() {
        self.accessToken = nil
        self.userId = nil
    }

    func currentUserId() -> String? {
        userId
    }

    // MARK: - Authorization Header

    private func authorizationHeader() -> String {
        var header = "MediaBrowser "
        header += "Client=\"Aether\", "
        header += "Device=\"AppleTV\", "
        header += "DeviceId=\"\(deviceId)\", "
        header += "Version=\"1.0\""
        if let token = accessToken {
            header += ", Token=\"\(token)\""
        }
        return header
    }

    // MARK: - Generic Request

    private func request<T: Decodable>(
        _ method: String,
        path: String,
        queryItems: [URLQueryItem]? = nil,
        body: (any Encodable)? = nil
    ) async throws -> T {
        guard let baseURL else { throw JellyfinError.invalidURL }

        var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )
        if let queryItems, !queryItems.isEmpty {
            components?.queryItems = queryItems
        }

        guard let url = components?.url else { throw JellyfinError.invalidURL }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.setValue(authorizationHeader(), forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body {
            urlRequest.httpBody = try encoder.encodeAny(body)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw JellyfinError.serverUnreachable
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw JellyfinError.invalidResponse
        }

        #if DEBUG
        print("[JellyfinAPI] \(method) \(url.absoluteString) -> \(httpResponse.statusCode)")
        if httpResponse.statusCode >= 400 {
            print("[JellyfinAPI] Response body: \(String(data: data, encoding: .utf8) ?? "nil")")
            if let body {
                let bodyData = try? encoder.encodeAny(body)
                print("[JellyfinAPI] Request body: \(String(data: bodyData ?? Data(), encoding: .utf8) ?? "nil")")
            }
        }
        #endif

        switch httpResponse.statusCode {
        case 200...299:
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw JellyfinError.decodingError(error)
            }
        case 401:
            throw JellyfinError.unauthorized
        default:
            throw JellyfinError.httpError(statusCode: httpResponse.statusCode)
        }
    }

    private func requestNoResponse(
        _ method: String,
        path: String,
        queryItems: [URLQueryItem]? = nil,
        body: (any Encodable)? = nil
    ) async throws {
        guard let baseURL else { throw JellyfinError.invalidURL }

        var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )
        if let queryItems, !queryItems.isEmpty {
            components?.queryItems = queryItems
        }

        guard let url = components?.url else { throw JellyfinError.invalidURL }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.setValue(authorizationHeader(), forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body {
            urlRequest.httpBody = try encoder.encodeAny(body)
        }

        let response: URLResponse
        do {
            (_, response) = try await session.data(for: urlRequest)
        } catch {
            throw JellyfinError.serverUnreachable
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw JellyfinError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw JellyfinError.unauthorized
        default:
            throw JellyfinError.httpError(statusCode: httpResponse.statusCode)
        }
    }

    // MARK: - Convenience HTTP Methods

    func get<T: Decodable>(path: String, query: [String: String] = [:]) async throws -> T {
        let queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        return try await request("GET", path: path, queryItems: queryItems)
    }

    func post<T: Decodable>(path: String, body: (any Encodable)? = nil) async throws -> T {
        return try await request("POST", path: path, body: body)
    }

    func postNoResponse(path: String, body: (any Encodable)? = nil) async throws {
        try await requestNoResponse("POST", path: path, body: body)
    }

    func deleteNoResponse(path: String) async throws {
        try await requestNoResponse("DELETE", path: path)
    }

    // MARK: - Server Validation

    func validateServer(url: URL) async throws -> PublicServerInfo {
        let previousBaseURL = baseURL
        baseURL = url
        do {
            let info: PublicServerInfo = try await get(path: "/System/Info/Public")
            return info
        } catch {
            baseURL = previousBaseURL
            throw error
        }
    }

    // MARK: - Authentication

    func login(username: String, password: String) async throws -> AuthResponse {
        let body = AuthRequest(username: username, pw: password)
        let response: AuthResponse = try await post(path: "/Users/AuthenticateByName", body: body)
        self.accessToken = response.accessToken
        self.userId = response.user.id
        return response
    }

    func logout() async throws {
        try await postNoResponse(path: "/Sessions/Logout")
        clearAuth()
    }

    // MARK: - Libraries

    func getLibraries() async throws -> [BaseItemDto] {
        guard let userId else { throw JellyfinError.noUserId }
        let result: QueryResult<BaseItemDto> = try await get(path: "/Users/\(userId)/Views")
        return result.items
    }

    // MARK: - Items

    func getItems(
        parentId: String? = nil,
        includeTypes: [String]? = nil,
        sortBy: String? = nil,
        sortOrder: String? = nil,
        limit: Int? = nil,
        startIndex: Int? = nil,
        genres: String? = nil,
        years: String? = nil,
        searchTerm: String? = nil,
        filters: String? = nil,
        recursive: Bool? = nil
    ) async throws -> QueryResult<BaseItemDto> {
        guard let userId else { throw JellyfinError.noUserId }

        var query: [String: String] = [
            "UserId": userId,
            "Fields": "Overview,Genres,People,Studios,CommunityRating,OfficialRating,MediaSources,RunTimeTicks,PremiereDate,ImageTags,BackdropImageTags,ParentId,SeriesId,SeasonId,UserData",
            "ImageTypeLimit": "1",
            "EnableImageTypes": "Primary,Backdrop,Thumb"
        ]

        if let parentId { query["ParentId"] = parentId }
        if let includeTypes { query["IncludeItemTypes"] = includeTypes.joined(separator: ",") }
        if let sortBy { query["SortBy"] = sortBy }
        if let sortOrder { query["SortOrder"] = sortOrder }
        if let limit { query["Limit"] = "\(limit)" }
        if let startIndex { query["StartIndex"] = "\(startIndex)" }
        if let genres { query["Genres"] = genres }
        if let years { query["Years"] = years }
        if let searchTerm { query["SearchTerm"] = searchTerm }
        if let filters { query["Filters"] = filters }
        if let recursive { query["Recursive"] = "\(recursive)" }

        return try await get(path: "/Items", query: query)
    }

    func getItem(id: String) async throws -> BaseItemDto {
        guard let userId else { throw JellyfinError.noUserId }
        return try await get(
            path: "/Users/\(userId)/Items/\(id)",
            query: [
                "Fields": "Overview,Genres,People,Studios,CommunityRating,OfficialRating,MediaSources,RunTimeTicks,PremiereDate,ImageTags,BackdropImageTags,ParentId,SeriesId,SeasonId,UserData"
            ]
        )
    }

    func getLatestItems(parentId: String? = nil, limit: Int? = nil) async throws -> [BaseItemDto] {
        guard let userId else { throw JellyfinError.noUserId }

        var query: [String: String] = [
            "UserId": userId,
            "Fields": "ImageTags,UserData,RunTimeTicks,CommunityRating,OfficialRating",
            "ImageTypeLimit": "1",
            "EnableImageTypes": "Primary,Backdrop,Thumb"
        ]
        if let parentId { query["ParentId"] = parentId }
        if let limit { query["Limit"] = "\(limit)" }

        return try await get(path: "/Items/Latest", query: query)
    }

    func getResumeItems(limit: Int? = nil) async throws -> QueryResult<BaseItemDto> {
        guard let userId else { throw JellyfinError.noUserId }

        var query: [String: String] = [
            "UserId": userId,
            "Fields": "ImageTags,UserData,RunTimeTicks,CommunityRating,OfficialRating,SeriesId,SeasonId,ParentId",
            "MediaTypes": "Video",
            "ImageTypeLimit": "1",
            "EnableImageTypes": "Primary,Backdrop,Thumb"
        ]
        if let limit { query["Limit"] = "\(limit)" }

        return try await get(path: "/Items/Resume", query: query)
    }

    func getNextUp(limit: Int? = nil) async throws -> QueryResult<BaseItemDto> {
        guard let userId else { throw JellyfinError.noUserId }

        var query: [String: String] = [
            "UserId": userId,
            "Fields": "ImageTags,UserData,RunTimeTicks,CommunityRating,OfficialRating,SeriesId,SeasonId,ParentId",
            "ImageTypeLimit": "1",
            "EnableImageTypes": "Primary,Backdrop,Thumb"
        ]
        if let limit { query["Limit"] = "\(limit)" }

        return try await get(path: "/Shows/NextUp", query: query)
    }

    // MARK: - TV Shows

    func getSeasons(seriesId: String) async throws -> QueryResult<BaseItemDto> {
        guard let userId else { throw JellyfinError.noUserId }
        return try await get(
            path: "/Shows/\(seriesId)/Seasons",
            query: [
                "UserId": userId,
                "Fields": "ImageTags,UserData,Overview"
            ]
        )
    }

    func getEpisodes(seriesId: String, seasonId: String) async throws -> QueryResult<BaseItemDto> {
        guard let userId else { throw JellyfinError.noUserId }
        return try await get(
            path: "/Shows/\(seriesId)/Episodes",
            query: [
                "UserId": userId,
                "SeasonId": seasonId,
                "Fields": "ImageTags,UserData,RunTimeTicks,Overview,MediaSources"
            ]
        )
    }

    // MARK: - Discovery

    func getSimilar(itemId: String, limit: Int? = nil) async throws -> QueryResult<BaseItemDto> {
        guard let userId else { throw JellyfinError.noUserId }

        var query: [String: String] = [
            "UserId": userId,
            "Fields": "ImageTags,UserData,RunTimeTicks,CommunityRating,OfficialRating"
        ]
        if let limit { query["Limit"] = "\(limit)" }

        return try await get(path: "/Items/\(itemId)/Similar", query: query)
    }

    func search(term: String, limit: Int? = nil) async throws -> QueryResult<BaseItemDto> {
        guard let userId else { throw JellyfinError.noUserId }

        var query: [String: String] = [
            "UserId": userId,
            "SearchTerm": term,
            "IncludeItemTypes": "Movie,Series,Episode,Person",
            "Recursive": "true",
            "Fields": "ImageTags,UserData,RunTimeTicks,CommunityRating,OfficialRating,SeriesId,SeasonId",
            "ImageTypeLimit": "1",
            "EnableImageTypes": "Primary,Backdrop,Thumb"
        ]
        if let limit { query["Limit"] = "\(limit)" }

        return try await get(path: "/Items", query: query)
    }

    // MARK: - Playback Reporting

    func reportPlaybackStart(_ info: PlaybackStartInfo) async throws {
        try await postNoResponse(path: "/Sessions/Playing", body: info)
    }

    func reportPlaybackProgress(_ info: PlaybackProgressInfo) async throws {
        try await postNoResponse(path: "/Sessions/Playing/Progress", body: info)
    }

    func reportPlaybackStopped(_ info: PlaybackStopInfo) async throws {
        try await postNoResponse(path: "/Sessions/Playing/Stopped", body: info)
    }

    // MARK: - User Actions

    func markPlayed(itemId: String) async throws {
        guard let userId else { throw JellyfinError.noUserId }
        try await postNoResponse(path: "/Users/\(userId)/PlayedItems/\(itemId)")
    }

    func markUnplayed(itemId: String) async throws {
        guard let userId else { throw JellyfinError.noUserId }
        try await deleteNoResponse(path: "/Users/\(userId)/PlayedItems/\(itemId)")
    }

    func toggleFavorite(itemId: String, isFavorite: Bool) async throws {
        guard let userId else { throw JellyfinError.noUserId }
        if isFavorite {
            try await postNoResponse(path: "/Users/\(userId)/FavoriteItems/\(itemId)")
        } else {
            try await deleteNoResponse(path: "/Users/\(userId)/FavoriteItems/\(itemId)")
        }
    }

    // MARK: - Live TV

    func getLiveTVChannels(limit: Int? = nil) async throws -> QueryResult<BaseItemDto> {
        guard let userId else { throw JellyfinError.noUserId }

        var query: [String: String] = [
            "UserId": userId,
            "Fields": "ImageTags,UserData,Overview,ChannelNumber,CurrentProgram",
            "EnableImageTypes": "Primary,Backdrop,Thumb",
            "AddCurrentProgram": "true",
            "SortBy": "SortName"
        ]
        if let limit { query["Limit"] = "\(limit)" }

        return try await get(path: "/LiveTv/Channels", query: query)
    }

    func getLiveTVPrograms(channelIds: [String]? = nil, isAiring: Bool? = nil, isSports: Bool? = nil, limit: Int? = nil) async throws -> QueryResult<BaseItemDto> {
        guard let userId else { throw JellyfinError.noUserId }

        var query: [String: String] = [
            "UserId": userId,
            "Fields": "ImageTags,Overview,ChannelNumber,ChannelName",
            "EnableImageTypes": "Primary,Backdrop,Thumb"
        ]
        if let channelIds { query["ChannelIds"] = channelIds.joined(separator: ",") }
        if let isAiring { query["IsAiring"] = "\(isAiring)" }
        if let isSports { query["IsSports"] = "\(isSports)" }
        if let limit { query["Limit"] = "\(limit)" }

        return try await get(path: "/LiveTv/Programs", query: query)
    }

    func getLiveTVRecommended(limit: Int? = nil, isAiring: Bool? = nil, isSports: Bool? = nil) async throws -> QueryResult<BaseItemDto> {
        guard let userId else { throw JellyfinError.noUserId }

        var query: [String: String] = [
            "UserId": userId,
            "Fields": "ImageTags,Overview,ChannelNumber,ChannelName",
            "EnableImageTypes": "Primary,Backdrop,Thumb",
            "IsAiring": "\(isAiring ?? true)"
        ]
        if let isSports { query["IsSports"] = "\(isSports)" }
        if let limit { query["Limit"] = "\(limit)" }

        return try await get(path: "/LiveTv/Programs/Recommended", query: query)
    }

    // MARK: - Image URLs

    func imageURL(
        itemId: String,
        imageType: String = "Primary",
        maxWidth: Int? = nil,
        maxHeight: Int? = nil,
        quality: Int = 90,
        tag: String? = nil,
        index: Int? = nil
    ) -> URL? {
        guard let baseURL else { return nil }

        var path = "/Items/\(itemId)/Images/\(imageType)"
        if let index { path += "/\(index)" }

        var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )

        var queryItems = [URLQueryItem(name: "quality", value: "\(quality)")]
        if let maxWidth { queryItems.append(URLQueryItem(name: "maxWidth", value: "\(maxWidth)")) }
        if let maxHeight { queryItems.append(URLQueryItem(name: "maxHeight", value: "\(maxHeight)")) }
        if let tag { queryItems.append(URLQueryItem(name: "tag", value: tag)) }
        components?.queryItems = queryItems

        return components?.url
    }

    func personImageURL(name: String, tag: String? = nil) -> URL? {
        guard let baseURL else { return nil }
        guard let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            return nil
        }

        var components = URLComponents(
            url: baseURL.appendingPathComponent("/Persons/\(encoded)/Images/Primary"),
            resolvingAgainstBaseURL: false
        )

        var queryItems = [
            URLQueryItem(name: "maxWidth", value: "300"),
            URLQueryItem(name: "quality", value: "90")
        ]
        if let tag { queryItems.append(URLQueryItem(name: "tag", value: tag)) }
        components?.queryItems = queryItems

        return components?.url
    }

    func streamURL(itemId: String, mediaSourceId: String, startTicks: Int64? = nil) -> URL? {
        guard let baseURL else { return nil }

        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.path = "/Videos/\(itemId)/\(mediaSourceId)/master.m3u8"

        var queryItems = [
            URLQueryItem(name: "MediaSourceId", value: mediaSourceId),
            URLQueryItem(name: "VideoCodec", value: "h264,hevc"),
            URLQueryItem(name: "AudioCodec", value: "aac,ac3,eac3"),
            URLQueryItem(name: "MaxStreamingBitrate", value: "120000000"),
            URLQueryItem(name: "SubtitleMethod", value: "Encode"),
            URLQueryItem(name: "api_key", value: accessToken)
        ]

        if let startTicks {
            queryItems.append(URLQueryItem(name: "StartTimeTicks", value: "\(startTicks)"))
        }

        components?.queryItems = queryItems
        return components?.url
    }
}

// MARK: - Encodable Helpers

private extension JSONEncoder {
    func encodeAny(_ value: any Encodable) throws -> Data {
        try encode(EncodableWrapper(value))
    }
}

private struct EncodableWrapper: Encodable {
    private let value: any Encodable

    init(_ value: any Encodable) {
        self.value = value
    }

    func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
}
