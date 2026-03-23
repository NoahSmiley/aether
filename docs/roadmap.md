# Aether — Beyond v1 Roadmap

> A custom Jellyfin client for Apple TV, built with SwiftUI.
> Part of the Athion ecosystem (athion.me).

This document outlines the long-term vision for Aether beyond the initial v1 release. v1 covers the foundation: server connection, authentication, home screen, library browsing, detail views, video playback, search, and settings. Everything below builds on that base.

---

## v1.x — Polish & Quality of Life

The goal of 1.x is to make Aether feel like a premium, native tvOS app — not just functional, but genuinely pleasant to use every day. No new architectural changes, just depth and refinement.

### Playback Improvements

| Feature | Description | Priority |
|---|---|---|
| Skip intro detection | Leverage Jellyfin's Intro Skipper plugin data to surface a "Skip Intro" button during detected segments. Fall back gracefully if no intro data exists. | Must-have |
| Chapter support | Display chapter markers on the scrubber. Allow jumping between chapters from a chapters panel overlay. | Must-have |
| Next episode auto-play | Auto-advance to the next episode with a countdown overlay (configurable delay or opt-out). Mark the previous episode as watched. | Must-have |
| Playback quality settings | Let users set a max bitrate and toggle "prefer direct play." Surface current playback stats (codec, resolution, bitrate, direct play vs transcode) in a debug overlay. | Must-have |
| Resume playback reliability | Harden position reporting and resume logic. Handle edge cases: server restarts, interrupted sessions, position drift. | Must-have |

**Dependencies:** Intro Skipper plugin installed on the Jellyfin server for skip intro. Chapter data depends on media being properly tagged (most Blu-ray rips include this).

### UI Polish

| Feature | Description | Priority |
|---|---|---|
| Parallax poster effects | Add the native tvOS parallax/floating effect to poster artwork, matching the feel of Apple's own TV app. | Must-have |
| Richer transitions | Smooth hero animations between list and detail views. Fade and scale transitions when navigating between sections. | Nice-to-have |
| Backdrop blur effects | Use blurred backdrop artwork behind metadata and playback controls for visual depth. | Nice-to-have |
| Loading states | Skeleton views and shimmer animations instead of spinners. | Nice-to-have |

**Dependencies:** None. Pure UI work.

### Accessibility

| Feature | Description | Priority |
|---|---|---|
| VoiceOver support | Full VoiceOver compatibility: meaningful labels on all interactive elements, logical focus order, playback state announcements. | Must-have |
| Dynamic type | Respect the system text size preference where applicable on tvOS. | Nice-to-have |

**Dependencies:** None. Should be woven into all new UI work going forward.

### State Management & User Features

