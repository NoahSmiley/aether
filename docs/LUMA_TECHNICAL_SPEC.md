# Luma Technical Specification

> Cross-platform media streaming client for Jellyfin and IPTV (Xtream Codes).
> Reference implementation: tvOS (Swift/SwiftUI). Target ports: Windows, Android TV.

---

## 1. App Overview

Luma is a media streaming client that aggregates two independent data sources into a unified home-screen experience:

1. **Jellyfin** -- a self-hosted media server providing on-demand movies, TV shows, and associated metadata (posters, backdrops, playback progress, etc.). Communication is over a standard REST API on the local network.
2. **IPTV via Xtream Codes** -- a remote IPTV service exposing live TV channels, categories, and EPG (Electronic Program Guide) data through the Xtream Codes API. Streams are delivered as HLS over the public internet.

These two sources are completely independent. They share no auth, no data models, and no network layer. The app loads data from both concurrently and merges the results into a single UI. Jellyfin powers the on-demand library (movies, TV shows, continue watching, next up), while Xtream powers the live TV experience (curated sports channels with EPG metadata).

### Tab Structure

The app presents six top-level tabs (sidebar-adaptable on tvOS):

| Tab | Content Source | Description |
|-----|---------------|-------------|
| Search | Jellyfin | Full-text search across movies, series, episodes, people |
| Home | Jellyfin + IPTV | Combined dashboard with continue watching, next up, live TV highlights, recently added, library rows |
| Movies | Jellyfin | Grid browse of all movies with sort/filter |
| TV Shows | Jellyfin | Grid browse of all series with sort/filter |
| Live TV | IPTV (Xtream) | Curated live sports channels organized by section |
| Settings | Local | Server config, IPTV credentials, app preferences |

---

## 2. Authentication Flow

### 2.1 Jellyfin Authentication

The Jellyfin auth flow is a three-step process:

#### Step 1: Server Discovery
- User enters a server URL (e.g., `http://192.168.1.100:8096`).
- The URL is normalized: protocol prefix added if missing, trailing slash stripped.
- A GET request is made to `/System/Info/Public` to validate the server.
- Response is decoded into `PublicServerInfo` (server name, version, ID, OS).
- On success, the server URL is persisted to storage.

#### Step 2: Username/Password Login
- POST to `/Users/AuthenticateByName` with body:
  ```json
  {
    "Username": "username",
    "Pw": "password"
  }
  ```
- Response (`AuthResponse`) contains:
  - `AccessToken` -- the session token for all subsequent requests
  - `User` -- a `UserDto` with user ID, name, and policy info
  - `ServerId` -- the Jellyfin server's unique ID
- Both `AccessToken` and `UserId` are persisted to storage.

#### Step 3: Session Restore
- On app launch, the app checks for stored `serverURL`, `accessToken`, and `userId`.
- If all three exist, it configures the API client and validates the token by fetching `/Users/{userId}`.
- If the token is expired or invalid, credentials are cleared and the user is sent back to login.

#### Auth Header Format
Every Jellyfin request includes an `Authorization` header (note: NOT `X-Emby-Authorization`, despite the Emby heritage -- this app sends it as `Authorization`):

```
MediaBrowser Client="Luma", Device="AppleTV", DeviceId="{uuid}", Version="1.0", Token="{accessToken}"
```

The `Token` field is omitted for unauthenticated requests (server validation, login).

#### Credential Storage
All Jellyfin credentials use a `KeychainHelper` abstraction with the key prefix `me.athion.luma.`:

| Key | Value | Purpose |
|-----|-------|---------|
| `me.athion.luma.serverURL` | `http://192.168.1.100:8096` | Jellyfin server base URL |
| `me.athion.luma.accessToken` | JWT/session token | Auth token for API calls |
| `me.athion.luma.userId` | UUID string | Jellyfin user ID |
| `me.athion.luma.deviceId` | UUID string | Stable device identifier (generated once, persisted forever) |

> **Implementation note**: The current tvOS implementation stores these in `UserDefaults` (not the actual iOS Keychain) via `KeychainHelper`. A Windows port should use an equivalent secure-storage mechanism (Windows Credential Manager, DPAPI, or similar).

