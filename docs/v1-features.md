# Aether v1 Feature Specification

Custom Jellyfin client for Apple TV, built with SwiftUI.

---

## Goals

- Deliver a polished, fully functional Jellyfin client for Apple TV that covers the core media consumption loop: browse, select, play, resume.
- Feel native to tvOS — proper focus management, smooth animations, standard remote interactions. No ported-from-iOS jank.
- Achieve feature parity with the basics of Swiftfin, then exceed it in UI quality and responsiveness.
- Correctly report playback state so continue watching, watch history, and played status sync across every Jellyfin client connected to the server.
- Establish the codebase architecture (service layer, view models, views) so future features can be added without rewriting.

## Non-Goals

- Competing with Infuse/Plex on day one. v1 is about getting the fundamentals bulletproof.
- Supporting anything beyond a single Jellyfin server.
- Admin or server management functionality.
- Music or audiobook playback.
- Live TV, IPTV, or DVR.

---

## Core Features

### 1. Server Connection & Authentication

Standard Jellyfin username/password authentication. Athion SSO is a future milestone.

**Server setup:**
- Text field for server URL (e.g., `https://jellyfin.example.com`).
- Validate the URL by hitting the `/System/Info/Public` endpoint before proceeding.
- Display the server name and version on successful connection.
- Persist the server URL in `UserDefaults` so the user does not re-enter it on every launch.
- Support both HTTP and HTTPS. No warnings for HTTP — the user knows their setup.

**Login:**
- Username and password fields.
- Authenticate via `POST /Users/AuthenticateByName`.
- Store the access token and user ID securely in the Keychain.
- All subsequent API requests include the `MediaBrowser` authorization header:
  ```
  MediaBrowser Client="Aether", Device="AppleTV", DeviceId="{unique}", Version="1.0", Token="{token}"
  ```
- On launch, attempt to reuse the stored token. If the server rejects it (401), drop back to the login screen.
- "Sign Out" option accessible from the Home screen's top-level navigation, which clears stored credentials and returns to server setup.

**Error handling:**
- Server unreachable — clear message, retry button.
- Invalid credentials — inline error, fields remain populated.
- Token expired mid-session — catch 401 responses globally, prompt re-authentication without losing navigation state if possible.

---

### 2. Home Screen

The landing screen after authentication. Provides quick access to in-progress and new content.

**Sections (top to bottom):**

1. **Continue Watching** — Items with a non-zero `PlaybackPositionTicks` that are not marked as played. Sorted by `DatePlayed` descending (most recently watched first). Displays poster art with a progress bar overlay at the bottom of each card showing percentage complete. Endpoint: `GET /Items?userId={id}&isResumable=true&SortBy=DatePlayed&SortOrder=Descending&Limit=20`.

2. **Next Up** — The next unwatched episode in any series the user is actively watching. This is the "you finished episode 3, here's episode 4" row. Endpoint: `GET /Shows/NextUp?userId={id}&Limit=20`. Each card shows the series name, episode title, and episode number.

3. **Recently Added** — One row per library (Movies, TV Shows, etc.). Each row shows the latest items added to that library, sorted by `DateCreated` descending. Endpoint: `GET /Items?userId={id}&ParentId={libraryId}&SortBy=DateCreated&SortOrder=Descending&Limit=20`. Uses poster art for movies, series art for TV (not individual episode art).

4. **Library Shortcuts** — A row of cards, one per user-visible library (from `GET /Users/{userId}/Views`). Selecting one navigates to the full library browser for that collection.

**Behavior:**
- Horizontal scrolling within each row.
- Vertical scrolling between rows.
- Focus on the first item in Continue Watching on initial load (or Next Up if Continue Watching is empty, or Recently Added if both are empty).
- Pull-to-refresh is not a tvOS pattern. Instead, refresh data every time the Home screen appears (on `task` or `onAppear`).
- Empty state: if the server has no libraries or no content, show a centered message ("No content found on this server").

---

### 3. Library Browsing

Full browsing interface for a single library (Movies, TV Shows, Collections, etc.).

**Grid view (default):**
- Poster art grid. Movies show movie posters. TV shows show series posters.
- 5 columns on a standard 1080p Apple TV display. Adjust column count if Apple TV 4K renders at a higher effective resolution.
- Poster cards show the title below the image. Focused card scales up slightly (standard tvOS lift effect).
- Infinite scroll / pagination. Load 40 items at a time using `StartIndex` and `Limit` parameters. Trigger the next page load when the user scrolls within 2 rows of the bottom.

**List view (toggle):**
- Horizontal rows with backdrop image on the left, title + year + rating + runtime on the right.
- Useful for quickly scanning a large library.

