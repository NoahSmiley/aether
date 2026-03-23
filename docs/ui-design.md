# Aether — UI/UX Design Document

**Platform:** Apple TV (tvOS 18+)
**Framework:** SwiftUI
**Input:** Siri Remote (focus-based navigation)
**Version:** 1.0

---

## Table of Contents

1. [Design Principles](#1-design-principles)
2. [Navigation Architecture](#2-navigation-architecture)
3. [Screen-by-Screen Layouts](#3-screen-by-screen-layouts)
4. [Focus & Interaction Patterns](#4-focus--interaction-patterns)
5. [Typography & Spacing](#5-typography--spacing)
6. [Animations & Transitions](#6-animations--transitions)
7. [Color Palette](#7-color-palette)

---

## 1. Design Principles

### Cinematic & Content-Forward

Aether treats the television as a canvas for media artwork. Every design decision should ask: "Does this let the content speak?" The interface is a frame, not a destination. Posters, backdrops, and logos are the primary visual language — UI chrome exists only to orient the user and expose actions.

### 10-Foot UI

The screen is viewed from 8-12 feet away on a couch. This constraint dictates everything:

- **Large type.** Body text starts at 29pt. Nothing falls below 25pt.
- **High contrast.** Pure white on near-black. No subtle grays for critical information.
- **Generous spacing.** Elements need room to breathe. Dense layouts feel cluttered at distance.
- **Obvious focus states.** The user must always know where they are. Focus is communicated through scale, elevation, and brightness — not thin outlines.

### Minimal Chrome

- No persistent navigation bars eating screen space during browsing.
- Tab bar collapses to icons when a tab is active (tvOS sidebar behavior).
- Toolbars, filters, and sort controls appear contextually and recede when not in use.
- The player has zero persistent UI — all controls are summoned by interaction.

### Dark by Default

The room is dark. The TV is the brightest object. A dark theme reduces eye strain, makes artwork pop, and feels native to the home theater context. There is no light mode in v1.

### Artwork Hierarchy

Jellyfin provides multiple image types. Aether uses them with clear intent:

| Image Type | Primary Use |
|---|---|
| **Backdrop** | Hero banners, detail screen headers, player background |
| **Primary (Poster)** | Grid items, row items, search results |
| **Logo** | Overlaid on backdrops (detail screens, hero banner) in place of plain text titles when available |
| **Thumb** | Episode thumbnails, "Continue Watching" row items |
| **Banner** | Not used in v1 (reserved for future horizontal list layouts) |

When a logo image is available, always prefer it over rendering the title as text on backdrop-based layouts. Logos are designed by studios to be legible over imagery and feel far more cinematic.

---

## 2. Navigation Architecture

### Top-Level: TabView (Sidebar Style)

tvOS 18+ supports `TabView` with `.sidebarAdaptable` style. Aether uses this as its root navigation:

```
TabView (sidebar style)
 ├── Home
 ├── Movies
 ├── TV Shows
 ├── Search
 └── Settings
```

**Behavior:**

- The sidebar is visible when the user presses the **Menu** button at the root of any tab, or swipes to the leading edge.
- When collapsed, the sidebar renders as a row of icons pinned to the top-left of the screen. These icons are semi-transparent and do not occlude content.
- Tab icons use SF Symbols: `house.fill`, `film.fill`, `tv.fill`, `magnifyingglass`, `gearshape.fill`.
- The active tab icon is highlighted with the accent color.

### Drilling: NavigationStack

Each tab contains its own `NavigationStack`. Navigation is linear:

```
Home
 └── Detail (Movie or Show)
      └── Player

Movies
 └── Detail (Movie)
      └── Player

TV Shows
 └── Detail (Show)
      └── Detail (Episode) [optional, or play directly]
           └── Player
```

### Back Navigation

- **Menu button** on the Siri Remote pops the current view from the `NavigationStack`.
- At a tab's root view, **Menu** opens/focuses the sidebar.
- At the sidebar level with no deeper view, **Menu** does nothing (tvOS default; the system handles app backgrounding on Home button press).

### Deep Linking

The app should support deep-linking to any detail view or directly into playback. This is a future consideration but the `NavigationStack` path-based API supports it natively.

---

## 3. Screen-by-Screen Layouts

### 3.1 Server Setup

**Purpose:** First-launch screen. The user provides the URL of their Jellyfin server.

**Layout:**

```
┌─────────────────────────────────────────────────┐
│                                                 │
│                                                 │
│              ┌───────────────────┐              │
│              │    Aether Logo    │              │
│              │                   │              │
│              │  ┌─────────────┐  │              │
│              │  │ Server URL  │  │              │
│              │  └─────────────┘  │              │
│              │                   │              │
│              │   [ Connect ]     │              │
│              │                   │              │
│              │   Status text     │              │
│              └───────────────────┘              │
│                                                 │
│                                                 │
└─────────────────────────────────────────────────┘
```

**Details:**

- Vertically and horizontally centered card on a dark, subtly textured background (very faint radial gradient from center, e.g., `#1A1A1A` to `#0D0D0D`).
- **App logo** ("Aether") at the top of the card in a custom wordmark or SF Pro Display Light at 52pt.
- **Server URL text field:** Standard tvOS text input. Placeholder text reads `https://your-server.com`. The field receives focus by default on screen load.
- **Connect button:** Pill-shaped, accent-colored background. Text: "Connect". Positioned below the text field with 24pt spacing.
- **Status area** below the button (32pt spacing):
  - *Connecting:* Spinner with "Connecting..." label.
  - *Success:* Server name and version displayed (e.g., "Jellyfin Server — v10.9.6") with a checkmark icon in green. After a 1.5-second pause, automatically transition to the Login screen.
  - *Error:* Red text describing the failure ("Could not reach server" / "Not a valid Jellyfin server"). The URL field re-focuses for correction.
- The card has no visible border. It is implied by the layout and the background gradient drawing the eye to center. If the card needs definition, use a 1pt border of `#FFFFFF` at 6% opacity.

**Focus order:** URL field -> Connect button.

---

### 3.2 Login

**Purpose:** Authenticate the user against the connected server.

**Layout:**

```
┌─────────────────────────────────────────────────┐
│                                                 │
│          Server Name  •  server-url.com         │
│                                                 │
│              ┌───────────────────┐              │
│              │                   │              │
│              │  ┌─────────────┐  │              │
│              │  │  Username   │  │              │
│              │  └─────────────┘  │              │
│              │                   │              │
│              │  ┌─────────────┐  │              │
│              │  │  Password   │  │              │
│              │  └─────────────┘  │              │
│              │                   │              │
│              │   [ Sign In ]     │              │
│              │                   │              │
│              │   Error message   │              │
│              └───────────────────┘              │
│                                                 │
│         [ Change Server ]                       │
└─────────────────────────────────────────────────┘
```

**Details:**

- **Server info** displayed at the top of the screen (not inside the card): server name on the left, server URL on the right, separated by a dot divider. Styled in secondary text color at 25pt. This reassures the user which server they are connecting to.
- **Username field:** Placeholder "Username". Receives default focus.
- **Password field:** Secure entry. Placeholder "Password".
- **Sign In button:** Same pill style as Connect. Accent background.
- **Error states:**
  - "Invalid username or password" — displayed in red below the Sign In button. The username field re-focuses.
  - "Server unreachable" — displayed with a retry affordance.
- **Change Server** button in the bottom-left corner (tertiary style, text-only). Returns to Server Setup and clears the stored server.
- On successful login, transition to the Home screen. The transition should feel like "opening the curtain" — a crossfade with a subtle scale-up from 0.97 to 1.0 on the Home view.

**Focus order:** Username -> Password -> Sign In. "Change Server" is reachable by navigating down past Sign In.

---

### 3.3 Home

**Purpose:** The landing screen. Surfaces featured, in-progress, and recent content to get the user watching quickly.

**Layout:**

```
┌─────────────────────────────────────────────────┐
│                                                 │
│  ┌─────────────────────────────────────────┐    │
│  │                                         │    │
│  │         HERO BANNER (backdrop)          │    │
│  │                                         │    │
│  │     [Logo Image]                        │    │
│  │     Year • Rating • Runtime             │    │
│  │                                         │    │
│  │     [ ▶ Play ]   [ ℹ More Info ]        │    │
│  │                                         │    │
│  └─────────────────────────────────────────┘    │
│                                                 │
│  Continue Watching                               │
│  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ...  │
│  │thumb│ │thumb│ │thumb│ │thumb│ │thumb│       │
│  │▓▓▓░░│ │▓░░░░│ │▓▓▓▓░│ │▓▓░░░│ │▓░░░░│       │
│  │Title│ │Title│ │Title│ │Title│ │Title│       │
│  └─────┘ └─────┘ └─────┘ └─────┘ └─────┘       │
│                                                 │
│  Recently Added                                  │
│  ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐ ...     │
│  │   │ │   │ │   │ │   │ │   │ │   │          │
│  │pos│ │pos│ │pos│ │pos│ │pos│ │pos│          │
│  │ter│ │ter│ │ter│ │ter│ │ter│ │ter│          │
│  │   │ │   │ │   │ │   │ │   │ │   │          │
│  └───┘ └───┘ └───┘ └───┘ └───┘ └───┘          │
│  Title  Title  Title  Title  Title  Title       │
│                                                 │
│  [Library Name Row]...                           │
│  [Library Name Row]...                           │
│                                                 │
└─────────────────────────────────────────────────┘
```

#### Hero Banner

- **Dimensions:** Full width of the screen. Height is 65% of the screen height (approximately 700pt on 1080p).
- **Content:** A randomly selected featured item (movie or show from the user's libraries).
- **Background:** The item's **backdrop** image, edge-to-edge. Apply a gradient overlay from the bottom: transparent at 40% height, fading to the screen background color (`#0D0D0D`) at the bottom edge. This allows the rows below to blend seamlessly.
- **Overlay content** (bottom-left, 80pt from the left edge, 60pt from the bottom of the banner):
  - **Logo image** if available, max width 400pt, max height 120pt, maintaining aspect ratio. If no logo, render the title in SF Pro Display Bold at 56pt.
  - **Metadata line** below the logo/title (12pt spacing): Year, content rating (e.g., PG-13), runtime (e.g., "2h 14m") — separated by bullet characters (`•`). Styled in secondary text at 25pt.
  - **Buttons row** (20pt below metadata):
    - **Play** button: Filled pill, accent color background, SF Symbol `play.fill` + "Play" label. This is the default focused element when the Home screen loads.
    - **More Info** button: Outline pill, 1pt white border at 30% opacity, SF Symbol `info.circle` + "More Info" label. Navigates to the Detail screen.
- **Auto-advancement:** The hero banner cycles to a new featured item every 8 seconds. The transition is a crossfade (0.6s duration). Cycling pauses when the user focuses on the Play or More Info buttons. A row of small dot indicators at the bottom-right of the banner shows the current position (max 5-7 items in rotation).
- **Parallax:** When the hero banner area is focused, the backdrop image should exhibit a subtle parallax tilt effect following the touch surface of the Siri Remote (matching the native tvOS poster behavior).

#### Continue Watching Row

- **Visibility:** Only shown if the user has items with playback progress.
- **Row label:** "Continue Watching" in SF Pro Display Medium at 31pt, left-aligned, 80pt from left edge.
- **Items:** Horizontal scroll (`ScrollView(.horizontal)` with `LazyHStack`).
- **Each item:**
  - **Thumb image** with 16:9 aspect ratio, 300pt width, 169pt height. Corner radius 12pt.
  - **Progress bar** overlaid on the bottom of the thumb. Height 4pt. Background: white at 20% opacity. Fill: accent color. The bar spans the full width of the thumb (inset by the corner radius).
  - **Title** below the thumb (8pt spacing): For movies, the movie title. For episodes, the format is "S2:E5 Episode Title". SF Pro Text Regular at 25pt, secondary text color. Truncated to one line.
  - **Show name** (episodes only): Below the episode title, SF Pro Text Regular at 23pt, tertiary text color.
- **Spacing between items:** 40pt.
- **Row left padding:** 80pt (aligned with section label).

#### Recently Added Row

- **Row label:** "Recently Added" — same style as Continue Watching label.
- **Items:** Horizontal scroll.
- **Each item:**
  - **Primary (poster)** image with 2:3 aspect ratio, 200pt width, 300pt height. Corner radius 10pt.
  - **Title** below the poster (8pt spacing): SF Pro Text Regular at 25pt, primary text color. Truncated to one line.
  - **Year** below the title (2pt spacing): SF Pro Text Regular at 23pt, secondary text color.
- **Spacing between items:** 40pt.
- **Row left padding:** 80pt.
- **New badge:** Items added within the last 48 hours display a small accent-colored dot (8pt diameter) in the top-right corner of the poster, inset 8pt from both edges.

#### Library Rows

- One row per Jellyfin library. Row label is the library name (e.g., "4K Movies", "Anime").
- Items within each row follow the same poster card layout as Recently Added.
- Libraries are sorted by the order configured on the server.
- Each row shows the latest items from that library.

#### Scrolling Behavior

- The entire Home screen is a single vertical `ScrollView`.
- As the user scrolls down (by moving focus to lower rows), the hero banner scrolls off the top and the rows scroll up naturally.
- When the hero banner is partially off-screen, it should not clip abruptly — the gradient ensures a smooth visual blend.

---

### 3.4 Library (Movies)

**Purpose:** Browse the full movie library with sort and filter controls.

**Layout:**

```
┌─────────────────────────────────────────────────┐
│                                                 │
│  Movies           Sort: Date Added ▾  Filter ▾  │
│                                                 │
│  ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐         │
│  │   │ │   │ │   │ │   │ │   │ │   │          │
│  │   │ │   │ │ F │ │   │ │   │ │   │          │
│  │   │ │   │ │   │ │   │ │   │ │   │          │
│  │   │ │   │ │   │ │   │ │   │ │   │          │
│  └───┘ └───┘ └───┘ └───┘ └───┘ └───┘          │
│  Title  Title  Title  Title  Title  Title       │
│                       2024                      │
│  ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐         │
│  │   │ │   │ │   │ │   │ │   │ │   │          │
│  │   │ │   │ │   │ │   │ │   │ │   │          │
│  │   │ │   │ │   │ │   │ │   │ │   │          │
│  │   │ │   │ │   │ │   │ │   │ │   │          │
│  └───┘ └───┘ └───┘ └───┘ └───┘ └───┘          │
│  ...                                            │
└─────────────────────────────────────────────────┘
```

**Details:**

- **Title bar:** "Movies" in SF Pro Display Bold at 38pt, left-aligned at 80pt. Sort and filter controls are right-aligned in the same row.
- **Sort button:** Displays the current sort field (default "Date Added"). On click, presents a dropdown/overlay with options:
  - Title (A-Z / Z-A)
  - Date Added (Newest / Oldest)
  - Release Year (Newest / Oldest)
  - Community Rating (Highest / Lowest)
  - Critic Rating (Highest / Lowest)
- **Filter button:** On click, presents an overlay panel with:
  - **Genre:** Multi-select list of all genres present in the library.
  - **Year:** Range or discrete selection.
  - **Watched status:** All / Unwatched / Watched.
  - Active filters are indicated by a badge count on the Filter button (e.g., "Filter (2)").
- **Grid layout:** `LazyVGrid` with adaptive columns, minimum width 200pt per column. On a 1920x1080 screen this produces approximately 6-7 columns.
- **Each grid item:**
  - Primary poster image, 2:3 aspect ratio, corner radius 10pt.
  - Title below the poster, 25pt, primary text color, single line, truncated with ellipsis.
- **Focused item behavior:**
  - Scales up to 1.08x.
  - Elevation increases (shadow: black at 50% opacity, 20pt blur, 10pt y-offset).
  - A **title and year overlay** appears below the scaled poster: the title in 27pt bold and the year in 25pt secondary, sliding in with a 0.2s ease-out animation.
  - Adjacent items shift outward slightly to accommodate the scale without overlap.
- **Watched indicator:** Movies that have been watched display a small checkmark badge in the bottom-right corner of the poster (white checkmark on a dark semi-transparent circle, 28pt diameter).

**Focus order:** The grid is the primary focus area. Pressing up from the top row moves focus to the Sort/Filter controls. Pressing up from Sort/Filter does nothing (top of screen). The sidebar is accessible via the Menu button.

---

### 3.5 Library (TV Shows)

**Purpose:** Browse the TV show library.

**Layout:** Identical grid structure to the Movies library (section 3.4) with the following differences:

- **Title bar:** "TV Shows" instead of "Movies".
- **Sort options:** Same set, plus "Premiere Date".
- **Filter options:** Same set, plus "Status" (Continuing / Ended).
- **Unwatched badge:** Shows with unwatched episodes display a badge in the top-right corner of the poster. The badge is a rounded rectangle (min-width 28pt, height 28pt, corner radius 14pt) with the accent color background and white text showing the unwatched episode count (e.g., "3", "12"). If the count exceeds 99, display "99+".
- **Fully watched indicator:** Shows where all episodes are watched display the same checkmark badge as movies.
- Clicking a show navigates to the TV Show Detail screen.

---

### 3.6 Detail (Movie)

**Purpose:** Display full information about a movie and provide the primary entry point to playback.

**Layout:**

```
┌─────────────────────────────────────────────────┐
│                                                 │
│         BACKDROP (full width, top-aligned)       │
│                                                 │
│     ┌──────────────────────────────────────┐    │
│     │  Gradient overlay (bottom fade)      │    │
│     │                                      │    │
│     │  [Logo Image]                        │    │
│     │  2024 • PG-13 • 2h 14m • 8.1★       │    │
│     │  Action, Thriller, Sci-Fi            │    │
│     │                                      │    │
│     │  [ ▶ Play ]  [ ▷ Trailer ]           │    │
│     └──────────────────────────────────────┘    │
│                                                 │
│  Overview                                        │
│  "A retired assassin is pulled back into the     │
│  underworld when..."                             │
│                                                 │
│  Cast & Crew                                     │
│  ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐         │
│  │ O │ │ O │ │ O │ │ O │ │ O │ │ O │          │
│  │   │ │   │ │   │ │   │ │   │ │   │          │
│  │Nme│ │Nme│ │Nme│ │Nme│ │Nme│ │Nme│          │
│  │Rol│ │Rol│ │Rol│ │Rol│ │Rol│ │Rol│          │
│  └───┘ └───┘ └───┘ └───┘ └───┘ └───┘          │
│                                                 │
│  Similar Movies                                  │
│  ┌───┐ ┌───┐ ┌───┐ ┌───┐ ...                   │
│                                                 │
└─────────────────────────────────────────────────┘
```

**Details:**

#### Header (Backdrop Area)

- **Backdrop image:** Full screen width, 60% of screen height. Top-aligned (flush with the top edge of the screen, no top padding).
- **Gradient overlay:** A compound gradient:
  - Bottom: `#0D0D0D` at 100% opacity from the bottom edge to 40% up the backdrop.
  - Left: `#0D0D0D` at 70% opacity on the left 30% of the image (ensures text legibility over bright backdrops).
  - Overall: A subtle vignette.
- **Logo/Title:** Positioned in the bottom-left of the backdrop area, 80pt from left, 40pt from the bottom of the backdrop.
  - Use the **Logo** image if available (max width 450pt, max height 130pt).
  - Fallback: Title text in SF Pro Display Bold at 52pt, white, with a subtle text shadow (2pt blur, 50% black).
- **Metadata line** (12pt below logo/title): Year, content rating, runtime, community rating (with a star icon). Each separated by `•`. SF Pro Text Regular at 25pt, secondary text color.
- **Genre line** (8pt below metadata): Comma-separated genres. SF Pro Text Regular at 25pt, secondary text color.
- **Action buttons** (24pt below genres):
  - **Play:** Filled accent-color pill. SF Symbol `play.fill` + "Play". This receives default focus.
  - **Trailer:** Outlined pill (1pt white border, 20% opacity). SF Symbol `play.rectangle` + "Trailer". Only visible if a trailer URL is available from Jellyfin.
  - **Watched toggle:** Icon-only circular button. SF Symbol `checkmark.circle` (unwatched) or `checkmark.circle.fill` (watched). Toggles watched state on click.
  - **Favorite toggle:** Icon-only circular button. SF Symbol `heart` (not favorited) or `heart.fill` (favorited).

#### Body (Below Backdrop)

- **Overview section:**
  - Section label: "Overview" in SF Pro Display Medium at 29pt, primary text.
  - Synopsis text: SF Pro Text Regular at 27pt, secondary text color. Max 4 lines visible by default. If truncated, the full text is revealed when the overview area receives focus and the user clicks, expanding inline with animation.
  - Left padding: 80pt. Right padding: 80pt. Max width for text: 900pt (prevent ultra-wide lines that are hard to read).

- **Cast & Crew row:**
  - Section label: "Cast & Crew" — same style as Overview label.
  - Horizontal scroll.
  - Each cast member:
    - **Circular headshot** (Primary image from Jellyfin person data), 120pt diameter. If no image, show a placeholder circle with initials.
    - **Name** below the circle (8pt spacing): SF Pro Text Medium at 23pt, primary text, centered, one line.
    - **Role/Character** below the name (2pt spacing): SF Pro Text Regular at 21pt, secondary text, centered, one line.
  - Spacing between cast items: 32pt.

- **Similar Movies row (optional):**
  - Section label: "Similar" — same label style.
  - Horizontal scroll of poster cards, same format as library rows.
  - Sourced from Jellyfin's "Similar Items" API endpoint.

- **Additional metadata (bottom of page):**
  - Studio(s), production year, external IDs (IMDB link icon), resolution/quality info (e.g., "4K HDR" badge).
  - Displayed as a muted metadata block in 23pt tertiary text.

---

### 3.7 Detail (TV Show)

**Purpose:** Display show information with season/episode navigation.

**Layout:** Same backdrop header structure as Movie Detail (section 3.6), with the following differences and additions:

#### Header Differences

- Metadata line includes: first air year (or year range if ended, e.g., "2019-2023"), content rating, number of seasons (e.g., "5 Seasons"), community rating.
- **Play button** label changes based on state:
  - New show (no progress): "Play S1:E1"
  - In progress: "Continue S2:E5" (next unwatched episode)
- **Trailer button** same behavior as movie detail.

#### Season Picker

Positioned directly below the action buttons, above the episode list:

```
  [ Season 1 ]  [ Season 2 ]  [ Season 3 ]  [ Season 4 ]
```

- Horizontal row of pill-shaped buttons.
- **Selected season:** Accent color fill, white text, bold.
- **Unselected seasons:** Transparent background, secondary text color, regular weight.
- Each pill: Corner radius 20pt, horizontal padding 24pt, height 40pt.
- Spacing between pills: 16pt.
- The currently relevant season is pre-selected (the season containing the next unwatched episode, or Season 1 for a new show).
- Scrollable horizontally if many seasons.

#### Episode List

Below the season picker, a vertical list of episodes:

```
┌─────────────────────────────────────────────────┐
│  ┌────────┐                                     │
│  │  Thumb  │  1. Pilot                          │
│  │  16:9   │  "Rick moves in with his daughter  │
│  │         │   and her family..."               │
│  │         │  44 min                      ✓     │
│  └────────┘                                     │
│─────────────────────────────────────────────────│
│  ┌────────┐                                     │
│  │  Thumb  │  2. Lawnmower Dog                  │
│  │  16:9   │  "Rick teaches Morty about the     │
│  │  ▓▓▓░░ │   dangers of..."                   │
│  │         │  23 min                            │
│  └────────┘                                     │
│─────────────────────────────────────────────────│
│  ...                                            │
└─────────────────────────────────────────────────┘
```

**Each episode row:**

- **Thumbnail:** Thumb image at 16:9 aspect ratio, 280pt width, 158pt height. Corner radius 8pt. Left-aligned at 80pt from screen edge.
  - If the episode has playback progress, a progress bar (same style as Continue Watching) is overlaid at the bottom of the thumbnail.
- **Episode number and title:** To the right of the thumb (24pt spacing). Format: "1. Episode Title" in SF Pro Text Semibold at 27pt, primary text.
- **Overview:** Below the title (6pt spacing). SF Pro Text Regular at 23pt, secondary text, max 2 lines, truncated.
- **Runtime:** Below the overview (6pt spacing). SF Pro Text Regular at 23pt, tertiary text. Formatted as "44 min".
- **Watched indicator:** A checkmark icon (SF Symbol `checkmark.circle.fill`) on the far right of the row, accent color, 24pt. Only displayed for watched episodes.
- **Row separator:** A horizontal line at 6% white opacity between rows.
- **Focus behavior:** The entire row is a single focusable unit. On focus, the row background brightens slightly (white at 5% opacity) and the thumbnail scales up to 1.04x. On click, playback begins for that episode.

#### Episode Row Focus Detail

When an episode row is focused and the user has not clicked yet, after a 1-second delay, the backdrop at the top of the screen crossfades to that episode's thumb image (if available) as a "preview." This gives the screen a dynamic feel as the user browses episodes.

---

### 3.8 Player

**Purpose:** Full-screen video playback with overlaid controls.

**Principles:** The player must be invisible by default. Controls appear only on interaction. Every control must be reachable within 2 remote actions.

#### Default State (Playing)

- Full-screen video. Zero UI elements visible.
- The status bar and any system overlays are hidden.

#### Transport Controls (Click or Swipe Down on Touchpad)

```
┌─────────────────────────────────────────────────┐
│                                                 │
│                  (video playing)                 │
│                                                 │
│                                                 │
│                                                 │
│                                                 │
│                                                 │
│  ┌─────────────────────────────────────────┐    │
│  │  Movie Title                            │    │
│  │                                         │    │
│  │  1:23:45 ━━━━━━━━━━━●───── -0:47:12    │    │
│  │                                         │    │
│  │       advancement controls               │    │
│  └─────────────────────────────────────────┘    │
│                                                 │
└─────────────────────────────────────────────────┘
```

**Details:**

- **Trigger:** A click on the touchpad surface (when no other element is focused) or a swipe down from the top edge.
- **Background:** A gradient scrim from the bottom (black at 80% opacity fading to transparent at 50% up the screen).
- **Title:** Movie title or "S2:E5 — Episode Title" at 29pt, SF Pro Text Medium, near the top of the transport bar area.
- **Scrubber bar:**
  - Full width minus 160pt (80pt padding each side).
  - Track: White at 15% opacity, 6pt height, fully rounded.
  - Played portion: White at 90% opacity.
  - Buffered portion: White at 30% opacity.
  - Playhead: Circular knob, 20pt diameter, white, with a subtle shadow.
  - The scrubber is focusable. When focused, swiping left/right on the touchpad scrubs the playhead. The speed of scrubbing increases the longer the user holds the swipe direction.
  - **Thumbnail preview:** While scrubbing, a thumbnail preview of the target timecode is shown above the playhead in a small 16:9 frame (200pt wide, rounded corners, subtle border).
- **Time labels:**
  - Left of the scrubber: Elapsed time (e.g., "1:23:45").
  - Right of the scrubber: Remaining time with a minus sign (e.g., "-0:47:12").
  - SF Pro Text Tabular Numbers at 23pt, secondary text.
- **Chapter markers (if available):** Small vertical tick marks on the scrubber track at chapter boundaries.
- **Auto-hide:** Transport controls disappear after 5 seconds of inactivity (fade out, 0.3s).

#### Playback Actions

- **Play/Pause:** Click the touchpad when transport is visible (or press the Play/Pause button on the Siri Remote at any time).
- **Seek forward 15s:** Press the right side of the touchpad clickpad, or press right on the outer ring. A "15s forward" icon briefly flashes on the right side of the screen.
- **Seek backward 15s:** Press the left side of the touchpad clickpad, or press left on the outer ring.
- **Skip intro:** When the Jellyfin server reports an intro segment (via the Intro Skipper plugin), a "Skip Intro" button appears in the bottom-right corner of the screen. It auto-appears at the intro start timecode and auto-hides at the intro end timecode. Styled as a capsule: semi-transparent dark background, white text, 27pt. Focused state: accent color background.
- **Skip credits/Next Episode:** Similar to Skip Intro. "Next Episode" button appears when credits begin. If the user does nothing, auto-advances to the next episode after a 15-second countdown (displayed as a circular progress ring around the button).

#### Info Panel (Swipe Up)

A swipe up on the touchpad (while playing or with transport visible) reveals the info panel, which slides in from the bottom as a full-width sheet:

```
┌─────────────────────────────────────────────────┐
│                                                 │
│  Audio                                           │
│  ● English (AAC 5.1)                            │
│    Japanese (AAC 2.0)                           │
│    English (DTS-HD MA 7.1)                      │
│                                                 │
│  Subtitles                                       │
│  ● None                                         │
│    English (SRT)                                │
│    English (PGS)                                │
│    Spanish (SRT)                                │
│                                                 │
│  Playback Info                                   │
│    Direct Play • 4K HEVC HDR • 45.2 Mbps       │
│                                                 │
└─────────────────────────────────────────────────┘
```

**Details:**

- **Audio track picker:** Lists all available audio tracks. Each row shows language, codec, and channel layout. The active track has an accent-colored radio indicator. Focus and click to switch.
- **Subtitle picker:** Lists all available subtitle tracks plus "None" at the top. Same radio-select behavior. The active subtitle is indicated.
- **Playback info:** Read-only. Shows whether the stream is direct playing or transcoding, video codec, resolution, HDR status, and bitrate.
- **Dismiss:** Swipe down or press Menu to close the info panel and return to playback.

---

### 3.9 Search

**Purpose:** Find content across all libraries.

**Layout:**

```
┌─────────────────────────────────────────────────┐
│                                                 │
│  ┌────────────────────────────────────────┐     │
│  │  Search Aether...                      │     │
│  └────────────────────────────────────────┘     │
│                                                 │
│  Movies (4 results)                              │
│  ┌───┐ ┌───┐ ┌───┐ ┌───┐                       │
│  │   │ │   │ │   │ │   │                        │
│  │   │ │   │ │   │ │   │                        │
│  └───┘ └───┘ └───┘ └───┘                       │
│                                                 │
│  TV Shows (2 results)                            │
│  ┌───┐ ┌───┐                                    │
│  │   │ │   │                                     │
│  │   │ │   │                                     │
│  └───┘ └───┘                                    │
│                                                 │
│  Episodes (7 results)                            │
│  ┌────────┐ ┌────────┐ ┌────────┐ ...          │
│  │ thumb  │ │ thumb  │ │ thumb  │               │
│  └────────┘ └────────┘ └────────┘               │
│                                                 │
│  People (3 results)                              │
│  (O) (O) (O)                                    │
│                                                 │
└─────────────────────────────────────────────────┘
```

**Details:**

- **Search field:** Full-width text input at the top. Placeholder: "Search Aether...". The tvOS virtual keyboard appears when this field is focused.
- **Results:** Update as the user types (debounced by 300ms to avoid excessive API calls).
- **Result categories:** Displayed as labeled rows, each with a horizontal scroll. Categories appear only when they have results:
  - **Movies:** Poster cards (same as library grid items).
  - **TV Shows:** Poster cards (same as library grid items).
  - **Episodes:** Thumb cards (16:9) with "S1:E3 Title" below and show name in secondary text.
  - **People:** Circular headshots with name below (same as cast row).
- **Empty state:** When the search field is empty, show recent searches (if any) as text chips below the field.
- **No results state:** Centered text "No results for '[query]'" in secondary text, with a suggestion to check the spelling.

**Focus order:** Search field (default) -> first result category -> next category, etc. Within a category, left/right scrolls items.

---

### 3.10 Settings

**Purpose:** App configuration and account management.

**Layout:**

```
┌─────────────────────────────────────────────────┐
│                                                 │
│  Settings                                        │
│                                                 │
│  ┌─────────────────────────────────────────┐    │
│  │  Server                                 │    │
│  │  Jellyfin Server — jellyfin.local:8096  │    │
│  │  Version 10.9.6                         │    │
│  └─────────────────────────────────────────┘    │
│                                                 │
│  ┌─────────────────────────────────────────┐    │
│  │  User                                   │    │
│  │  noah                                   │    │
│  └─────────────────────────────────────────┘    │
│                                                 │
│  ┌─────────────────────────────────────────┐    │
│  │  Playback                               │    │
│  │  Max Streaming Bitrate    [ Auto ▾ ]    │    │
│  │  Force Direct Play        [ Off  ▾ ]    │    │
│  │  Default Audio Language   [ English ▾]  │    │
│  │  Default Subtitle Mode    [ Auto ▾ ]    │    │
│  └─────────────────────────────────────────┘    │
│                                                 │
│  ┌─────────────────────────────────────────┐    │
│  │  Appearance                             │    │
│  │  Home Screen Rows         [ 10 ▾ ]      │    │
│  │  Episode Thumbnails       [ On ▾ ]      │    │
│  └─────────────────────────────────────────┘    │
│                                                 │
│  [ Sign Out ]                                    │
│                                                 │
│  Aether v1.0.0                                   │
│                                                 │
└─────────────────────────────────────────────────┘
```

**Details:**

- **Grouped list** layout with inset grouped styling (matches tvOS system Settings aesthetic).
- **Server section:** Read-only. Shows server name, URL, and version.
- **User section:** Read-only. Shows the current username and avatar (if set).
- **Playback section:**
  - **Max Streaming Bitrate:** Picker with options: Auto, 120 Mbps, 80 Mbps, 60 Mbps, 40 Mbps, 20 Mbps, 10 Mbps, 4 Mbps. Default: Auto.
  - **Force Direct Play:** Toggle (on/off). When on, the client requests direct play only and will not transcode. Default: off.
  - **Default Audio Language:** Picker with common languages. Default: device language.
  - **Default Subtitle Mode:** Picker: Off, Auto (show subtitles when audio language does not match content language), Always, Forced Only. Default: Auto.
- **Appearance section:**
  - **Home Screen Rows:** Number of library rows to display on the Home screen. Picker: 5, 10, 15, All. Default: 10.
  - **Episode Thumbnails:** Toggle. When off, episode rows use a compact text-only layout. Default: on.
- **Sign Out button:** Destructive style (red text). On click, presents a confirmation dialog ("Sign out of [server name]?" with "Sign Out" and "Cancel" buttons). Signing out clears stored credentials and returns to the Server Setup screen.
- **App version** at the very bottom, centered, in 21pt tertiary text.

---

## 4. Focus & Interaction Patterns

### 4.1 Focus Ring & Scale Behavior

tvOS does not use touch or cursor pointers. Focus is the primary interaction paradigm. Aether's focus behavior:

| Element Type | Focused Scale | Shadow | Other Effects |
|---|---|---|---|
| Poster card | 1.08x | 20pt blur, 50% black, 10pt y-offset | Title appears or brightens below |
| Thumbnail card | 1.05x | 16pt blur, 40% black, 8pt y-offset | — |
| Button (pill) | 1.05x | 12pt blur, 30% black, 6pt y-offset | Background brightens by 10% |
| Button (icon only) | 1.10x | 8pt blur, 25% black | Icon color transitions to accent |
| List row | 1.0x (no scale) | None | Background: white at 5% opacity |
| Text field | 1.0x | None | Border brightens to white at 40% |
| Season pill | 1.05x | 8pt blur, 25% black | — |
| Cast headshot | 1.10x | 12pt blur, 30% black | — |

All scale and shadow transitions use a spring animation: `response: 0.35, dampingFraction: 0.7`.

### 4.2 Long-Press Actions

Long-pressing (holding the touchpad for 1 second) on a focusable content item presents a context menu (tvOS `.contextMenu` modifier):

**On a Movie or Show poster:**
- Play (or Continue)
- Mark as Watched / Mark as Unwatched
- Add to Favorites / Remove from Favorites
- Go to Detail

**On an Episode row:**
- Play Episode
- Mark as Watched / Mark as Unwatched
- Play from Beginning (if has progress)

**On a Cast member:**
- View Filmography (navigates to a filtered view of items featuring this person)

Context menus use the native tvOS blurred background style with list items.

### 4.3 Siri Remote Mapping

| Remote Action | Context | App Behavior |
|---|---|---|
| **Touch surface click** | Any focused element | Select / activate |
| **Touch surface swipe** | Lists, grids, scroll views | Move focus in swipe direction |
| **Touch surface swipe** | Player (transport visible) | Scrub playhead |
| **Touch surface swipe down** | Player (transport hidden) | Show transport controls |
| **Touch surface swipe up** | Player | Show info panel (audio/subtitle) |
| **Menu button** | Any screen with NavigationStack depth > 0 | Pop (go back) |
| **Menu button** | Tab root screen | Open/focus sidebar |
| **Menu button** | Player transport/info visible | Dismiss overlay, stay in player |
| **Menu button** | Player (no overlays) | Exit player, return to previous screen |
| **Play/Pause button** | Player | Toggle play/pause |
| **Play/Pause button** | Any content item focused | Begin playback immediately |
| **Home button** | Anywhere | tvOS system: return to Home screen |
| **Long-press touch surface** | Content item focused | Show context menu |

### 4.4 Click vs Swipe Disambiguation

The Siri Remote's touchpad can register both clicks and swipes. Aether should rely on SwiftUI's built-in focus system for navigation (swipe moves focus, click selects). Avoid custom gesture recognizers that might conflict with the system's focus engine. For the player scrubber, use `MoveCommandDirection` or `DigitalCrownRotationalSensitivity`-style APIs adapted for tvOS touch surface input.

---

## 5. Typography & Spacing

### 5.1 Type Scale

All fonts use **SF Pro**, the system font on Apple platforms. Specific faces:

| Use Case | Font | Size | Weight | Line Height |
|---|---|---|---|---|
| Screen title | SF Pro Display | 38pt | Bold | 44pt |
| Section label (row header) | SF Pro Display | 31pt | Medium | 36pt |
| Hero banner title (fallback) | SF Pro Display | 56pt | Bold | 62pt |
| Detail title | SF Pro Display | 52pt | Bold | 58pt |
| Body text (overview) | SF Pro Text | 27pt | Regular | 36pt |
| Item title (poster label) | SF Pro Text | 25pt | Regular | 30pt |
| Secondary text (year, metadata) | SF Pro Text | 25pt | Regular | 30pt |
| Tertiary text (minor info) | SF Pro Text | 23pt | Regular | 28pt |
| Button label | SF Pro Text | 27pt | Semibold | 32pt |
| Scrubber time | SF Pro (Tabular) | 23pt | Regular | 28pt |
| Caption / version | SF Pro Text | 21pt | Regular | 26pt |

Never go below 21pt for any on-screen text. At 10-foot distance, anything smaller becomes illegible.

### 5.2 Spacing Scale

Use a base unit of **8pt** with a consistent scale:

| Token | Value | Usage |
|---|---|---|
| `space-xs` | 4pt | Tight grouping (title + year, icon + label) |
| `space-sm` | 8pt | Related elements (poster + title) |
| `space-md` | 16pt | Between interactive elements (button group) |
| `space-lg` | 24pt | Between sections within a group |
| `space-xl` | 40pt | Between rows on Home screen |
| `space-2xl` | 60pt | Major section separators |
| `space-3xl` | 80pt | Screen edge padding (left/right) |

### 5.3 Minimum Focus Target Sizes

Per Apple Human Interface Guidelines for tvOS:

- Minimum focusable element size: **86pt x 86pt**.
- Recommended poster card size: **200pt x 300pt** (2:3) — well above minimum.
- Recommended button size: minimum **86pt x 48pt** with generous padding.
- Spacing between focusable elements: minimum **20pt** (to prevent accidental focus shifts).

---

## 6. Animations & Transitions

### 6.1 View Transitions (Push/Pop)

- **Push navigation** (e.g., Home -> Detail): The incoming view slides in from the trailing edge (right) while the outgoing view slides to the leading edge and slightly fades out. Duration: 0.35s, ease-in-out curve. This matches the native tvOS `NavigationStack` transition.
- **Pop navigation** (Menu button): Reverse of push. The current view slides out to the trailing edge and the previous view slides in from the leading edge.
- **Login -> Home transition:** Custom crossfade with a scale-up (from 0.97 to 1.0) on the Home view. Duration: 0.5s. This feels like "unveiling" the content.

### 6.2 Focus Animations

- **Scale:** Spring animation, `response: 0.35, dampingFraction: 0.7`. This gives a snappy but organic feel — the element slightly overshoots then settles.
- **Shadow:** Animated alongside scale with the same spring parameters.
- **Text/overlay appearance** (e.g., title below focused poster): Opacity fade from 0 to 1 with a slight y-offset translation (8pt upward), duration 0.2s, ease-out. Starts 0.05s after the focus scale animation begins.

### 6.3 Hero Banner

- **Auto-advancement crossfade:** The backdrop image and overlay content (logo, metadata, buttons) crossfade simultaneously. Duration: 0.6s, ease-in-out. The new backdrop fades in from 0% opacity while the old one fades out.
- **Dot indicator transition:** The active dot scales from 8pt to 10pt diameter and changes from secondary to primary color. Duration: 0.3s.
- **Parallax tilt:** Follows the native `tvOS` card parallax behavior. The backdrop image is rendered slightly larger than its frame (by ~15pt on each edge) and shifts in response to the touch surface position. This is automatic when using the system's focus engine with an `Image` inside a `Button`.

### 6.4 Loading States

- **Skeleton screens:** Before data loads, show placeholder shapes that match the layout. Posters render as rounded rectangles in `#1A1A1A`. Text renders as shorter rounded rectangles in `#1A1A1A`.
- **Shimmer effect:** A diagonal gradient highlight sweeps across skeleton elements. The gradient is: transparent -> white at 5% opacity -> transparent. It travels from leading to trailing edge over 1.2s, repeating on loop. This conveys "loading" without a spinner.
- **Image loading:** Individual images fade in from 0% opacity when they load (0.2s duration). This prevents the jarring "pop" of images appearing instantly, especially on slow network connections.
- **Pull-to-refresh:** Not applicable on tvOS (no pull gesture). Instead, data refreshes automatically when a tab becomes active if the last refresh was more than 5 minutes ago. A small, unobtrusive spinner can appear inline in the row header during background refresh.

---

## 7. Color Palette

### 7.1 Core Colors

| Token | Hex | Usage |
|---|---|---|
| `background` | `#0D0D0D` | Primary screen background. Near-black, not pure black (avoids OLED crush artifacts and feels warmer). |
| `surface` | `#1A1A1A` | Cards, skeleton placeholders, elevated surfaces. |
| `surfaceHover` | `#242424` | Focused row backgrounds, pressed states. |
| `border` | `#FFFFFF` at 6% | Subtle dividers, card outlines (use sparingly). |
| `borderFocused` | `#FFFFFF` at 40% | Focused text field borders. |

### 7.2 Accent Color

| Token | Hex | Usage |
|---|---|---|
| `accent` | `#6C5CE7` | Primary action buttons, focused element highlights, progress bars, selected pills, active indicators. A desaturated violet that reads as distinctive without overwhelming artwork. |
| `accentLight` | `#8B7CF0` | Hover/focus state of accent elements (brightened 15%). |
| `accentDark` | `#5544CC` | Pressed state of accent elements. |

The accent color should be defined as a single SwiftUI `Color` asset so it can be globally changed during development if the team settles on a different hue. Alternative candidates: `#4A90D9` (muted blue), `#E5A549` (warm amber).

### 7.3 Text Colors

| Token | Hex / Opacity | Usage |
|---|---|---|
| `textPrimary` | `#FFFFFF` at 92% | Titles, button labels, headings — all text that demands attention. Not pure 100% white (slightly softened to reduce harshness on dark backgrounds). |
| `textSecondary` | `#FFFFFF` at 60% | Metadata, subtitles, years, descriptions. Supporting text that provides context. |
| `textTertiary` | `#FFFFFF` at 38% | Timestamps, version numbers, disabled labels. Text that is present but not important. |

### 7.4 Semantic Colors

| Token | Hex | Usage |
|---|---|---|
| `success` | `#2ECC71` | Connection success indicator (server setup), checkmark on watched items. |
| `error` | `#E74C3C` | Error messages, destructive actions (sign out button text). |
| `warning` | `#F39C12` | Transcoding indicator (if applicable). |

### 7.5 Adaptive Artwork Colors (Future Enhancement)

In a future version, Aether could extract dominant colors from poster/backdrop artwork and use them to tint the background or accent elements on Detail screens. This would create a unique visual identity for each piece of content (similar to Spotify's approach).

**Implementation sketch:**
- Extract 2-3 dominant colors from the backdrop image using `UIImage` color quantization.
- Select the most saturated, non-neutral color as the "artwork accent."
- Apply it as a subtle gradient wash on the detail screen background (15-20% opacity, blended with the base `#0D0D0D`).
- Ensure WCAG contrast ratios are met by clamping luminance values.

This feature is explicitly out of scope for v1 but the color system should be architected to accommodate it (use semantic color tokens everywhere, never hardcode hex values in views).

---

## Appendix A: Image Sizing Reference

Recommended image request sizes from the Jellyfin API (to avoid loading unnecessarily large images):

| Image Type | Request Width | Aspect Ratio | Notes |
|---|---|---|---|
| Backdrop (hero) | 1920px | 16:9 | Full screen width |
| Backdrop (detail) | 1920px | 16:9 | Full screen width |
| Primary (poster, grid) | 400px | 2:3 | 2x of 200pt display width |
| Primary (poster, row) | 400px | 2:3 | Same |
| Thumb (episode) | 560px | 16:9 | 2x of 280pt display width |
| Thumb (continue watching) | 600px | 16:9 | 2x of 300pt display width |
| Logo | 800px | Variable | Needs breathing room for quality |
| Person (headshot) | 240px | 1:1 (cropped) | 2x of 120pt display diameter |

Always request images at 2x the display point size for Retina quality on Apple TV. Use Jellyfin's `maxWidth` query parameter to control the response size and enable `fillWidth` to let the server resize efficiently.

---

## Appendix B: Accessibility Considerations

Even in v1, basic accessibility should be respected:

- **VoiceOver support:** All focusable elements must have meaningful accessibility labels. Poster cards should announce: "[Title], [Year], [Type]". Episode rows should announce: "Episode [number], [title], [runtime], [watched/unwatched]".
- **Reduce Motion:** When the user has "Reduce Motion" enabled in tvOS Settings, disable:
  - Hero banner parallax.
  - Shimmer loading animation (replace with a static skeleton).
  - Auto-advancement of the hero banner (still allow manual).
  - Scale animations on focus (use opacity change instead).
- **High contrast:** When the system "Increase Contrast" setting is active, increase `textSecondary` to 75% opacity and `textTertiary` to 50% opacity. Add a 1pt border to buttons that normally rely solely on fill color.
- **Dynamic Type:** tvOS has limited Dynamic Type support, but respect the system's text size preference if the user has adjusted it in Accessibility settings.