### 2.2 IPTV / Xtream Authentication

IPTV auth is stateless. There is no login flow -- credentials are stored directly:

| UserDefaults Key | Purpose |
|-----------------|---------|
| `xtreamBaseURL` | IPTV provider base URL |
| `xtreamUsername` | Xtream account username |
| `xtreamPassword` | Xtream account password |

Credentials are embedded in every API request as query parameters. There is no token exchange, no session, and no expiry. If the credentials are wrong, the server returns an HTTP error.

---

## 3. Jellyfin Integration

### 3.1 API Client Architecture

The Jellyfin API client (`JellyfinAPI`) is implemented as a Swift `actor` (thread-safe singleton). Key design:

- **Singleton**: `JellyfinAPI.shared`
- **URLSession config**: 15-second request timeout, 300-second resource timeout
- **JSON decoding**: ISO 8601 date strategy
- **Error handling**: Maps HTTP status codes to typed errors (`JellyfinError`)
  - 401 -> `.unauthorized`
  - Other 4xx/5xx -> `.httpError(statusCode:)`
  - Network failure -> `.serverUnreachable`
  - JSON parse failure -> `.decodingError(error)`

### 3.2 Key Endpoints

#### Library & Browse

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/Users/{userId}/Views` | Get all library views (Movies, TV Shows, Music, etc.) |
| GET | `/Items` | Query items with filters, sort, pagination |
| GET | `/Users/{userId}/Items/{itemId}` | Get single item with full metadata |
| GET | `/Items/Latest` | Get recently added items (optionally filtered by library) |
| GET | `/Items/Resume` | Get items with unfinished playback (continue watching) |
| GET | `/Shows/NextUp` | Get next unwatched episodes for in-progress series |

#### TV Show Hierarchy

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/Shows/{seriesId}/Seasons` | Get all seasons for a series |
| GET | `/Shows/{seriesId}/Episodes` | Get episodes for a specific season (filtered by `SeasonId` query param) |

#### Discovery

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/Items/{itemId}/Similar` | Get similar/recommended items |
| GET | `/Items` (with `SearchTerm`) | Full-text search (types: Movie, Series, Episode, Person) |

#### Playback Reporting

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/Sessions/Playing` | Report playback started |
| POST | `/Sessions/Playing/Progress` | Report playback progress (periodic, every ~10 seconds) |
| POST | `/Sessions/Playing/Stopped` | Report playback stopped |

Playback reporting bodies include: `ItemId`, `MediaSourceId`, `PositionTicks`, `IsPaused`, `CanSeek`, `PlayMethod`, `PlaySessionId`.

Ticks are Jellyfin's time unit: **1 tick = 100 nanoseconds** (10,000,000 ticks = 1 second).

#### User Actions

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/Users/{userId}/PlayedItems/{itemId}` | Mark item as played |
| DELETE | `/Users/{userId}/PlayedItems/{itemId}` | Mark item as unplayed |
| POST | `/Users/{userId}/FavoriteItems/{itemId}` | Add to favorites |
| DELETE | `/Users/{userId}/FavoriteItems/{itemId}` | Remove from favorites |

#### Live TV (Jellyfin native -- currently unused for IPTV)

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/LiveTv/Channels` | Get live TV channels |
| GET | `/LiveTv/Programs` | Get TV programs (filterable by channel, airing status, sports) |
| GET | `/LiveTv/Programs/Recommended` | Get recommended currently-airing programs |

> These Jellyfin Live TV endpoints exist in the API client but the app's actual live TV experience uses Xtream Codes, not Jellyfin's native live TV.

### 3.3 Common Query Parameters

Most item queries include these standard fields:

```
Fields=Overview,Genres,People,Studios,CommunityRating,OfficialRating,
       MediaSources,RunTimeTicks,PremiereDate,ImageTags,BackdropImageTags,
       ParentId,SeriesId,SeasonId,UserData
ImageTypeLimit=1
EnableImageTypes=Primary,Backdrop,Thumb
```

Pagination uses `Limit` and `StartIndex`. Sort uses `SortBy` (e.g., `SortName`, `DateCreated`, `CommunityRating`) and `SortOrder` (`Ascending`, `Descending`). The default page size is 50 items (`LumaConfig.pageSize`).