**Sorting:**
- Options: Name (A-Z, Z-A), Date Added (newest/oldest), Release Date (newest/oldest), Community Rating (highest first), Runtime (shortest/longest).
- Accessible via a button in the top bar. Opens a dropdown/overlay to select sort field and order.
- Default: Date Added, newest first.

**Filtering:**
- Genre filter: fetch available genres from `GET /Genres?ParentId={libraryId}`, display as a selectable list. Multiple genres can be selected (AND logic).
- Year filter: range selector or list of available years.
- Played/Unplayed filter: All / Unplayed Only / Played Only.
- Favorite filter: toggle to show only favorited items.
- Filters accessible from the same top bar area as sorting.
- Active filters should display as pills/tags below the top bar so the user knows what is applied.

**Collections:**
- If the library type is `boxsets`, display collections as cards. Selecting a collection shows its child items in a sub-grid.

**Behavior:**
- Remember the user's scroll position when navigating back from a detail view.
- Remember selected sort/filter within a session (reset on app relaunch is fine for v1).

---

### 4. Item Detail

Full detail screen for a movie, series, season, or episode.

**Layout — Movies:**
- Full-width backdrop image at the top with gradient fade to the background.
- Logo image overlaid on the backdrop if available (from `/Items/{id}/Images/Logo`), otherwise the title as text.
- Metadata row: year, runtime, community rating (star icon + number), official rating (PG-13, R, etc.), video resolution (4K, 1080p).
- Genres as a comma-separated list or tags.
- Overview/description text. Truncated with "Show More" if it exceeds 4 lines.
- **Play button** — primary focused action. Shows "Resume from XX:XX" if there is a saved position, otherwise "Play".
- Cast & crew row: horizontal scrollable list of actor cards (headshot + name + role). Tapping an actor is a no-op in v1 (future: actor detail/filmography).
- Media info section: video codec, audio codec, container, resolution, audio channels. Pulled from `MediaSources` in the item detail response.

**Layout — TV Series:**
- Same backdrop/logo/metadata header as movies but with total season count and episode count instead of runtime.
- **Season picker**: horizontal row of season cards (season poster + "Season 1", "Season 2", etc.). First unwatched season is focused by default.
- **Episode list**: vertical list below the season picker showing episodes for the selected season. Each episode row displays:
  - Episode thumbnail (landscape).
  - Episode number and title (e.g., "E03 - The Storm").
  - Runtime.
  - Played checkmark if already watched.
  - Progress bar if partially watched.
  - Brief overview text (1-2 lines, truncated).
- Selecting an episode navigates to the player.
- "Play Next Episode" button at the top of the episode list that jumps to the next unwatched episode.

**Layout — Individual Episode (when navigated to directly):**
- Backdrop from the episode (or series fallback).
- Series name, season/episode number, episode title.
- Full overview text, runtime, air date.
- Play button.

**Favorite toggle:**
- Accessible from the detail screen (e.g., a heart icon). Calls `POST /Users/{userId}/FavoriteItems/{itemId}` or the DELETE equivalent.

**Watched toggle:**
- Mark as played / unplayed. Calls `POST /Users/{userId}/PlayedItems/{itemId}` or DELETE.

---

### 5. Video Playback

Full-screen video player using AVKit/AVPlayer.

**Stream negotiation:**
- For each item, inspect `MediaSources` to determine if direct play is possible.
- If the video codec and container are natively supported by AVPlayer (see Technical Requirements), request direct play with `Static=true`.
- If transcoding is needed, use the HLS stream URL (`/Videos/{itemId}/{mediaSourceId}/master.m3u8`) and let the server transcode.
- Prefer direct play to reduce server load and latency.

**Transport controls:**
- Use the system `AVPlayerViewController` for standard tvOS transport controls:
  - Play / Pause (click remote center button, or play/pause button on Siri Remote).
  - Scrub (swipe left/right on Siri Remote touchpad).
  - Skip forward/back 10 seconds (press left/right edges of touchpad, or use skip buttons).
  - Info panel showing item title, elapsed time, remaining time, and the scrub bar.
- No custom player overlay in v1. System controls are good enough and handle all remote input correctly out of the box.

**Resume:**
- If the item has `UserData.PlaybackPositionTicks > 0`, present a choice on play: "Resume from XX:XX" or "Play from Beginning".
- When resuming, pass `StartTimeTicks` to the stream URL and also call `AVPlayer.seek(to:)` to the correct position.

**Audio and subtitle track selection:**
- Expose available audio tracks from `MediaStreams` where `Type == "Audio"`.
- Expose available subtitle tracks from `MediaStreams` where `Type == "Subtitle"`.
- Allow selection via the standard tvOS info panel (the swipe-down panel during playback).
- Default audio: the track marked as default by the server.
- Default subtitles: the user's subtitle preference from Jellyfin settings, or none.

