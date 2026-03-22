# Aether - Research & Architecture

## Overview

Aether is a custom Jellyfin client for Apple TV (tvOS) built from scratch with SwiftUI. The goal is full control over the viewing experience and features missing from existing clients like Swiftfin.

## Prerequisites

- **Mac required** - Xcode is macOS-only, no alternative for tvOS development
- **Apple Developer Program** ($99/year) - required to deploy to a physical Apple TV
- **tvOS Simulator** - available in Xcode for development without a physical device
- **Xcode 15+** - for latest SwiftUI and tvOS SDK support

## Jellyfin API

### Authentication

Authenticate via POST to `/Users/AuthenticateByName` with username and password. Returns an access token used for all subsequent requests.

**Authorization header format:**
```
MediaBrowser Client="Aether", Device="AppleTV", DeviceId="unique-id", Version="1.0", Token="access-token"
```

Alternative: `X-Emby-Token` header with just the token value.

### Library Browsing

| Endpoint | Purpose |
|----------|---------|
| `GET /Users/{userId}/Views` | Fetch all libraries (Movies, TV, Music) |
| `GET /Items?ParentId={id}` | Browse items within a library |
| `GET /Shows/{seriesId}/Seasons` | Get seasons for a TV show |
| `GET /Shows/{seriesId}/Episodes?SeasonId={id}` | Get episodes for a season |
| `GET /Items/{id}` | Get full details for a single item |
| `GET /Items?SearchTerm={query}` | Search across libraries |

**Key query parameters:** `userId`, `isMissing=false`, `excludeItemTypes=Virtual`, `SortBy`, `SortOrder`, `Limit`, `StartIndex`

### Video Streaming

Jellyfin serves HLS natively - perfect for tvOS since AVPlayer handles HLS out of the box.

**Stream URL:**
```
GET /Videos/{itemId}/{mediaSourceId}/master.m3u8
```

**Parameters:**
- `DeviceId` - client identifier
- `AudioStreamIndex` - audio track selection
- `SubtitleStreamIndex` - subtitle track
- `StartTimeTicks` - resume position (1 tick = 100 nanoseconds)
- `MaxVideoBitrate` / `MaxAudioBitrate` - quality caps
- `Static=true` - direct play without transcoding (when codec is compatible)

AVPlayer auto-selects the best quality stream based on network conditions.

### Images

Artwork URLs follow this pattern:
```
GET /Items/{itemId}/Images/{imageType}
```

**Image types:** `Primary` (poster), `Backdrop`, `Logo`, `Thumb`, `Banner`

Optional parameters: `maxWidth`, `maxHeight`, `quality` for resizing.

### Playback Reporting

Report playback state so "Continue Watching" works across all Jellyfin clients.

| Endpoint | When |
|----------|------|
| `POST /Sessions/Playing` | Playback starts |
| `POST /Sessions/Playing/Progress` | Periodic updates (every 10s) |
| `POST /Sessions/Playing/Stopped` | Playback ends or pauses |

**Payload includes:** `ItemId`, `MediaSourceId`, `PositionTicks`, `IsPaused`, `PlayMethod`

## tvOS Development

### Focus Engine

tvOS uses a **focus-based** navigation system instead of touch. The Siri Remote moves focus between UI elements.

- `@FocusState` - track and control which element is focused
- `focusable()` - make custom views focusable
- `onMoveCommand` - handle directional remote input (up/down/left/right)
- Focused elements should scale up slightly and show a highlight

### Navigation Patterns

- `NavigationStack` with `NavigationLink` for drilling into content
- `TabView` with `.sidebarAdaptable` style (tvOS 18+) for top-level sections
- No back button on remote - system handles back navigation via Menu button

### Video Playback

```swift
import AVKit
import SwiftUI

struct PlayerView: View {
    let streamURL: URL

    var body: some View {
        VideoPlayer(player: AVPlayer(url: streamURL))
    }
}
```

AVPlayer natively supports:
- HLS adaptive streaming (.m3u8)
- Auto quality selection based on bandwidth
- Picture-in-picture (tvOS 14+)
- Standard transport controls (play/pause, scrub, skip)

For custom controls, use `AVPlayerViewController` with overlay views.

### Image Loading

Use `AsyncImage` (built into SwiftUI) or a library like Kingfisher/Nuke for caching:

```swift
AsyncImage(url: posterURL) { image in
    image.resizable().aspectRatio(contentMode: .fill)
} placeholder: {
    Color.gray
}
```

For production, a caching library is recommended to avoid re-downloading artwork.

## App Architecture

### Screens (v1)

1. **Server Setup** - enter Jellyfin server URL
2. **Login** - username/password authentication
3. **Home** - continue watching, recently added, library sections
4. **Library** - grid of items with poster art, filtering/sorting
5. **Detail** - backdrop, metadata, seasons/episodes, play button
6. **Player** - full-screen video with transport controls

### Data Flow

```
Jellyfin Server (HLS/REST API)
    |
JellyfinAPI (Swift service layer)
    |
ViewModels (@Observable classes)
    |
SwiftUI Views
```

### Project Structure

```
Aether/
  App/
    AetherApp.swift          # Entry point
    ContentView.swift        # Root navigation
  Models/
    MediaItem.swift          # Movie/show/episode models
    User.swift               # Auth models
    Library.swift            # Library/collection models
  Services/
    JellyfinAPI.swift        # HTTP client, auth, requests
    ImageService.swift       # Artwork URL building + caching
    PlaybackReporter.swift   # Session progress reporting
  ViewModels/
    HomeViewModel.swift      # Home screen data
    LibraryViewModel.swift   # Library browsing
    DetailViewModel.swift    # Item detail + episodes
    PlayerViewModel.swift    # Playback state management
  Views/
    Auth/
      ServerSetupView.swift
      LoginView.swift
    Home/
      HomeView.swift
      ContinueWatchingRow.swift
      RecentlyAddedRow.swift
    Library/
      LibraryView.swift
      MediaGridItem.swift
    Detail/
      DetailView.swift
      SeasonPicker.swift
      EpisodeRow.swift
    Player/
      PlayerView.swift
  Utils/
    Constants.swift
    Extensions.swift
```

## Challenges

### Hard
- **Learning Swift/SwiftUI from zero** - biggest time investment
- **Focus management** - tvOS focus engine is unintuitive, debugging focus issues is painful
- **Transcoding negotiation** - telling Jellyfin what codecs/containers the Apple TV supports for optimal direct play

### Medium
- **Playback resume** - accurate tick-based position reporting
- **Subtitle rendering** - handling embedded vs external subtitles
- **Error handling** - network failures, server unreachable, transcoding failures

### Easy (on tvOS specifically)
- **HLS playback** - AVPlayer handles this natively, almost zero code
- **Image loading** - AsyncImage + Jellyfin image API is straightforward
- **Basic navigation** - NavigationStack works well for media browsing

## References

- [Jellyfin API Overview](https://jmshrv.com/posts/jellyfin-api/)
- [Jellyfin API Authorization](https://gist.github.com/nielsvanvelzen/ea047d9028f676185832e51ffaf12a6f)
- [Creating a tvOS media catalog app (Apple)](https://developer.apple.com/documentation/SwiftUI/Creating-a-tvOS-media-catalog-app-in-SwiftUI)
- [Build SwiftUI apps for tvOS - WWDC20](https://developer.apple.com/videos/play/wwdc2020/10042/)
- [HLS Streaming with AVKit and SwiftUI](https://www.createwithswift.com/hls-streaming-with-avkit-and-swiftui/)
- [Swiftfin Source (reference)](https://github.com/jellyfin/Swiftfin)