### 3.4 Data Models

#### `BaseItemDto` -- The Universal Item
Every Jellyfin entity (movie, series, season, episode, person, library folder) is represented as a `BaseItemDto`. Key fields:

```
Identity:     id, name, originalTitle, serverId, type (ItemType enum)
Metadata:     overview, taglines, genres, studios, people, communityRating,
              criticRating, officialRating, premiereDate, productionYear
Duration:     runTimeTicks (Int64, 100ns units)
Progress:     userData (UserData -- playback position, play count, favorite, played %)
Series info:  seriesId, seriesName, seasonId, seasonName, indexNumber, parentIndexNumber
Media:        mediaSources (array of MediaSourceInfo), mediaType, container
Images:       imageTags (dict), backdropImageTags (array), parentBackdropImageTags,
              primaryImageAspectRatio
Hierarchy:    parentId, collectionType, childCount, recursiveItemCount
Live TV:      channelNumber, channelName, currentProgram, startDate
```

#### `ItemType` Enum
```
Movie, Series, Season, Episode, BoxSet, Person, MusicAlbum, MusicArtist,
Audio, Folder, CollectionFolder, TvChannel, LiveTvChannel, Program, LiveTvProgram
```

#### `QueryResult<T>`
Standard paginated response wrapper:
```json
{
  "Items": [...],
  "TotalRecordCount": 150,
  "StartIndex": 0
}
```

#### `UserData`
Tracks per-user state for each item:
- `playbackPositionTicks` (Int64) -- resume position
- `playCount` (Int)
- `isFavorite` (Bool)
- `played` (Bool)
- `playedPercentage` (Double, 0-100)
- Computed: `progressPercent` (0.0-1.0), `resumePositionSeconds`

#### `MediaSourceInfo`
Represents a playable media source:
- `id`, `name`, `container`, `size`, `bitrate`, `path`
- `mediaStreams` -- array of `MediaStream` (video, audio, subtitle tracks)
- `supportsDirectPlay`, `supportsDirectStream`, `supportsTranscoding`
- Computed: `resolutionLabel` (e.g., "4K", "1080p", "720p")

#### `MediaStream`
Individual track within a media source:
- Video: `width`, `height`, `bitRate`, `codec`, `videoRange`, `videoRangeType`
- Audio: `channels`, `channelLayout`, `sampleRate`, `codec`
- Subtitle: `language`, `deliveryMethod`, `deliveryUrl`, `isForced`, `isExternal`
- Type enum: `Video`, `Audio`, `Subtitle`, `EmbeddedImage`

#### Auth & Server Models
- `PublicServerInfo` -- server name, version, ID, OS (from `/System/Info/Public`)
- `AuthRequest` -- `{ Username, Pw }` (POST body for login)
- `AuthResponse` -- `{ User (UserDto), AccessToken, ServerId }`
- `UserDto` -- `{ name, id, serverId, hasPassword, configuration, policy }`

### 3.5 Image URL Building

Jellyfin serves images via URL construction, not embedded data. The pattern:

```
{baseURL}/Items/{itemId}/Images/{imageType}[/{index}]?quality={q}&maxWidth={w}&maxHeight={h}&tag={tag}
```

#### Image Types Used

| Type | Purpose | Typical Size |
|------|---------|-------------|
| `Primary` | Poster art (2:3 ratio) | 240x360 |
| `Backdrop` | Widescreen background art (16:9) | 400x225 (thumbnail) or full-width |
| `Thumb` | Thumbnail (16:9) | 400x225 |
| `Logo` | Transparent title logo | max 500w x 160h |

#### Person Images
Person images use a different path:
```
{baseURL}/Persons/{encodedName}/Images/Primary?maxWidth=300&quality=90&tag={tag}
```
The person name must be percent-encoded for the URL path.

Default quality is 90 for all image requests.

### 3.6 Jellyfin Playback Flow

For on-demand Jellyfin content:

1. Get the item's `mediaSources` array from the item detail response.
2. Select a media source (typically the first/only one).
3. Construct stream URL:
   ```
   {baseURL}/Videos/{itemId}/{mediaSourceId}/master.m3u8
     ?MediaSourceId={mediaSourceId}
     &VideoCodec=h264,hevc
     &AudioCodec=aac,ac3,eac3
     &MaxStreamingBitrate=120000000
     &SubtitleMethod=Encode
     &api_key={accessToken}
     [&StartTimeTicks={resumePositionTicks}]
   ```
4. Hand the URL to AVPlayer (tvOS) or equivalent HLS player.
5. Report playback start, progress (every 10 seconds), and stop to the Jellyfin server.

---

## 4. IPTV / Xtream Codes Integration

### 4.1 API Structure

All Xtream API requests follow this pattern:

```
{baseURL}/player_api.php?username={user}&password={pass}&action={action}[&extra_params]
```

The API client (`XtreamAPI`) is a `@MainActor` singleton. URLSession config: 15-second request timeout, 300-second resource timeout.

### 4.2 Available Actions

| Action | Extra Params | Response Type | Purpose |
|--------|-------------|---------------|---------|
| `get_live_categories` | none | `[XtreamCategory]` | List all channel categories |
| `get_live_streams` | `category_id` (optional) | `[XtreamStream]` | List channels, optionally filtered by category |
| `get_short_epg` | `stream_id` | `XtreamEPGResponse` | Get current/upcoming EPG for a specific channel |

### 4.3 Data Models

#### `XtreamCategory`
```json
{
  "category_id": "680",
  "category_name": "USA SPORTS",
  "parent_id": 0
}
```

#### `XtreamStream`
```json
{
  "num": 1,
  "name": "US| ESPN HD",
  "stream_type": "live",
  "stream_id": 1921356,
  "stream_icon": "https://...",
  "epg_channel_id": "ESPN.us",
  "category_id": "680",
  "tv_archive": 0
}
```

#### `XtreamEPGEntry`
```json
{
  "id": "123456",
  "title": "base64_encoded_string",
  "start": "2026-03-23 14:00:00",
  "end": "2026-03-23 16:00:00",
  "description": "base64_encoded_string",
  "channel_id": "ESPN.us",
  "stream_id": "1921356"
}
```

**Critical**: The `title` and `description` fields are **base64-encoded UTF-8 strings**. They must be decoded before display:
```
base64 string -> Data (base64 decode) -> String (UTF-8)
```

#### `XtreamEPGResponse`
```json
{
  "epg_listings": [ ...XtreamEPGEntry array... ]
}
```

### 4.4 Stream URL Format

Live stream URLs follow this pattern:
```
{baseURL}/live/{username}/{password}/{stream_id}.m3u8
```

Example:
```
http://line.trxdnscloud.ru/live/914f80594b/32d6ec5d6f/1921356.m3u8
```

This URL does NOT serve the actual stream directly. See Section 8 for the redirect chain.

### 4.5 EPG Timezone

All EPG timestamps from the Xtream server are in the **Europe/Amsterdam** timezone. The `start` and `end` fields use the format `yyyy-MM-dd HH:mm:ss`. When parsing, the date formatter's timezone must be set to `Europe/Amsterdam`, then converted to the user's local timezone for display.

---

## 5. Channel Curation Strategy

### 5.1 The Problem

The IPTV provider exposes **51,000+ channels** across hundreds of categories. Showing all of them is impractical and would create a terrible user experience. Most channels are international duplicates, low-quality feeds, or irrelevant content.

### 5.2 The Solution: Hardcoded Stream IDs

The app maintains a **hardcoded allowlist** of specific stream IDs, organized into three sections. Only these channels are ever shown to the user.

#### Sports Section

| Channel | Stream ID | Quality | FPS |
|---------|-----------|---------|-----|
| ESPN HD | 1921356 | 1080p | 60 |
| ESPN 2 HD | 1921353 | 1080p | 60 |
| ESPN NEWS | 1921360 | 1080p | 60 |
| ESPN U | 1921359 | 1080p | 60 |
| CBS Sports Network | 45601 | 720p | 30 |
| NBC Sports Network | 234677 | 720p | 30 |
| Fox Sports 1 | 45571 | 720p | 30 |
| Fox Sports 2 | 45570 | 720p | 30 |
| ESPN UHD 4K | 1481941 | 4K | 60 |

#### NFL Section