**Playback completion:**
- When playback reaches 90% or more of total runtime, mark the item as played via `POST /Users/{userId}/PlayedItems/{itemId}`.
- For TV episodes, after marking as played, show an overlay: "Up Next: [next episode title]" with a 15-second countdown. Auto-play the next episode when the countdown expires, or cancel if the user presses Menu/Back.

**Error handling:**
- Playback fails to start — display an error overlay with the failure reason if available, and a "Try Again" button.
- Stream interruption — AVPlayer handles buffering natively. If the stream dies entirely, show an error and offer retry.

---

### 6. Playback Reporting

Ensures that watch position and played state stay in sync with the Jellyfin server and all other connected clients.

**Reporting lifecycle:**

1. **Playback start** — `POST /Sessions/Playing` when AVPlayer begins playback. Payload:
   - `ItemId`
   - `MediaSourceId`
   - `PlaySessionId` (generate a unique UUID per playback session)
   - `PositionTicks` (starting position)
   - `PlayMethod` (`DirectPlay` or `Transcode`)
   - `AudioStreamIndex`
   - `SubtitleStreamIndex`

2. **Progress updates** — `POST /Sessions/Playing/Progress` every 10 seconds during active playback. Payload:
   - All fields from start, plus updated `PositionTicks` and `IsPaused`.
   - Also report on pause/unpause events immediately (do not wait for the next 10-second tick).

3. **Playback stopped** — `POST /Sessions/Playing/Stopped` when:
   - User presses Menu/Back to exit the player.
   - Playback reaches the end of the item.
   - The app enters the background.
   - An error terminates playback.
   - Include final `PositionTicks`.

**Edge cases:**
- If the network is unavailable when a stop report is due, queue it and retry when connectivity returns (best-effort, do not persist across app launches in v1).
- If the app is force-killed, the last progress report (sent up to 10 seconds ago) is the best the server will have. This is acceptable.

---

### 7. Image Loading & Caching

**URL construction:**
- Build image URLs using the pattern: `{serverUrl}/Items/{itemId}/Images/{imageType}?maxWidth={w}&maxHeight={h}&quality=90`.
- Image types used: `Primary` (posters), `Backdrop` (detail screens, episode thumbnails), `Logo` (detail screen overlay), `Thumb` (episode thumbnails fallback).
- Request appropriate sizes based on where the image is displayed:
  - Poster grid cards: `maxWidth=300`.
  - Detail backdrop: `maxWidth=1920`.
  - Episode thumbnails: `maxWidth=500`.
  - Actor headshots: `maxWidth=200`.

**Caching strategy:**
- Use a third-party image loading library (Nuke or Kingfisher) for disk and memory caching.
- Do not use `AsyncImage` for production — it has no disk cache and re-downloads images when views are recreated.
- Cache images on disk with a reasonable size limit (500 MB). LRU eviction.
- Memory cache for currently visible images.
- Placeholder: solid dark gray rectangle matching the aspect ratio of the expected image (2:3 for posters, 16:9 for backdrops).
- Fade-in animation when an image finishes loading.

**Blurhash (stretch goal within v1):**
- Jellyfin returns blurhash strings for most images. If time allows, decode the blurhash and display it as the placeholder instead of a gray rectangle. This significantly improves perceived loading speed.

---

### 8. Search

Global search across all libraries.

**Interface:**
- Accessible from the top-level tab bar (alongside Home and Libraries).
- Text input field at the top. tvOS will present the on-screen keyboard when the field is focused.
- Results appear below the search field as the user types (debounced — wait 300ms after the last keystroke before firing the request).

**Endpoint:** `GET /Items?searchTerm={query}&userId={id}&Recursive=true&Limit=30`

**Result display:**
- Group results by type: Movies, Series, Episodes, Collections.
- Each group is a horizontal row of poster/thumbnail cards.
- Selecting a result navigates to its detail screen.
- If no results are found, display "No results for '{query}'".

**Behavior:**
- Search is performed against the Jellyfin server, not locally. No local indexing needed.
- Clear the search field and results when navigating away from the search tab.

---

## Out of Scope for v1

The following features are explicitly excluded from the v1 release. They may appear in future versions.