| Feature | Description | Priority |
|---|---|---|
| Watched/unwatched management | Toggle watched state from detail views and long-press context menus. Batch mark seasons as watched. | Must-have |
| Favorites | Mark items as favorites. Surface a "Favorites" row on the home screen. | Must-have |
| Multiple user profiles | Profile selection screen at launch (per-server, using Jellyfin's built-in user system). Quick-switch without re-entering the server URL. | Must-have |
| Continue watching improvements | Smarter ordering, ability to dismiss items from the row. | Nice-to-have |

**Dependencies:** None beyond v1 auth flow.

### Performance & Reliability

| Feature | Description | Priority |
|---|---|---|
| Image prefetching | Preload artwork for visible and near-visible items. Cache aggressively; respect memory limits. | Must-have |
| View preloading | Begin loading detail view data when an item gains focus, not on selection. Reduces perceived latency. | Nice-to-have |
| Memory optimization | Profile and cap image cache size. Ensure background views are properly deallocated. | Must-have |
| Offline detection | Detect when the Jellyfin server is unreachable. Show cached content where possible, with clear "offline" messaging. Retry automatically. | Must-have |
| Error handling | Replace generic errors with actionable messages. Gracefully handle auth expiry, server version mismatches, missing media. | Must-have |

**Dependencies:** None.

---

## v2.0 — Athion Integration

This is the architectural inflection point. Aether stops being a standalone Jellyfin client and becomes a first-class citizen of the Athion ecosystem, alongside Liminal, Flux, and OpenDock.

### Single Sign-On

| Feature | Description | Priority |
|---|---|---|
| SSO via athion.me | Authenticate through the centralized Athion identity provider. One account, one login, across all Athion apps. | Must-have |
| Jellyfin credential linking | The Athion account stores associated Jellyfin server credentials. Users connect their Jellyfin instance once through Athion and never see a separate Jellyfin login in Aether again. | Must-have |
| Token management | Securely store and refresh Athion tokens. Handle token expiry, revocation, and re-auth flows. | Must-have |
| Migration path | Existing v1.x users with direct Jellyfin logins should be guided through a smooth migration to Athion SSO. Support both auth methods during a transition period. | Must-have |

**Dependencies:** Athion SSO service must be built and deployed. OAuth2/OIDC flow design. Shared auth library across Athion apps.

### Multi-Server Support

| Feature | Description | Priority |
|---|---|---|
| Multiple Jellyfin instances | Connect to more than one Jellyfin server simultaneously. Useful for users with separate servers for movies vs TV, or shared family setups. | Must-have |
| Unified library view | Optionally merge libraries from multiple servers into a single browsing experience, with clear server attribution. | Nice-to-have |
| Server health indicators | Show connection status and latency per server in settings. | Nice-to-have |

**Dependencies:** Athion SSO (credentials for multiple servers stored in the Athion account).

### Athion Design Language

| Feature | Description | Priority |
|---|---|---|
| Unified branding | Align Aether's visual identity with the broader Athion design system — color palette, typography, iconography, motion principles. | Must-have |
| Shared UI components | Extract common patterns (navigation, settings, account management) into a shared SwiftUI package usable by future Athion apps. | Nice-to-have |
| Deep links | Support deep links from other Athion apps. Example: OpenDock could link directly to a movie's detail page in Aether. Define a URL scheme (e.g., `aether://media/{jellyfinItemId}`). | Nice-to-have |

**Dependencies:** Athion design system needs to be defined. Coordination across all Athion app projects.

### Shared Preferences

| Feature | Description | Priority |
|---|---|---|
| Cross-app preferences | Store user preferences (theme, language, accessibility settings) in the Athion account so they roam across all Athion apps and devices. | Nice-to-have |

**Dependencies:** Athion account service with a preferences API.

---

## v2.x — Advanced Media Features

Expand Aether beyond video-on-demand into a comprehensive media hub — live TV, music, audiobooks, photos. This is where the Jellyfin backend's full breadth gets exposed.

### Live TV & IPTV

| Feature | Description | Priority |
|---|---|---|
| EPG (Electronic Program Guide) | A grid-style guide showing channels and scheduled programming. Filterable by category. Sourced from Jellyfin's guide data. | Must-have |
| Channel surfing | Tune into live channels with quick up/down channel switching. Overlay with current/next program info. | Must-have |
| DVR / recording | Schedule recordings from the guide. Manage recording rules (record series, new episodes only, etc). View and manage existing recordings. | Nice-to-have |
| IPTV provider setup | In-app flow to add IPTV providers (M3U playlists, Xtream Codes) to the Jellyfin server. Alternatively, guide users through the Jellyfin dashboard setup. | Nice-to-have |

**Dependencies:** Jellyfin Live TV & DVR plugin configured on the server. IPTV tuner setup (e.g., xTeVe or Jellyfin's built-in tuner). Guide data source (XMLTV or provider-supplied).

### Music Playback

| Feature | Description | Priority |
|---|---|---|
| Library browsing | Browse by album, artist, genre, playlist. Album art grid with playback controls. | Must-have |
| Now playing | Full-screen now-playing view with artwork, playback controls, and a queue. | Must-have |
| Background audio | Continue music playback while navigating other parts of the app. | Must-have |
| Playlists | Create, edit, and manage playlists. | Nice-to-have |
| Lyrics | Display synced lyrics if available in metadata. | Nice-to-have |

**Dependencies:** Music library configured in Jellyfin. Audio codec support in the playback pipeline.

### Other Media Types

| Feature | Description | Priority |
|---|---|---|
| Audiobook support | Browse and play audiobooks. Track chapter progress. Sleep timer. | Nice-to-have |
| Photo library | Browse photo libraries from Jellyfin. Slideshow mode with Ken Burns effect — great for Apple TV as an ambient display. | Nice-to-have |

**Dependencies:** Respective libraries configured in Jellyfin.

### Collections & Playlists

| Feature | Description | Priority |
|---|---|---|
| Collections management | View and manage Jellyfin collections (e.g., "Marvel Cinematic Universe"). Create new collections from Aether. | Must-have |
| Video playlists | Queue up movies or episodes into an ad-hoc playlist for a viewing session. | Nice-to-have |

**Dependencies:** None beyond v1.

### Advanced Audio & Video

| Feature | Description | Priority |
|---|---|---|
| Subtitle styling | Customize subtitle font, size, color, background. Per-profile preferences. | Must-have |
| Subtitle offset adjustment | Fine-tune subtitle timing with +/- offset controls during playback. | Nice-to-have |
| External subtitle search | Search for and download subtitles from OpenSubtitles or similar, via Jellyfin's subtitle provider plugins. | Nice-to-have |
| HDR / Dolby Vision passthrough | Ensure proper HDR10, HDR10+, and Dolby Vision metadata passthrough to the Apple TV's video pipeline. Test and optimize per-format. | Must-have |
| Dolby Atmos passthrough | Bitstream Atmos audio to compatible receivers/soundbars. Verify E-AC3 JOC passthrough. | Must-have |

**Dependencies:** Apple TV 4K hardware. HDR/DV content in the library. Receiver or soundbar for Atmos testing. Direct play is critical here — transcoding strips HDR/Atmos metadata.

---

## v3.0 — Social & Multi-Device

Introduce social features and break Aether out of the single-device model.

### Social Features

| Feature | Description | Priority |
|---|---|---|
| SyncPlay | Watch together with other Jellyfin users. Synchronized playback with shared controls. Uses Jellyfin's built-in SyncPlay API. | Must-have |
| Watch history sharing | Optionally share what you have been watching with other users on the same server. Activity feed on the home screen. | Nice-to-have |
| Recommendations | Surface "Because you watched X" suggestions. Start with Jellyfin's built-in suggestion API, potentially enhance with local heuristics. | Nice-to-have |

**Dependencies:** SyncPlay requires Jellyfin server support (available since 10.7). Multiple active users on the server for social features to be meaningful.

### Multi-Device

| Feature | Description | Priority |
|---|---|---|
| Handoff | Start watching on Apple TV, pick up on iPhone/iPad (or vice versa) — if the iOS companion app exists. Uses Jellyfin's playback position sync, enhanced with Apple's Handoff framework. | Nice-to-have |
| Companion app (iPhone as remote) | Use an iPhone as an enhanced remote: browse and search with a keyboard, queue content, control playback. Communicates with the tvOS app over the local network. | Nice-to-have |
| Push notifications | Notify users when new content is added to their libraries. Configurable per-library. Requires a lightweight notification relay service. | Nice-to-have |

**Dependencies:** iOS app (see v3.x). Notification service infrastructure (could be an Athion-level service). Handoff requires shared Apple ecosystem (same iCloud account).

---

## v3.x — Platform Expansion

Bring the Aether experience beyond Apple TV to the rest of Apple's platforms.

### iOS / iPadOS

| Feature | Description | Priority |
|---|---|---|
| iPhone app | Adapted UI for iPhone. Focus on browsing, managing libraries, and playback. Shared codebase via SwiftUI with platform-specific adaptations. | Must-have |
| iPad app | Take advantage of the larger screen. Split-view browsing, picture-in-picture playback. | Must-have |

**Dependencies:** Significant UI adaptation work. Shared networking/data layer from the tvOS app. App Store review considerations.

### macOS

| Feature | Description | Priority |
|---|---|---|
| macOS app | Native SwiftUI macOS app (not Catalyst). Menu bar integration, keyboard shortcuts, windowed and full-screen playback. | Nice-to-have |

**Dependencies:** SwiftUI multiplatform project structure. macOS-specific playback pipeline considerations.

### System Integration

| Feature | Description | Priority |
|---|---|---|
| Widgets | iOS/macOS widgets: recently added media, now playing, continue watching. | Nice-to-have |
| Shortcuts | Siri Shortcuts integration. "Play the next episode of X" or "Show me new movies." | Nice-to-have |
| CarPlay | If music playback is implemented, expose it via CarPlay for in-car listening. | Nice-to-have |

**Dependencies:** Music playback (v2.x) for CarPlay. WidgetKit, App Intents frameworks.

---

## Infrastructure & Homelab Considerations

Aether is built and tested against a homelab-hosted Jellyfin instance. These considerations ensure the infrastructure supports the app's evolution.

### Transcoding & Direct Play

The Proxmox host runs on an AMD Ryzen 9 9950X3D with 64GB RAM. This CPU has no integrated GPU, which means hardware-accelerated transcoding (QSV, NVENC) is not available without a dedicated GPU. Implications:

- **Prefer direct play.** Aether should aggressively prefer direct play and direct stream. The Apple TV 4K supports a wide range of codecs natively (H.264, H.265/HEVC, VP9, AV1 on newer models). Most well-encoded media should play without transcoding.
- **Software transcoding as fallback.** The 9950X3D is a beast for CPU-based transcoding if needed, but it is wasteful compared to hardware encode. Monitor for cases where transcoding kicks in unnecessarily and fix the root cause (usually a subtitle burn-in or incompatible audio codec).
- **Future GPU passthrough.** If transcoding demand grows (more users, live TV transcoding), consider passing a dedicated GPU through to the Jellyfin VM. The Proxmox host supports PCIe passthrough.

### Network Optimization

New network gear arriving around 2026-03-28 opens up:

| Improvement | Description | Priority |
|---|---|---|
| VLANs | Isolate media streaming traffic onto its own VLAN. Prevents congestion from other homelab workloads. | Must-have |
| Static IPs | Assign stable IPs to the Jellyfin VM and Apple TV. Eliminates DNS/DHCP flakiness. | Must-have |
| QoS | Prioritize streaming traffic (especially 4K HDR, which can peak at 80+ Mbps for remuxes). | Nice-to-have |
| Jumbo frames | If all devices on the media VLAN support it, enable jumbo frames (9000 MTU) for reduced overhead on large transfers. | Nice-to-have |

### Testing Infrastructure

| Improvement | Description | Priority |
|---|---|---|
| Dedicated test Jellyfin instance | Spin up a second Jellyfin LXC/VM on the Proxmox host for testing. Populate with a controlled set of media covering edge cases (4K HDR, Atmos, subtitles, multi-episode series, live TV). Keeps the production library untouched. | Nice-to-have |
| Monitoring | Track streaming metrics: buffering events, transcode frequency, playback errors. Could feed into a Grafana dashboard alongside existing homelab monitoring. | Nice-to-have |

### Existing Homelab Context

- **VM 100:** Jellyfin (Debian 13) at 192.168.0.159 — the primary media server.
- **LXC 102:** Flux — another Athion service, already running.
- **LXC 103:** Minecraft — unrelated but shares resources.

Aether does not directly interact with the Proxmox layer, but understanding the infrastructure helps inform decisions about transcoding strategy, network architecture, and resource allocation.

---

## Timeline Perspective

This roadmap is deliberately aspirational. Rough sequencing:

- **v1.x** can begin immediately after v1 ships. These are incremental improvements with no external dependencies.
- **v2.0** is gated on the Athion SSO infrastructure. That work spans multiple projects and is a larger undertaking.
- **v2.x** features can be developed in parallel with v2.0 since they are mostly independent of Athion integration.
- **v3.0 and beyond** are longer-horizon. Social features and multi-device support depend on having a meaningful user base and the iOS/iPadOS apps to make handoff worthwhile.

The phases are not strictly sequential — features from later phases can be pulled forward if priorities shift. The version numbers represent thematic groupings, not rigid gates.