| Channel | Stream ID | Quality | FPS |
|---------|-----------|---------|-----|
| NFL Network | 45526 | 720p | 30 |
| NFL RedZone | 45524 | 720p | 30 |

#### Golf Section

| Channel | Stream ID | Quality | FPS |
|---------|-----------|---------|-----|
| Golf Channel | 45554 | SD (540p) | 30 |
| NBC Golf | 45532 | SD (540p) | 30 |

### 5.3 Category IDs for Fetching

The curated channels span multiple Xtream categories. The app fetches streams from all relevant categories in parallel, then filters to only the known stream IDs:

| Category ID | Category Name |
|-------------|--------------|
| 680 | USA Sports |
| 2232 | ESPN |
| 675 | NFL |
| 1673 | UHD 4K |

```
fetch category 680 (sports)  ---|
fetch category 2232 (ESPN)   ---|---> merge all ---> filter to known IDs ---> group by section
fetch category 675 (NFL)     ---|
fetch category 1673 (4K)     ---|
```

### 5.4 EPG Enrichment

For each curated channel, the app fetches EPG data to determine what is currently airing:

1. Call `get_short_epg` with the channel's `stream_id`.
2. Parse the EPG entries (remember: title/description are base64).
3. For each entry, parse `start` and `end` as `Europe/Amsterdam` timezone.
4. Find the entry where `start <= now < end` -- this is the currently airing program.
5. If found: display the decoded program title, description, and local-time start/end.
6. If no EPG data or no current program: show a **fallback** using the cleaned channel name.

EPG checks happen concurrently for all channels in a section using a task group.

### 5.5 Channel Name Cleaning

Raw channel names from the provider include prefix tags and quality suffixes that should be stripped for display:

- **Prefix pattern**: `XX| ` (2-3 uppercase alphanumeric chars followed by `|` and space) -- e.g., `US| ESPN HD` becomes `ESPN HD`
- **Quality suffixes removed**: ` HD`, ` FHD`, ` SD`, ` UHD`, ` UHD/4K`, ` ᴴᴰ ⁶⁰ᶠᵖˢ`, ` ᴴᴰ ²⁵ᶠᵖˢ`, ` ᴴᴰ`

### 5.6 Quality Metadata

Each curated channel has associated quality metadata (resolution and frame rate), stored alongside the stream ID definitions. Quality levels:

| Quality | Badge Color | Typical Resolution |
|---------|------------|-------------------|
| 4K (UHD) | Purple | 2160p |
| 1080p (FHD) | Blue | 1920x1080 |
| 720p (HD) | Green | 1280x720 |
| SD | Gray | Below 720p |

---

## 6. Home Page Architecture

### 6.1 Data Loading

The home page loads data from both Jellyfin and IPTV concurrently on appear:

```
HomeViewModel.loadAll():
  async let continueWatching = getResumeItems(limit: 20)      // Jellyfin
  async let nextUp = getNextUp(limit: 20)                      // Jellyfin
  async let recentlyAdded = getLatestItems(limit: 20)          // Jellyfin
  async let libraries = getLibraries()                          // Jellyfin

LiveTVViewModel.loadAll():
  async let sports = getLiveStreams(category: 680)               // IPTV
  async let espn = getLiveStreams(category: 2232)                // IPTV
  async let nfl = getLiveStreams(category: 675)                  // IPTV
  async let uhd4k = getLiveStreams(category: 1673)               // IPTV
  --> filter to curated IDs --> EPG check each channel
```

Jellyfin data loads fast (local network, typically < 500ms). IPTV data takes longer (remote server + individual EPG checks per channel, typically 2-5 seconds).

### 6.2 Home Page Sections (top to bottom)

1. **Hero Banner** -- Large cinematic banner cycling through up to 6 recently added items that have backdrop images. Auto-rotates every 8 seconds (`LumaConfig.heroBannerInterval`).
2. **Continue Watching** -- Horizontal row of items with unfinished playback (from `getResumeItems`).
3. **Next Up** -- Horizontal row of next unwatched episodes for in-progress series (from `getNextUp`).
4. **Live TV** -- Combined highlights row from IPTV. Shows a skeleton/shimmer placeholder while IPTV data is loading.
5. **Recently Added** -- Horizontal row of latest items across all libraries (from `getLatestItems`).
6. **Library rows** -- One row per Jellyfin library view.

