# Aether — Jellyfin API Integration Plan

> **Target server:** Jellyfin 10.11.6 at `http://192.168.0.159:8096`
> **Client platform:** tvOS (Apple TV), Swift, async/await
> **Document scope:** Complete API reference for Aether v1 implementation

---

## Table of Contents

1. [API Client Architecture](#1-api-client-architecture)
2. [Complete Endpoint Map](#2-complete-endpoint-map)
3. [Swift Codable Models](#3-swift-codable-models)
4. [Pagination Strategy](#4-pagination-strategy)
5. [Caching Strategy](#5-caching-strategy)
6. [Request/Response Examples](#6-requestresponse-examples)

---

## 1. API Client Architecture

### 1.1 Singleton Service — `JellyfinAPI`

All network communication flows through a single `JellyfinAPI` actor. Using a Swift actor (rather than a plain class) gives us thread-safe mutable state for the token and device ID without manual locking.

```swift
actor JellyfinAPI {
    static let shared = JellyfinAPI()

    private var baseURL: URL
    private var accessToken: String?
    private var userId: String?
    private let deviceId: String
    private let session: URLSession

    private init() {
        // Load baseURL from UserDefaults (set during server setup flow)
        let saved = UserDefaults.standard.string(forKey: "jellyfinBaseURL")
            ?? "http://192.168.0.159:8096"
        self.baseURL = URL(string: saved)!

        // DeviceId: generate once, persist in Keychain
        self.deviceId = KeychainHelper.read(key: "deviceId")
            ?? {
                let id = UUID().uuidString
                KeychainHelper.save(key: "deviceId", value: id)
                return id
            }()

        // Restore token from Keychain if present
        self.accessToken = KeychainHelper.read(key: "accessToken")
        self.userId = KeychainHelper.read(key: "userId")

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }
}
```

### 1.2 Base URL Configuration

| Storage location | Key | Value |
|---|---|---|
| `UserDefaults` | `jellyfinBaseURL` | `http://192.168.0.159:8096` (or user-entered) |
| Keychain | `accessToken` | The JWT-style token returned by auth |
| Keychain | `userId` | User UUID from auth response |
| Keychain | `deviceId` | Persistent UUID generated on first launch |

The base URL is stored in `UserDefaults` because it is non-secret and needs to survive app reinstalls for a smoother reconnect experience. Tokens and IDs go in Keychain for security.

During the server setup flow, the app first calls `GET /System/Info/Public` to validate the URL before saving it.

### 1.3 Authorization Header

Every authenticated request must include this header:

```
Authorization: MediaBrowser Client="Aether", Device="AppleTV", DeviceId="{uuid}", Version="1.0", Token="{token}"
```

For unauthenticated requests (login, server discovery), the same header is sent **without** the `Token` segment:

```
Authorization: MediaBrowser Client="Aether", Device="AppleTV", DeviceId="{uuid}", Version="1.0"
```

Implementation:

```swift
extension JellyfinAPI {
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

    private func buildRequest(
        path: String,
        method: String = "GET",
        query: [String: String]? = nil,
        body: Encodable? = nil
    ) throws -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if let query {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.setValue(authorizationHeader(), forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body {
            request.httpBody = try JSONEncoder().encode(body)
        }
        return request
    }
}
```

### 1.4 Core Request Method

A generic `request` method handles decoding, error mapping, and automatic re-auth:

```swift
extension JellyfinAPI {
    func request<T: Decodable>(
        path: String,
        method: String = "GET",
        query: [String: String]? = nil,
        body: Encodable? = nil,
        retryOnUnauthorized: Bool = true
    ) async throws -> T {
        let urlRequest = try buildRequest(path: path, method: method, query: query, body: body)
        let (data, response) = try await session.data(for: urlRequest)

        guard let http = response as? HTTPURLResponse else {
            throw JellyfinError.invalidResponse
        }

        switch http.statusCode {
        case 200...299:
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)

        case 401:
            if retryOnUnauthorized {
                // Clear stale token and notify UI to re-authenticate
                self.accessToken = nil
                KeychainHelper.delete(key: "accessToken")
                throw JellyfinError.unauthorized
            }
            throw JellyfinError.unauthorized

        case 404:
            throw JellyfinError.notFound

        case 500...599:
            throw JellyfinError.serverError(statusCode: http.statusCode)

        default:
            throw JellyfinError.httpError(statusCode: http.statusCode, data: data)
        }
    }

    /// Fire-and-forget variant for reporting endpoints that return no body (204).
    func send(
        path: String,
        method: String = "POST",
        query: [String: String]? = nil,
        body: Encodable? = nil
    ) async throws {
        let urlRequest = try buildRequest(path: path, method: method, query: query, body: body)
        let (_, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            if let http = response as? HTTPURLResponse, http.statusCode == 401 {
                throw JellyfinError.unauthorized
            }
            throw JellyfinError.invalidResponse
        }
    }
}
```

### 1.5 Error Handling Strategy

```swift
enum JellyfinError: Error, LocalizedError {
    case invalidResponse
    case unauthorized                        // 401 — token expired or invalid
    case notFound                            // 404
    case serverError(statusCode: Int)        // 5xx
    case httpError(statusCode: Int, data: Data)
    case serverUnreachable                   // network timeout / no route
    case decodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .unauthorized:       return "Session expired. Please sign in again."
        case .serverUnreachable:  return "Cannot reach the Jellyfin server."
        case .notFound:           return "The requested item was not found."
        case .serverError(let c): return "Server error (\(c)). Try again later."
        default:                  return "An unexpected error occurred."
        }
    }
}
```

**Error handling rules:**

| Scenario | Behavior |
|---|---|
| **Network timeout / no connectivity** | Show a non-blocking banner "Cannot reach server". Retry automatically when network status changes (via `NWPathMonitor`). |
| **401 Unauthorized** | Clear stored token, present login screen. Do **not** retry silently — require explicit re-authentication. |
| **404 Not Found** | Surface gracefully in the UI ("Item not found"). Log for debugging. |
| **5xx Server Error** | Show transient error toast. Allow manual retry. |
| **JSON decode failure** | Log full response body at `.error` level. Show generic error to user. This likely means a model mismatch with the server version. |

### 1.6 Network Monitoring

Use `NWPathMonitor` to track connectivity. When the path becomes satisfied after being unsatisfied, trigger a lightweight refresh (re-fetch resume items, library views).

---

## 2. Complete Endpoint Map

### 2.1 Authentication

| Method | Path | Purpose | Auth Required |
|---|---|---|---|
| `GET` | `/System/Info/Public` | Server discovery and validation — returns server name, version, ID. Used to verify a URL is a valid Jellyfin server. | No |
| `POST` | `/Users/AuthenticateByName` | Log in with username + password. Returns access token and user object. | No (but needs `Authorization` header without `Token`) |
| `POST` | `/Sessions/Logout` | Invalidate the current session token on the server. | Yes |

**Auth flow:**
1. User enters server URL.
2. `GET /System/Info/Public` validates the server.
3. User enters username + password.
4. `POST /Users/AuthenticateByName` with body `{ "Username": "...", "Pw": "..." }`.
5. Store `AccessToken` and `User.Id` in Keychain.
6. All subsequent requests include the full `Authorization` header with token.

### 2.2 User & Libraries

| Method | Path | Purpose | Key Parameters |
|---|---|---|---|
| `GET` | `/Users/{userId}` | Fetch current user profile (display name, configuration, policy). | — |
| `GET` | `/Users/{userId}/Views` | List all media libraries visible to the user (Movies, Shows, Music, etc.). | — |

### 2.3 Browsing & Discovery

| Method | Path | Purpose | Key Parameters |
|---|---|---|---|
| `GET` | `/Items` | **Primary browsing endpoint.** List items with powerful filtering. Used for library contents, genre browsing, search, and filtered views. | `UserId`, `ParentId`, `IncludeItemTypes`, `SortBy`, `SortOrder`, `Limit`, `StartIndex`, `Genres`, `Years`, `SearchTerm`, `Filters`, `Recursive`, `Fields`, `ImageTypeLimit`, `EnableImageTypes` |
| `GET` | `/Items/{id}` | Single item full detail. Fetch when user opens a detail view. | `UserId`, `Fields` (request all needed fields) |
| `GET` | `/Items/{id}/Similar` | Items similar to the given item. Shown on detail pages. | `UserId`, `Limit`, `Fields` |
| `GET` | `/Items/Latest` | Recently added items for a library. | `UserId`, `ParentId`, `Limit`, `Fields`, `ImageTypeLimit`, `EnableImageTypes` |
| `GET` | `/Items/Resume` | Continue watching — items with partial playback progress. | `UserId`, `Limit`, `Fields`, `MediaTypes`, `ImageTypeLimit`, `EnableImageTypes` |
| `GET` | `/Shows/{seriesId}/Seasons` | List seasons for a TV series. | `UserId`, `Fields` |
| `GET` | `/Shows/{seriesId}/Episodes` | List episodes, optionally filtered to one season. | `UserId`, `SeasonId`, `Fields`, `StartIndex`, `Limit` |
| `GET` | `/Persons` | Browse cast/crew. Used for "People" sections and actor detail pages. | `UserId`, `Limit`, `Fields`, `SearchTerm` |
| `GET` | `/Genres` | List all genres available in a library. Used for filter UI. | `UserId`, `ParentId`, `IncludeItemTypes` |

**Common `Fields` value for browsing requests:**

```
Fields=Overview,Genres,People,Studios,CommunityRating,OfficialRating,MediaSources,
       RunTimeTicks,PremiereDate,ImageTags,BackdropImageTags,ParentId,SeriesId,
       SeasonId,UserData
```

Request only what you need per screen:
- **Grid/poster view:** `Fields=ImageTags,UserData,RunTimeTicks,CommunityRating,OfficialRating`
- **Detail view:** All fields above (the full set)

**Common `SortBy` values:**
- `SortName` — alphabetical
- `DateCreated` — date added
- `PremiereDate` — release date
- `CommunityRating` — rating descending
- `PlayCount` — most watched
- `Random` — shuffle

**Common `Filters` values:**
- `IsUnplayed` — unwatched only
- `IsPlayed` — watched only
- `IsFavorite` — favorites only
- `IsResumable` — has partial progress

### 2.4 Playback

| Method | Path | Purpose | Key Parameters / Body |
|---|---|---|---|
| `GET` | `/Items/{id}/PlaybackInfo` | **Must call before playback.** Returns available media sources, stream URLs, transcoding info, subtitle options. | `UserId`; POST variant accepts `DeviceProfile` for transcoding negotiation |
| `GET` | `/Videos/{itemId}/{mediaSourceId}/master.m3u8` | HLS stream URL. Passed to AVPlayer for actual playback. | `MediaSourceId`, `VideoCodec`, `AudioCodec`, `SubtitleStreamIndex`, `AudioStreamIndex`, `MaxStreamingBitrate`, `api_key={token}` |
| `POST` | `/Sessions/Playing` | Report playback started. Tells the server what is playing (shows in dashboard). | Body: `PlaybackStartInfo` JSON |
| `POST` | `/Sessions/Playing/Progress` | Report playback progress. **Send every 10 seconds.** Updates the server's playback position for resume. | Body: `PlaybackProgressInfo` JSON |
| `POST` | `/Sessions/Playing/Stopped` | Report playback stopped. Finalizes the position or marks as complete. | Body: `PlaybackStopInfo` JSON |
| `POST` | `/UserItems/{id}/Rating` | Toggle favorite status for an item. | `UserId`, Body: `{ "IsFavorite": true }` |
| `POST` | `/Users/{userId}/PlayedItems/{id}` | Mark item as watched. | — |
| `DELETE` | `/Users/{userId}/PlayedItems/{id}` | Mark item as unwatched. | — |

**HLS Stream URL Construction:**

```swift
func streamURL(itemId: String, mediaSourceId: String) -> URL {
    var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
    components.path = "/Videos/\(itemId)/\(mediaSourceId)/master.m3u8"
    components.queryItems = [
        URLQueryItem(name: "MediaSourceId", value: mediaSourceId),
        URLQueryItem(name: "VideoCodec", value: "h264,hevc"),
        URLQueryItem(name: "AudioCodec", value: "aac,ac3,eac3"),
        URLQueryItem(name: "MaxStreamingBitrate", value: "120000000"),
        URLQueryItem(name: "SubtitleMethod", value: "Encode"),
        URLQueryItem(name: "api_key", value: accessToken),
    ]
    return components.url!
}
```

> **Note:** The `api_key` query parameter is required for stream URLs because AVPlayer does not propagate custom headers on HLS segment requests. This is the standard Jellyfin approach for clients that cannot set headers on every sub-request.

**Playback reporting cadence:**

1. User taps Play -> `POST /Sessions/Playing` (once)
2. Every 10 seconds -> `POST /Sessions/Playing/Progress`
3. User pauses -> `POST /Sessions/Playing/Progress` with `IsPaused: true`
4. User resumes -> `POST /Sessions/Playing/Progress` with `IsPaused: false`
5. User stops or playback ends -> `POST /Sessions/Playing/Stopped`

### 2.5 Images

| Method | Path | Purpose | Key Parameters |
|---|---|---|---|
| `GET` | `/Items/{id}/Images/Primary` | Poster image | `maxWidth`, `maxHeight`, `quality`, `tag` |
| `GET` | `/Items/{id}/Images/Backdrop` | Fanart / background image | `maxWidth`, `maxHeight`, `quality`, `tag`, `imageIndex` |
| `GET` | `/Items/{id}/Images/Logo` | Transparent logo (for overlay on backdrop) | `maxWidth`, `quality`, `tag` |
| `GET` | `/Items/{id}/Images/Thumb` | Thumbnail (16:9 crop) | `maxWidth`, `quality`, `tag` |
| `GET` | `/Items/{id}/Images/Banner` | Wide banner (used for series) | `maxWidth`, `quality`, `tag` |
| `GET` | `/Persons/{name}/Images/Primary` | Actor/person headshot | `maxWidth`, `maxHeight`, `quality`, `tag` |

**Image URL helper:**

```swift
extension JellyfinAPI {
    func imageURL(
        itemId: String,
        type: ImageType,
        maxWidth: Int? = nil,
        maxHeight: Int? = nil,
        quality: Int = 90,
        tag: String? = nil,
        index: Int? = nil
    ) -> URL {
        var path = "/Items/\(itemId)/Images/\(type.rawValue)"
        if let index { path += "/\(index)" }

        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "quality", value: "\(quality)")
        ]
        if let maxWidth { queryItems.append(URLQueryItem(name: "maxWidth", value: "\(maxWidth)")) }
        if let maxHeight { queryItems.append(URLQueryItem(name: "maxHeight", value: "\(maxHeight)")) }
        if let tag { queryItems.append(URLQueryItem(name: "tag", value: tag)) }
        components.queryItems = queryItems
        return components.url!
    }

    func personImageURL(name: String, maxWidth: Int = 300, tag: String? = nil) -> URL {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!
        var components = URLComponents(url: baseURL.appendingPathComponent("/Persons/\(encoded)/Images/Primary"), resolvingAgainstBaseURL: false)!
        var queryItems = [URLQueryItem(name: "maxWidth", value: "\(maxWidth)"), URLQueryItem(name: "quality", value: "90")]
        if let tag { queryItems.append(URLQueryItem(name: "tag", value: tag)) }
        components.queryItems = queryItems
        return components.url!
    }

    enum ImageType: String {
        case primary = "Primary"
        case backdrop = "Backdrop"
        case logo = "Logo"
        case thumb = "Thumb"
        case banner = "Banner"
    }
}
```

**Recommended image sizes for Apple TV (1080p / 4K):**

| Image Type | Context | maxWidth | maxHeight |
|---|---|---|---|
| Primary (poster) | Grid cell | 400 | 600 |
| Primary (poster) | Detail page | 600 | 900 |
| Backdrop | Full-screen background | 1920 | — |
| Backdrop | 4K background | 3840 | — |
| Logo | Overlay on backdrop | 800 | — |
| Thumb | Episode thumbnail | 640 | 360 |
| Person | Cast headshot | 300 | 300 |

The `tag` parameter serves as a cache key. When the server-side image changes, the tag value changes, which busts the client cache. Always include it when available (sourced from `ImageTags` dict or `PrimaryImageTag` on the item).

### 2.6 Search

Search uses the same `/Items` endpoint with a `SearchTerm` parameter:

| Method | Path | Purpose | Key Parameters |
|---|---|---|---|
| `GET` | `/Items` | Unified search across all types | `SearchTerm`, `IncludeItemTypes=Movie,Series,Episode,Person`, `Recursive=true`, `Limit=24`, `Fields=...` |

**Implementation notes:**
- Debounce search input by 300ms before firing the request.
- Search as the user types (no explicit "submit" needed).
- Group results by item type in the UI (Movies, Series, Episodes, People).
- For person results, use the returned person's ID to fetch their filmography via `GET /Items` with `PersonIds={id}`.

---

## 3. Swift Codable Models

All models use `Codable` for JSON serialization. Properties are optional where the server may omit them depending on context or the `Fields` parameter.

### 3.1 Authentication Models

```swift
// POST /Users/AuthenticateByName — Request
struct AuthRequest: Codable {
    let Username: String
    let Pw: String
}

// POST /Users/AuthenticateByName — Response
struct AuthResponse: Codable {
    let User: UserDto
    let AccessToken: String
    let ServerId: String
}

// GET /System/Info/Public — Response
struct PublicServerInfo: Codable {
    let ServerName: String
    let Version: String
    let Id: String
    let LocalAddress: String?
    let OperatingSystem: String?
    let StartupWizardCompleted: Bool?
}
```

### 3.2 User Model

```swift
struct UserDto: Codable {
    let Name: String
    let Id: String
    let ServerId: String?
    let HasPassword: Bool?
    let PrimaryImageTag: String?
    let Configuration: UserConfiguration?
    let Policy: UserPolicy?
}

struct UserConfiguration: Codable {
    let PlayDefaultAudioTrack: Bool?
    let SubtitleLanguagePreference: String?
    let SubtitleMode: String?
}

struct UserPolicy: Codable {
    let IsAdministrator: Bool?
    let IsDisabled: Bool?
    let EnableAllFolders: Bool?
}
```

### 3.3 `BaseItemDto` — The Core Item Model

This is the largest model, representing movies, series, seasons, episodes, and other media. Most fields are optional because different item types populate different subsets.

```swift
struct BaseItemDto: Codable, Identifiable, Hashable {
    // Identity
    let Id: String
    let Name: String?
    let OriginalTitle: String?
    let ServerId: String?
    let Type: ItemType?

    // Metadata
    let Overview: String?
    let Taglines: [String]?
    let Genres: [String]?
    let Studios: [StudioInfo]?
    let People: [PersonInfo]?
    let CommunityRating: Double?
    let CriticRating: Double?
    let OfficialRating: String?       // e.g. "PG-13", "TV-MA"
    let PremiereDate: String?          // ISO 8601
    let ProductionYear: Int?
    let EndDate: String?

    // Duration & Progress
    let RunTimeTicks: Int64?           // 1 tick = 100 nanoseconds
    let UserData: UserData?

    // Series / Season / Episode
    let SeriesId: String?
    let SeriesName: String?
    let SeasonId: String?
    let SeasonName: String?
    let IndexNumber: Int?              // Episode number within season
    let ParentIndexNumber: Int?        // Season number

    // Media Info
    let MediaSources: [MediaSourceInfo]?
    let MediaType: String?             // "Video", "Audio"
    let Container: String?

    // Images
    let ImageTags: [String: String]?   // e.g. ["Primary": "abc123"]
    let BackdropImageTags: [String]?
    let ParentBackdropImageTags: [String]?
    let PrimaryImageAspectRatio: Double?

    // Hierarchy
    let ParentId: String?
    let CollectionType: String?        // "movies", "tvshows", etc.

    // Counts (for library/series/season)
    let ChildCount: Int?
    let RecursiveItemCount: Int?

    // Status
    let Status: String?                // e.g. "Ended", "Continuing"
    let AirDays: [String]?
    let AirTime: String?

    static func == (lhs: BaseItemDto, rhs: BaseItemDto) -> Bool {
        lhs.Id == rhs.Id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(Id)
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
    case unknown

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = ItemType(rawValue: value) ?? .unknown
    }
}

struct StudioInfo: Codable {
    let Name: String?
    let Id: String?
}
```

### 3.4 User Data

```swift
struct UserData: Codable {
    let PlaybackPositionTicks: Int64?
    let PlayCount: Int?
    let IsFavorite: Bool?
    let Played: Bool?
    let UnplayedItemCount: Int?
    let LastPlayedDate: String?
    let PlayedPercentage: Double?

    var progressPercent: Double {
        PlayedPercentage ?? 0
    }

    var resumePositionSeconds: Double {
        Double(PlaybackPositionTicks ?? 0) / 10_000_000.0
    }
}
```

### 3.5 Media Source & Stream Models

```swift
struct MediaSourceInfo: Codable {
    let Id: String?
    let Name: String?
    let Container: String?           // e.g. "mkv", "mp4"
    let Size: Int64?                 // File size in bytes
    let Bitrate: Int?                // Total bitrate
    let Path: String?
    let MediaStreams: [MediaStream]?
    let SupportsDirectPlay: Bool?
    let SupportsDirectStream: Bool?
    let SupportsTranscoding: Bool?
    let TranscodingUrl: String?
    let DefaultAudioStreamIndex: Int?
    let DefaultSubtitleStreamIndex: Int?

    /// Convenience: first video stream's resolution label
    var resolutionLabel: String? {
        guard let video = MediaStreams?.first(where: { $0.Type == .video }) else { return nil }
        guard let h = video.Height else { return nil }
        if h >= 2160 { return "4K" }
        if h >= 1080 { return "1080p" }
        if h >= 720 { return "720p" }
        return "\(h)p"
    }
}

struct MediaStream: Codable {
    let Type: MediaStreamType?
    let Codec: String?               // e.g. "hevc", "aac", "srt"
    let Language: String?            // ISO 639 code
    let DisplayTitle: String?        // Human-readable, e.g. "English - AAC Stereo"
    let Title: String?
    let IsDefault: Bool?
    let IsForced: Bool?
    let IsExternal: Bool?
    let Index: Int?

    // Video-specific
    let Width: Int?
    let Height: Int?
    let BitRate: Int?
    let VideoRange: String?          // "SDR", "HDR", "HDR10", "Dolby Vision"
    let VideoRangeType: String?

    // Audio-specific
    let Channels: Int?
    let ChannelLayout: String?       // e.g. "5.1", "7.1"
    let SampleRate: Int?

    // Subtitle-specific
    let DeliveryMethod: String?      // "External", "Embed", "Encode", "Hls"
    let DeliveryUrl: String?
}

enum MediaStreamType: String, Codable {
    case video = "Video"
    case audio = "Audio"
    case subtitle = "Subtitle"
    case embeddedImage = "EmbeddedImage"
}
```

### 3.6 Person Model

```swift
struct PersonInfo: Codable {
    let Name: String?
    let Id: String?
    let Role: String?                // e.g. "Tony Stark" (for actors)
    let Type: PersonType?
    let PrimaryImageTag: String?
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
```

### 3.7 Library View

```swift
struct LibraryView: Codable, Identifiable {
    let Id: String
    let Name: String?
    let CollectionType: String?      // "movies", "tvshows", "music", "books"
    let ImageTags: [String: String]?
}
```

### 3.8 Playback Reporting Models

```swift
struct PlaybackStartInfo: Codable {
    let ItemId: String
    let MediaSourceId: String?
    let AudioStreamIndex: Int?
    let SubtitleStreamIndex: Int?
    let PlayMethod: String?          // "DirectPlay", "DirectStream", "Transcode"
    let PlaySessionId: String?
    let CanSeek: Bool
    let IsPaused: Bool
    let PositionTicks: Int64?
}

struct PlaybackProgressInfo: Codable {
    let ItemId: String
    let MediaSourceId: String?
    let AudioStreamIndex: Int?
    let SubtitleStreamIndex: Int?
    let PositionTicks: Int64?
    let IsPaused: Bool
    let IsMuted: Bool?
    let PlayMethod: String?
    let PlaySessionId: String?
    let CanSeek: Bool
    let VolumeLevel: Int?
}

struct PlaybackStopInfo: Codable {
    let ItemId: String
    let MediaSourceId: String?
    let PositionTicks: Int64?
    let PlaySessionId: String?
}
```

### 3.9 Generic Query Result

Used for all paginated list responses:

```swift
struct QueryResult<T: Codable>: Codable {
    let Items: [T]
    let TotalRecordCount: Int
    let StartIndex: Int?
}
```

### 3.10 Time Conversion Helpers

Jellyfin uses "ticks" (1 tick = 100 nanoseconds = 0.0000001 seconds). This comes up constantly.

```swift
extension Int64 {
    /// Convert Jellyfin ticks to seconds.
    var ticksToSeconds: Double {
        Double(self) / 10_000_000.0
    }

    /// Convert Jellyfin ticks to a formatted duration string like "1h 42m".
    var ticksToDuration: String {
        let totalSeconds = Int(ticksToSeconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

extension Double {
    /// Convert seconds to Jellyfin ticks.
    var secondsToTicks: Int64 {
        Int64(self * 10_000_000.0)
    }
}
```

---

## 4. Pagination Strategy

### 4.1 Core Parameters

All list endpoints support pagination via:

| Parameter | Type | Default | Description |
|---|---|---|---|
| `StartIndex` | Int | 0 | Zero-based offset of the first item to return |
| `Limit` | Int | 50 | Maximum number of items per page |

The response includes `TotalRecordCount` so the client knows how many items exist in total.

### 4.2 Default Page Sizes

| Context | Page Size | Rationale |
|---|---|---|
| Library grid | 50 | Enough to fill several screens of posters |
| Continue watching | 20 | Typically a short list |
| Latest additions | 16 | One or two rows |
| Search results | 24 | Fast response for as-you-type |
| Episodes list | 100 | Most seasons fit in one page |
| Similar items | 12 | One row of recommendations |

### 4.3 Infinite Scroll Implementation

```swift
class PaginatedLoader<T: Codable>: ObservableObject {
    @Published var items: [T] = []
    @Published var isLoading = false
    @Published var hasMore = true

    private var startIndex = 0
    private let pageSize: Int
    private let fetchPage: (Int, Int) async throws -> QueryResult<T>

    init(pageSize: Int = 50, fetchPage: @escaping (Int, Int) async throws -> QueryResult<T>) {
        self.pageSize = pageSize
        self.fetchPage = fetchPage
    }

    func loadNextPage() async {
        guard !isLoading, hasMore else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await fetchPage(startIndex, pageSize)
            items.append(contentsOf: result.Items)
            startIndex += result.Items.count
            hasMore = startIndex < result.TotalRecordCount
        } catch {
            // Handle error — do not advance startIndex so retry is possible
        }
    }

    /// Call this from item's onAppear to trigger pre-fetching.
    func loadMoreIfNeeded(currentItem: T) where T: Identifiable {
        let thresholdIndex = items.index(items.endIndex, offsetBy: -Int(Double(pageSize) * 0.2))
        if let idx = items.firstIndex(where: { ($0 as! any Identifiable).id as? String == (currentItem as! any Identifiable).id as? String }),
           idx >= thresholdIndex {
            Task { await loadNextPage() }
        }
    }

    func reset() {
        items = []
        startIndex = 0
        hasMore = true
    }
}
```

### 4.4 Pre-fetch Trigger

When the user scrolls to approximately **80% of currently loaded items**, start fetching the next page. This ensures new data is ready before the user reaches the end, preventing visible loading gaps.

On Apple TV, where focus-based navigation makes scroll position predictable, the 80% threshold can be computed as:

```
thresholdIndex = items.count - (pageSize * 0.2)
```

When the focused item's index crosses this threshold, fire the next page load.

---

## 5. Caching Strategy

### 5.1 Image Caching — Nuke

Use **Nuke** (preferred over Kingfisher for its SwiftUI integration and pipeline architecture).

```swift
// Configure once at app startup
import Nuke
import NukeUI

let pipeline = ImagePipeline {
    $0.dataCache = try? DataCache(name: "com.aether.images")  // Disk cache
    $0.dataCachePolicy = .automatic
    $0.imageCache = ImageCache.shared                         // Memory cache

    // Disk cache: 500 MB limit (Apple TV has ample storage)
    if let dataCache = $0.dataCache as? DataCache {
        dataCache.sizeLimit = 500 * 1024 * 1024
    }

    // Memory cache: 200 MB
    ImageCache.shared.costLimit = 200 * 1024 * 1024
    ImageCache.shared.countLimit = 500
}

ImagePipeline.shared = pipeline
```

In SwiftUI views, use `LazyImage` from NukeUI:

```swift
LazyImage(url: JellyfinAPI.shared.imageURL(
    itemId: item.Id,
    type: .primary,
    maxWidth: 400,
    tag: item.ImageTags?["Primary"]
)) { state in
    if let image = state.image {
        image.resizable().aspectRatio(contentMode: .fill)
    } else {
        Color.gray.opacity(0.3) // Placeholder
    }
}
```

**Cache busting:** The `tag` query parameter is a hash of the server-side image. When the image changes on the server, the tag changes, producing a new URL, which naturally busts the cache. If no tag is available (deleted image), the URL still works but caching cannot be validated — treat these as non-cacheable.

### 5.2 Data Caching Tiers

| Data Type | Cache Location | TTL / Invalidation | Rationale |
|---|---|---|---|
| Library list (`/Views`) | In-memory | Refresh on app foreground | Libraries rarely change mid-session |
| Library contents (`/Items`) | In-memory (per view) | Refresh on pull-to-refresh or app foreground | Users expect to see new additions when reopening the app |
| Item detail (`/Items/{id}`) | In-memory LRU | 10 minutes or until navigated away | Avoid re-fetching when going back to a detail page |
| Resume items (`/Items/Resume`) | **Never cached** | Always fetch fresh | Must reflect latest playback position |
| Playback info (`/PlaybackInfo`) | **Never cached** | Always fetch fresh | Stream URLs and transcoding decisions are session-specific |
| Search results | **Never cached** | — | Each keystroke produces a new query |
| User profile | In-memory | Refresh on app foreground | Rarely changes |

### 5.3 Implementation — In-Memory Cache

```swift
actor DataCache {
    static let shared = DataCache()

    private var store: [String: CacheEntry] = [:]
    private let defaultTTL: TimeInterval = 600  // 10 minutes

    struct CacheEntry {
        let data: Any
        let expiry: Date
    }

    func get<T>(key: String) -> T? {
        guard let entry = store[key],
              entry.expiry > Date() else {
            store.removeValue(forKey: key)
            return nil
        }
        return entry.data as? T
    }

    func set(key: String, value: Any, ttl: TimeInterval? = nil) {
        store[key] = CacheEntry(
            data: value,
            expiry: Date().addingTimeInterval(ttl ?? defaultTTL)
        )
    }

    func invalidate(key: String) {
        store.removeValue(forKey: key)
    }

    func invalidateAll() {
        store.removeAll()
    }
}
```

### 5.4 Foreground Refresh

When the app returns to the foreground (via `scenePhase` or `NotificationCenter`):

1. Refresh resume items (continue watching row).
2. Refresh library views (in case libraries were added/removed).
3. **Do not** clear the image cache — it is still valid.
4. If the token is expired (401 on any refresh call), route to login.

---

## 6. Request/Response Examples

### 6.1 Authentication

**Request:**

```http
POST /Users/AuthenticateByName HTTP/1.1
Host: 192.168.0.159:8096
Authorization: MediaBrowser Client="Aether", Device="AppleTV", DeviceId="A1B2C3D4-E5F6-7890-ABCD-EF1234567890", Version="1.0"
Content-Type: application/json

{
    "Username": "noah",
    "Pw": "password123"
}
```

**Response (200 OK):**

```json
{
    "User": {
        "Name": "noah",
        "ServerId": "8f7d3b2a1c4e5f60",
        "Id": "d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9",
        "HasPassword": true,
        "PrimaryImageTag": "abc123def456",
        "Configuration": {
            "PlayDefaultAudioTrack": true,
            "SubtitleLanguagePreference": "eng",
            "SubtitleMode": "Default"
        },
        "Policy": {
            "IsAdministrator": true,
            "IsDisabled": false,
            "EnableAllFolders": true
        }
    },
    "AccessToken": "e8a7b6c5d4e3f2a1b0c9d8e7f6a5b4c3d2e1f0a9b8c7d6e5f4a3b2c1d0e9f8",
    "ServerId": "8f7d3b2a1c4e5f60"
}
```

### 6.2 List Items (Library Browse)

**Request:**

```http
GET /Items?UserId=d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9&ParentId=abc123&IncludeItemTypes=Movie&SortBy=SortName&SortOrder=Ascending&Limit=3&StartIndex=0&Recursive=true&Fields=Overview,CommunityRating,OfficialRating,RunTimeTicks,PremiereDate,ImageTags,BackdropImageTags,UserData,Genres HTTP/1.1
Host: 192.168.0.159:8096
Authorization: MediaBrowser Client="Aether", Device="AppleTV", DeviceId="A1B2C3D4-...", Version="1.0", Token="e8a7b6c5d4e3f2..."
```

**Response (200 OK):**

```json
{
    "Items": [
        {
            "Name": "Blade Runner 2049",
            "ServerId": "8f7d3b2a1c4e5f60",
            "Id": "f1a2b3c4d5e6f7a8",
            "Type": "Movie",
            "Overview": "Thirty years after the events of the first film, a new blade runner, LAPD Officer K, unearths a long-buried secret that has the potential to plunge what's left of society into chaos.",
            "ProductionYear": 2017,
            "PremiereDate": "2017-10-03T00:00:00.0000000Z",
            "CommunityRating": 7.5,
            "OfficialRating": "R",
            "RunTimeTicks": 98820000000,
            "Genres": ["Science Fiction", "Drama"],
            "ImageTags": {
                "Primary": "tag_abc123"
            },
            "BackdropImageTags": ["tag_def456"],
            "PrimaryImageAspectRatio": 0.6666666666666666,
            "UserData": {
                "PlaybackPositionTicks": 36000000000,
                "PlayCount": 0,
                "IsFavorite": false,
                "Played": false,
                "PlayedPercentage": 36.43
            }
        },
        {
            "Name": "Dune: Part Two",
            "ServerId": "8f7d3b2a1c4e5f60",
            "Id": "a9b8c7d6e5f4a3b2",
            "Type": "Movie",
            "Overview": "Follow the mythic journey of Paul Atreides as he unites with Chani and the Fremen while on a path of revenge against the conspirators who destroyed his family.",
            "ProductionYear": 2024,
            "PremiereDate": "2024-02-27T00:00:00.0000000Z",
            "CommunityRating": 8.3,
            "OfficialRating": "PG-13",
            "RunTimeTicks": 99960000000,
            "Genres": ["Science Fiction", "Adventure"],
            "ImageTags": {
                "Primary": "tag_ghi789"
            },
            "BackdropImageTags": ["tag_jkl012"],
            "PrimaryImageAspectRatio": 0.6666666666666666,
            "UserData": {
                "PlaybackPositionTicks": 0,
                "PlayCount": 2,
                "IsFavorite": true,
                "Played": true,
                "PlayedPercentage": null
            }
        },
        {
            "Name": "Interstellar",
            "ServerId": "8f7d3b2a1c4e5f60",
            "Id": "c1d2e3f4a5b6c7d8",
            "Type": "Movie",
            "Overview": "The adventures of a group of explorers who make use of a newly discovered wormhole to surpass the limitations on human space travel and conquer the vast distances involved in an interstellar voyage.",
            "ProductionYear": 2014,
            "PremiereDate": "2014-11-05T00:00:00.0000000Z",
            "CommunityRating": 8.4,
            "OfficialRating": "PG-13",
            "RunTimeTicks": 101640000000,
            "Genres": ["Adventure", "Drama", "Science Fiction"],
            "ImageTags": {
                "Primary": "tag_mno345"
            },
            "BackdropImageTags": ["tag_pqr678", "tag_stu901"],
            "PrimaryImageAspectRatio": 0.6666666666666666,
            "UserData": {
                "PlaybackPositionTicks": 0,
                "PlayCount": 5,
                "IsFavorite": true,
                "Played": true,
                "PlayedPercentage": null
            }
        }
    ],
    "TotalRecordCount": 247,
    "StartIndex": 0
}
```

### 6.3 Single Item Detail

**Request:**

```http
GET /Users/d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9/Items/f1a2b3c4d5e6f7a8?Fields=Overview,Genres,People,Studios,CommunityRating,OfficialRating,MediaSources,RunTimeTicks,PremiereDate,ImageTags,BackdropImageTags,UserData HTTP/1.1
Host: 192.168.0.159:8096
Authorization: MediaBrowser Client="Aether", Device="AppleTV", DeviceId="...", Version="1.0", Token="..."
```

**Response (200 OK):**

```json
{
    "Name": "Blade Runner 2049",
    "Id": "f1a2b3c4d5e6f7a8",
    "Type": "Movie",
    "Overview": "Thirty years after the events of the first film...",
    "ProductionYear": 2017,
    "PremiereDate": "2017-10-03T00:00:00.0000000Z",
    "CommunityRating": 7.5,
    "OfficialRating": "R",
    "RunTimeTicks": 98820000000,
    "Taglines": ["The key to the future is finally unearthed."],
    "Genres": ["Science Fiction", "Drama"],
    "Studios": [
        { "Name": "Warner Bros. Pictures", "Id": "studio001" },
        { "Name": "Alcon Entertainment", "Id": "studio002" }
    ],
    "People": [
        {
            "Name": "Ryan Gosling",
            "Id": "person001",
            "Role": "K",
            "Type": "Actor",
            "PrimaryImageTag": "person_tag_001"
        },
        {
            "Name": "Harrison Ford",
            "Id": "person002",
            "Role": "Rick Deckard",
            "Type": "Actor",
            "PrimaryImageTag": "person_tag_002"
        },
        {
            "Name": "Denis Villeneuve",
            "Id": "person003",
            "Role": null,
            "Type": "Director",
            "PrimaryImageTag": "person_tag_003"
        }
    ],
    "MediaSources": [
        {
            "Id": "f1a2b3c4d5e6f7a8",
            "Name": "Blade Runner 2049 (2017) - 2160p Remux",
            "Container": "mkv",
            "Size": 76543210000,
            "Bitrate": 80000000,
            "SupportsDirectPlay": true,
            "SupportsDirectStream": true,
            "SupportsTranscoding": true,
            "DefaultAudioStreamIndex": 1,
            "DefaultSubtitleStreamIndex": null,
            "MediaStreams": [
                {
                    "Type": "Video",
                    "Codec": "hevc",
                    "Width": 3840,
                    "Height": 2160,
                    "BitRate": 60000000,
                    "VideoRange": "HDR10",
                    "IsDefault": true,
                    "Index": 0
                },
                {
                    "Type": "Audio",
                    "Codec": "truehd",
                    "Language": "eng",
                    "DisplayTitle": "English - Dolby TrueHD Atmos 7.1",
                    "Channels": 8,
                    "ChannelLayout": "7.1",
                    "IsDefault": true,
                    "Index": 1
                },
                {
                    "Type": "Audio",
                    "Codec": "ac3",
                    "Language": "eng",
                    "DisplayTitle": "English - AC3 5.1 (Compatibility)",
                    "Channels": 6,
                    "ChannelLayout": "5.1",
                    "IsDefault": false,
                    "Index": 2
                },
                {
                    "Type": "Subtitle",
                    "Codec": "srt",
                    "Language": "eng",
                    "DisplayTitle": "English (SRT)",
                    "IsDefault": false,
                    "IsForced": false,
                    "IsExternal": true,
                    "Index": 3,
                    "DeliveryMethod": "External"
                }
            ]
        }
    ],
    "ImageTags": {
        "Primary": "tag_abc123",
        "Logo": "tag_xyz789"
    },
    "BackdropImageTags": ["tag_def456", "tag_ghi012"],
    "UserData": {
        "PlaybackPositionTicks": 36000000000,
        "PlayCount": 0,
        "IsFavorite": false,
        "Played": false,
        "PlayedPercentage": 36.43,
        "LastPlayedDate": "2026-03-20T02:15:00.0000000Z"
    }
}
```

### 6.4 Playback Info

**Request:**

```http
GET /Items/f1a2b3c4d5e6f7a8/PlaybackInfo?UserId=d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9 HTTP/1.1
Host: 192.168.0.159:8096
Authorization: MediaBrowser Client="Aether", Device="AppleTV", DeviceId="...", Version="1.0", Token="..."
```

**Response (200 OK):**

```json
{
    "MediaSources": [
        {
            "Id": "f1a2b3c4d5e6f7a8",
            "Name": "Blade Runner 2049 (2017) - 2160p Remux",
            "Container": "mkv",
            "Size": 76543210000,
            "Bitrate": 80000000,
            "SupportsDirectPlay": true,
            "SupportsDirectStream": true,
            "SupportsTranscoding": true,
            "TranscodingUrl": "/Videos/f1a2b3c4d5e6f7a8/master.m3u8?MediaSourceId=f1a2b3c4d5e6f7a8&VideoCodec=h264&AudioCodec=aac&MaxStreamingBitrate=40000000",
            "DefaultAudioStreamIndex": 1,
            "DefaultSubtitleStreamIndex": null,
            "MediaStreams": [
                {
                    "Type": "Video",
                    "Codec": "hevc",
                    "Width": 3840,
                    "Height": 2160,
                    "BitRate": 60000000,
                    "VideoRange": "HDR10",
                    "IsDefault": true,
                    "Index": 0
                },
                {
                    "Type": "Audio",
                    "Codec": "truehd",
                    "Language": "eng",
                    "DisplayTitle": "English - Dolby TrueHD Atmos 7.1",
                    "Channels": 8,
                    "ChannelLayout": "7.1",
                    "IsDefault": true,
                    "Index": 1
                },
                {
                    "Type": "Subtitle",
                    "Codec": "srt",
                    "Language": "eng",
                    "DisplayTitle": "English (SRT)",
                    "IsDefault": false,
                    "IsForced": false,
                    "Index": 3,
                    "DeliveryMethod": "External",
                    "DeliveryUrl": "/Videos/f1a2b3c4d5e6f7a8/Subtitles/3/0/Stream.srt"
                }
            ]
        }
    ],
    "PlaySessionId": "sess_abc123def456"
}
```

### 6.5 Playback Reporting — Start

**Request:**

```http
POST /Sessions/Playing HTTP/1.1
Host: 192.168.0.159:8096
Authorization: MediaBrowser Client="Aether", Device="AppleTV", DeviceId="...", Version="1.0", Token="..."
Content-Type: application/json

{
    "ItemId": "f1a2b3c4d5e6f7a8",
    "MediaSourceId": "f1a2b3c4d5e6f7a8",
    "AudioStreamIndex": 1,
    "SubtitleStreamIndex": null,
    "PlayMethod": "DirectStream",
    "PlaySessionId": "sess_abc123def456",
    "CanSeek": true,
    "IsPaused": false,
    "PositionTicks": 36000000000
}
```

**Response:** `204 No Content`

### 6.6 Playback Reporting — Progress

**Request (sent every 10 seconds):**

```http
POST /Sessions/Playing/Progress HTTP/1.1
Host: 192.168.0.159:8096
Authorization: MediaBrowser Client="Aether", Device="AppleTV", DeviceId="...", Version="1.0", Token="..."
Content-Type: application/json

{
    "ItemId": "f1a2b3c4d5e6f7a8",
    "MediaSourceId": "f1a2b3c4d5e6f7a8",
    "AudioStreamIndex": 1,
    "SubtitleStreamIndex": null,
    "PositionTicks": 37200000000,
    "IsPaused": false,
    "IsMuted": false,
    "PlayMethod": "DirectStream",
    "PlaySessionId": "sess_abc123def456",
    "CanSeek": true
}
```

**Response:** `204 No Content`

### 6.7 Playback Reporting — Stopped

**Request:**

```http
POST /Sessions/Playing/Stopped HTTP/1.1
Host: 192.168.0.159:8096
Authorization: MediaBrowser Client="Aether", Device="AppleTV", DeviceId="...", Version="1.0", Token="..."
Content-Type: application/json

{
    "ItemId": "f1a2b3c4d5e6f7a8",
    "MediaSourceId": "f1a2b3c4d5e6f7a8",
    "PositionTicks": 42000000000,
    "PlaySessionId": "sess_abc123def456"
}
```

**Response:** `204 No Content`

### 6.8 Server Discovery

**Request:**

```http
GET /System/Info/Public HTTP/1.1
Host: 192.168.0.159:8096
```

**Response (200 OK):**

```json
{
    "LocalAddress": "http://192.168.0.159:8096",
    "ServerName": "NAS",
    "Version": "10.11.6",
    "Id": "8f7d3b2a1c4e5f60",
    "OperatingSystem": "Linux",
    "StartupWizardCompleted": true
}
```

### 6.9 Library Views

**Request:**

```http
GET /Users/d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9/Views HTTP/1.1
Host: 192.168.0.159:8096
Authorization: MediaBrowser Client="Aether", Device="AppleTV", DeviceId="...", Version="1.0", Token="..."
```

**Response (200 OK):**

```json
{
    "Items": [
        {
            "Name": "Movies",
            "Id": "lib_movies_001",
            "CollectionType": "movies",
            "ImageTags": {
                "Primary": "lib_tag_001"
            }
        },
        {
            "Name": "TV Shows",
            "Id": "lib_tvshows_001",
            "CollectionType": "tvshows",
            "ImageTags": {
                "Primary": "lib_tag_002"
            }
        },
        {
            "Name": "Anime",
            "Id": "lib_anime_001",
            "CollectionType": "tvshows",
            "ImageTags": {
                "Primary": "lib_tag_003"
            }
        }
    ],
    "TotalRecordCount": 3,
    "StartIndex": 0
}
```

---

## Appendix A: Full Endpoint Quick Reference

A flat list for fast lookup during implementation.

```
AUTH
  POST   /Users/AuthenticateByName
  GET    /System/Info/Public
  POST   /Sessions/Logout

USER
  GET    /Users/{userId}
  GET    /Users/{userId}/Views

BROWSE
  GET    /Items
  GET    /Items/{id}
  GET    /Items/{id}/Similar
  GET    /Items/Latest
  GET    /Items/Resume
  GET    /Shows/{seriesId}/Seasons
  GET    /Shows/{seriesId}/Episodes
  GET    /Persons
  GET    /Genres

PLAYBACK
  GET    /Items/{id}/PlaybackInfo
  GET    /Videos/{itemId}/{mediaSourceId}/master.m3u8
  POST   /Sessions/Playing
  POST   /Sessions/Playing/Progress
  POST   /Sessions/Playing/Stopped
  POST   /Users/{userId}/PlayedItems/{id}
  DELETE /Users/{userId}/PlayedItems/{id}

IMAGES
  GET    /Items/{id}/Images/{type}
  GET    /Persons/{name}/Images/Primary

FAVORITES
  POST   /UserItems/{id}/Rating
```

## Appendix B: tvOS / AVPlayer Considerations

1. **HLS is mandatory.** Apple TV's AVPlayer only supports HLS for streaming. Jellyfin's `/master.m3u8` endpoint handles this, transcoding if the source format is not natively HLS-compatible.

2. **Direct play vs. transcode.** Check `MediaSourceInfo.SupportsDirectPlay`. If the container is natively supported (MP4/MOV with H.264/HEVC + AAC), prefer direct stream to reduce server load. If the container is MKV, Jellyfin will remux to HLS (fast, no quality loss). If the codec is unsupported (e.g., AV1), the server transcodes.

3. **HDR.** Apple TV 4K supports HDR10 and Dolby Vision. Check `MediaStream.VideoRange` and pass the appropriate codec parameters. Do not request H.264 transcoding for HDR content — it will lose HDR metadata. If the source is HDR and direct play is supported, always prefer it.

4. **Audio passthrough.** Apple TV supports Dolby Atmos (TrueHD and E-AC3 with Atmos). For surround sound, set the audio stream index to the highest-quality compatible track. If the user's audio system does not support TrueHD, fall back to E-AC3 or AAC stereo.

5. **Subtitles.** External subtitles (SRT, ASS) can be loaded alongside AVPlayer via `AVMediaSelectionGroup` or rendered as a custom overlay. Embedded subtitles in MKV containers are extracted by Jellyfin and served at `/Videos/{id}/Subtitles/{index}/0/Stream.{format}`.

6. **Background playback.** When the app moves to the background during playback, send a progress report immediately and continue sending reports if audio playback continues.

7. **Token on stream URL.** AVPlayer does not forward custom HTTP headers to HLS segment requests. Always pass the token via the `api_key` query parameter on the `.m3u8` URL. This is secure on a local network; for remote access over HTTPS, it remains acceptable.