- **Live TV / IPTV / DVR** — Requires significant additional API integration and a fundamentally different UI paradigm (channel guide, recording management).
- **Music playback** — Different UI, background audio session management, queue/playlist logic. A separate effort.
- **User management / admin** — Creating, editing, or deleting users. This belongs in the Jellyfin web dashboard.
- **Athion SSO** — Authentication via athion.me. v1 uses standard Jellyfin credentials. SSO is planned for a future release when the Athion auth service is ready.
- **Multi-server support** — Connecting to more than one Jellyfin server simultaneously. v1 supports a single server.
- **Parental controls / user switching** — Managed profiles, PIN-protected users, content restrictions.
- **SyncPlay** — Synchronized group playback sessions.
- **Offline downloads** — Downloading media for offline viewing. tvOS storage is limited and this requires significant download management UI.
- **Custom themes / appearance settings** — A single dark theme ships with v1.
- **Chapter support** — Displaying chapter markers on the scrub bar and chapter selection UI.
- **Trailers / extras** — Playing trailers or bonus content from within the detail screen.
- **External subtitle file support** — v1 supports embedded subtitles and server-side subtitle burn-in. External .srt/.ass delivery to the client is deferred.

---

## Technical Requirements

### Platform

- **Minimum deployment target:** tvOS 17.0
  - tvOS 17 is the baseline for reliable `@Observable` macro support, NavigationStack improvements, and the current SwiftUI feature set.
  - tvOS 17 runs on Apple TV HD (4th gen) and all Apple TV 4K models. No users are excluded.
- **Built with:** Xcode 15+ and Swift 5.9+.

### Supported Codecs for Direct Play

These codecs and containers are natively supported by AVPlayer on tvOS and should be requested for direct play (no transcoding):

**Video codecs:**
| Codec | Notes |
|-------|-------|
| H.264 (AVC) | Baseline, Main, High profiles up to Level 5.2 |
| H.265 (HEVC) | Main, Main 10 profiles. Hardware decoding on all Apple TV 4K models. |
| VP9 | Supported on Apple TV 4K (2nd gen and later) via tvOS 16+. Profile 0 and 2. |
| AV1 | Supported on Apple TV 4K (3rd gen, 2022) via tvOS 16+. |

**Audio codecs:**
| Codec | Notes |
|-------|-------|
| AAC | All profiles (LC, HE-AAC, HE-AAC v2) |
| AC3 (Dolby Digital) | Passthrough to receiver |
| E-AC3 (Dolby Digital Plus) | Passthrough to receiver, includes Dolby Atmos via DD+ |
| ALAC | Apple Lossless |
| FLAC | Supported on tvOS 11+ |
| Opus | Supported on tvOS 17+ |

**Containers:**
| Container | Notes |
|-----------|-------|
| MP4 / M4V | Primary container for direct play |
| MOV | Supported natively |
| MKV via HLS | MKV is not directly supported by AVPlayer. Jellyfin's HLS remuxing handles MKV content. If the video and audio codecs are compatible, only remuxing is needed (no transcoding). |

**Subtitle formats (embedded):**
| Format | Delivery |
|--------|----------|
| SRT | Extracted and delivered as WebVTT via HLS |
| SSA/ASS | Server burns in (transcoding of subtitle stream only) |
| PGS | Server burns in |
| WebVTT | Native support via HLS |

### Network Requirements

- The Apple TV must be on the same network as the Jellyfin server, OR the server must be accessible via a public URL / reverse proxy / VPN.
- Minimum recommended bandwidth for direct play: 20 Mbps for 1080p content, 40 Mbps for 4K content (actual requirements depend on the source bitrate).
- The app makes standard HTTPS (or HTTP) requests. No special ports beyond what the Jellyfin server is configured to use.

### Dependencies

| Dependency | Purpose |
|------------|---------|
| **Nuke** (or Kingfisher) | Async image loading with disk + memory cache. Choose one. Nuke is lighter weight. |

Minimize third-party dependencies. SwiftUI, AVKit, and Foundation cover the vast majority of needs. The image caching library is the only expected external dependency for v1.

---

## Success Criteria

v1 is complete when the following are true:

1. **End-to-end flow works**: A user can connect to a Jellyfin server, log in, browse their libraries, find a movie or TV episode, play it, and have the playback position sync correctly to other Jellyfin clients (web, mobile, etc.).

2. **Direct play works for common formats**: H.264 and H.265 content in MP4 containers plays without transcoding. The app correctly falls back to HLS transcoding for incompatible formats.

3. **Continue Watching is accurate**: Resuming a partially watched item starts at the correct position. The Home screen's Continue Watching row reflects the true state from the server.

4. **TV show navigation is complete**: Users can browse series, pick seasons, pick episodes, and auto-advance to the next episode on completion.

5. **The app feels native to tvOS**: Focus moves predictably, animations are smooth, and the Siri Remote controls are responsive. No broken focus traps, no laggy scrolling on large libraries.

6. **Search returns relevant results**: A user can search by title and find movies, shows, and episodes across all libraries.

7. **No data loss or corruption**: The app never marks an item as played incorrectly, never reports wrong playback positions, and never loses the user's authentication state unexpectedly.

8. **Stable on real hardware**: Tested on a physical Apple TV (not just the simulator) with a library of at least several hundred items. No crashes during normal usage patterns.