### 6.3 Loading States

- Jellyfin sections appear almost instantly (local network).
- The Live TV row shows a **skeleton/shimmer UI** while IPTV data loads, then swaps in the actual channel cards once EPG data is resolved.
- Sections with no data are hidden (e.g., if Continue Watching is empty, the row is not shown).

---

## 7. Live TV Page Architecture

### 7.1 Section Organization

The dedicated Live TV page displays three sections:

1. **Sports** -- ESPN channels, CBS/NBC/Fox Sports
2. **NFL** -- NFL Network, NFL RedZone
3. **Golf** -- Golf Channel, NBC Golf

Each section is independently loaded and only displayed if it has at least one channel with data. If a section has no channels (e.g., all streams failed), it is hidden entirely.

### 7.2 Channel Card Display

Each channel card shows:
- **Channel logo** (from `stream_icon` URL in the Xtream stream data)
- **Program title** (decoded from EPG, or cleaned channel name as fallback)
- **Channel name** (cleaned -- prefix and quality tags stripped)
- **Time range** (e.g., "7:00 PM - 9:30 PM" in local timezone, empty if no EPG)
- **"ON NOW" badge** (if EPG data confirmed a currently-airing program)

### 7.3 Empty State

If no channels have data across all sections (network error, provider down, etc.), an empty state is shown.

### 7.4 Channel Ordering

Channels within each section maintain the order defined in the hardcoded channel definitions array (see Section 5.2). This ensures a consistent, predictable layout regardless of the order the IPTV API returns data.

---

## 8. Stream Playback Pipeline

### 8.1 User Interaction Flow

1. User focuses on a channel card and presses select.
2. A `fullScreenCover` (modal overlay) opens `LiveStreamPlayerView`.
3. The view receives the stream name (for display) and stream URL.

### 8.2 Stream URL Construction

```
{baseURL}/live/{username}/{password}/{streamId}.m3u8
```

Example:
```
http://line.trxdnscloud.ru/live/914f80594b/32d6ec5d6f/1921356.m3u8
```

### 8.3 The Redirect Chain

**This is critical to understand for any platform implementation.**

When a player requests the stream URL above, the IPTV server responds with an **HTTP 302 redirect** to the actual streaming server. The redirect URL:

- Points to a **different IP address** each time (load-balanced CDN).
- Contains a **single-use authentication token** in the URL path or query string.
- The token is valid for **one connection attempt only**.

**Rules:**
- **DO NOT pre-resolve the redirect URL** (e.g., with a HEAD request or URLSession redirect follow). The token will be consumed and the actual player request will fail.
- **DO NOT cache redirect URLs**. They are single-use.
- **Let the media player follow the redirect natively.** AVPlayer on tvOS handles 302 redirects transparently. On Windows, ensure the chosen player (LibVLC, mpv, etc.) also follows HTTP redirects in its HLS pipeline.

### 8.4 AVPlayer Configuration (tvOS Reference)

```swift
let player = AVPlayer(url: streamURL)
player.automaticallyWaitsToMinimizeStalling = true
player.play()
```

The current implementation uses a simple setup. For an enhanced implementation, consider:

- `player.currentItem?.automaticallyPreservesTimeOffsetFromLive = true`
- `player.currentItem?.configuredTimeOffsetFromLive = .zero`
- Seek to `CMTime.positiveInfinity` once the player reports `readyToPlay` to jump to the live edge.

### 8.5 Player UI

The player is presented inside an `AVPlayerViewController` (tvOS system player UI) wrapped in a `UIViewControllerRepresentable`. On dismiss:

1. `player.pause()`
2. `player.replaceCurrentItem(with: nil)` -- releases the HLS connection
3. `player = nil`

### 8.6 Timeout

The URLSession is configured with a 15-second request timeout. If the IPTV stream fails to begin loading within 15 seconds, the request times out.

---

## 9. Known Issues & Platform Notes

### 9.1 tvOS Simulator Video Rendering

The tvOS simulator **cannot render video** for most IPTV HLS streams. Audio plays normally, but the video layer shows black. This is a simulator limitation. **Real Apple TV hardware plays video correctly.** Do not debug video rendering issues in the simulator.

### 9.2 HLS Live Window

IPTV HLS playlists have very small live windows (approximately 60 seconds of segments). This means:
- The AVPlayer scrub bar / timeline does not behave like traditional DVR-capable live TV.
- There is essentially no rewind buffer.
- If the player falls behind the live edge, it may stall or rebuffer.

### 9.3 Single-Use Redirect Tokens

The IPTV server's 302 redirect URLs contain single-use tokens. Consequences:
- **Never cache stream URLs** after following a redirect.
- **Never pre-resolve** (HEAD, curl, etc.) before handing to the player.
- Each new playback session must start from the original stream URL to get a fresh redirect.

### 9.4 tvOS Focus Chrome

On real tvOS hardware, `.buttonStyle(.plain)` still renders the system's white focus chrome (a white rounded-rect highlight behind the focused button). The app uses a custom `NoChromeFocusStyle` to suppress this:
- Uses `@FocusState` to track focus.
- Applies scale (1.05x) and brightness (+0.2) on focus instead of the system chrome.
- Applies opacity (0.7) on press for feedback.

Any tvOS implementation should use this or a similar approach for custom card/button UI.

### 9.5 Stream ID Stability

The hardcoded stream IDs (see Section 5.2) are assigned by the IPTV provider. If the provider reorganizes their channel lineup, these IDs may change and will need to be updated in the app. There is currently no dynamic discovery mechanism -- the IDs are maintained manually.

### 9.6 Credential Storage Note

The current `KeychainHelper` implementation uses `UserDefaults` (with a `me.athion.luma.` prefix) rather than the actual iOS/tvOS Keychain. This is a simplification. For a production app, especially on Windows, use the platform's secure credential store:
- **tvOS/iOS**: Keychain Services
- **Windows**: Windows Credential Manager or DPAPI
- **Android**: EncryptedSharedPreferences or Android Keystore

---

## 10. Windows Implementation Notes

### 10.1 API Compatibility

Both APIs are standard HTTP REST:

- **Jellyfin**: JSON over HTTP. All endpoints, headers, and query parameters work identically on any platform. The `Authorization` header format is the same. No platform-specific SDKs are required.
- **Xtream**: JSON over HTTP. Query-parameter-based authentication. No sessions, cookies, or platform-specific behavior.

A Windows implementation can use any HTTP client (WinHTTP, libcurl, .NET HttpClient, etc.).

### 10.2 Stream Playback

The player must support:
1. **HLS** (HTTP Live Streaming) -- `.m3u8` playlists with `.ts` segments.
2. **HTTP 302 redirects** followed transparently by the media pipeline (not pre-resolved).
3. **Live streaming** (no total duration, sliding window playlist).

Recommended players for Windows:
- **LibVLC** -- Mature, handles HLS + redirects natively. Available via libvlcsharp for .NET.
- **mpv** -- Lightweight, excellent HLS support, follows redirects. Available via mpv.net or libmpv.
- **Windows Media Foundation** -- Native Windows API, supports HLS on Windows 10+. Redirect handling may require custom `IMFSchemeHandler`.

**Critical**: The chosen player MUST follow HTTP 302 redirects within its streaming pipeline. If using a player that requires you to provide the final URL, you cannot pre-resolve it (the token is single-use). Choose a player that handles redirects internally.

### 10.3 EPG Timezone Conversion

EPG times are in `Europe/Amsterdam` (CET/CEST, UTC+1/UTC+2 depending on DST):

```
Server sends:  "2026-03-23 20:00:00"  (Europe/Amsterdam)
Parse as:      2026-03-23T20:00:00+01:00  (or +02:00 during summer)
Display as:    local time for the user
```

On Windows, use `TimeZoneInfo.FindSystemTimeZoneById("W. Europe Standard Time")` (.NET) or equivalent to parse server times, then convert to local.

### 10.4 Base64 EPG Decoding

EPG `title` and `description` fields are base64-encoded UTF-8:

```
input:  "U3BvcnRzQ2VudGVy"
decode: base64 -> bytes -> UTF-8 string -> "SportsCenter"
```

On Windows: `Convert.FromBase64String()` (.NET) or `CryptStringToBinaryA()` (Win32).

### 10.5 Image Loading

Jellyfin images are standard HTTP URLs with query parameters for sizing. No special handling needed -- use any image loading library. Consider:
- **Caching**: The tvOS app uses a 500MB image cache (`LumaConfig.imageCacheSizeMB`). Implement similar disk/memory caching on Windows.
- **Quality parameter**: Default is 90. Reduce for bandwidth-constrained environments.
- **Sizing**: Always pass `maxWidth`/`maxHeight` to avoid downloading full-resolution images when a smaller size is needed.

### 10.6 UI Design Constants (Reference)

From the tvOS implementation's `LumaTheme`:

| Element | Value |
|---------|-------|
| Poster card | 240 x 360 (2:3) |
| Thumbnail card | 400 x 225 (16:9) |
| Hero banner height | 700pt |
| Hero logo max | 500w x 160h |
| Card corner radius | 12pt |
| Focus scale | 1.08x |
| Focus shadow | 25pt radius |
| 8pt spacing grid | 4, 8, 16, 24, 32, 48, 64 |

### 10.7 Network Assumptions

- **Jellyfin** is on the local network. Expect very fast responses (< 100ms). Timeouts can be aggressive.
- **IPTV** is on the public internet. Expect 1-5 second latency for API calls and EPG lookups. Stream startup may take several seconds due to the redirect + HLS playlist fetch + first segment download.

---

## Appendix A: Error Types

### Jellyfin Errors (`JellyfinError`)

| Case | Description |
|------|-------------|
| `invalidURL` | Server URL is malformed |
| `invalidResponse` | Response is not a valid HTTP response |
| `httpError(statusCode)` | Non-2xx, non-401 HTTP status |
| `unauthorized` | HTTP 401 -- token expired or invalid |
| `serverUnreachable` | Network request failed entirely |
| `decodingError(error)` | JSON deserialization failed |
| `noToken` | No access token available |
| `noUserId` | No user ID available (not logged in) |

### Xtream Errors (`XtreamError`)

| Case | Description |
|------|-------------|
| `invalidURL` | API URL construction failed |
| `invalidResponse` | Response is not valid or network failed |
| `httpError(statusCode)` | Non-2xx HTTP status |
| `decodingError(error)` | JSON deserialization failed |

---

## Appendix B: Full Model Hierarchy

```
BaseItemDto
  ├── id: String
  ├── name: String?
  ├── type: ItemType? (Movie|Series|Season|Episode|BoxSet|Person|...)
  ├── overview: String?
  ├── genres: [String]?
  ├── people: [PersonInfo]?
  │     ├── name, id, role, type (Actor|Director|Writer|Producer)
  │     └── primaryImageTag
  ├── studios: [StudioInfo]?
  │     └── name, id
  ├── communityRating: Double?
  ├── officialRating: String? (e.g., "PG-13", "TV-MA")
  ├── runTimeTicks: Int64?
  ├── userData: UserData?
  │     ├── playbackPositionTicks, playCount, isFavorite, played
  │     ├── playedPercentage (0-100)
  │     └── computed: progressPercent (0.0-1.0), resumePositionSeconds
  ├── mediaSources: [MediaSourceInfo]?
  │     ├── id, container, size, bitrate
  │     ├── supportsDirectPlay, supportsDirectStream, supportsTranscoding
  │     ├── mediaStreams: [MediaStream]?
  │     │     ├── type (Video|Audio|Subtitle|EmbeddedImage)
  │     │     ├── codec, language, displayTitle
  │     │     ├── Video: width, height, bitRate, videoRange
  │     │     ├── Audio: channels, channelLayout, sampleRate
  │     │     └── Subtitle: deliveryMethod, deliveryUrl, isForced, isExternal
  │     └── computed: resolutionLabel
  ├── imageTags: [String: String]?
  ├── backdropImageTags: [String]?
  ├── seriesId, seriesName, seasonId, seasonName
  ├── indexNumber (episode #), parentIndexNumber (season #)
  └── currentProgram: LiveTVProgram? (for live TV items)
        └── id, name, overview, startDate, endDate, channelId
```
