# Sound design foundation

This document freezes the parts of the original SwiftUI prototype that define
the product's identity. The new application may change implementation details,
but should preserve these visual and interaction decisions unless a deliberate
design review changes them.

## Product character

Sound is an artwork-first personal music player for local and NAS libraries.
It should feel calm and native rather than technical: strong cover art, quiet
metadata, restrained glass surfaces, and one vivid red playback accent.

## Core screens retained from the prototype

1. Library
   - Desktop: translucent sidebar plus a content canvas.
   - Compact: bottom navigation for library, search, and settings.
   - Primary library views: recent, albums, songs, artists, and genres.
   - Album cards use large square art with compact title, artist, and source.
2. Album detail
   - Large cover on the left, title and metadata on the right.
   - Red primary play action and quiet secondary shuffle action.
   - Dense track table on desktop; simpler rows on compact layouts.
3. Now playing
   - Immersive artwork-led background derived from the current cover palette.
   - Artwork and transport on one side, lyrics or queue on the other.
   - Synchronized lyrics keep the active line near the visual center.
4. Source settings
   - Connections and indexed folders are separate concepts.
   - Local folder and WebDAV are first-release source types.
   - Scanning, authentication, unavailable, and error states must be explicit.
5. Mini player
   - Persistent bottom surface with cover, title, transport, progress, and
     volume on desktop.
   - Compact platforms retain cover, title, play/pause, and next.

## Design tokens

### Color

- Accent: `#FA243C`.
- Content background: near-black in dark mode and warm-neutral near-white in
  light mode. Avoid pure black or pure white over large surfaces.
- Primary text: 88-92% opacity.
- Secondary text: 50-62% opacity.
- Hairline separators: 5-10% primary color.
- Glass border: white at approximately 18-42% depending on the background.
- Album palette colors may tint hero glows and the now-playing backdrop, but
  never replace the playback accent.

### Shape and elevation

- Album artwork: 8-10 px corner radius at normal sizes.
- Cards and settings rows: 14-16 px continuous radius.
- Mini player: 20 px radius, soft shadow, thin light border.
- Source badges: capsule shape with a subtle translucent fill.
- Avoid strong card borders and heavy drop shadows.

### Type

- Section heading: 22 px, bold.
- Album hero title: approximately 38 px, heavy, slightly tight tracking.
- Body/track title: 13-14 px, semibold.
- Secondary metadata: 11-13 px.
- Time values use tabular/monospaced figures.
- Lyrics: approximately 22 px, heavy and rounded where available.

### Spacing

- Desktop content gutter: 32 px.
- Major vertical sections: 28-32 px.
- Album grid gap: 24 px.
- Album card artwork: adaptive 150-190 px on desktop.
- Track row vertical padding: approximately 11 px.

## Interaction rules

- Artwork is the strongest visual element on every browsing screen.
- Source identity is visible but quiet; it must not dominate song metadata.
- The UI never fabricates playback progress.
- During scrubbing, the thumb and time labels may show a local preview.
- A seek is sent once on release; the UI then returns to engine-reported time.
- Loading and buffering are distinct from paused playback.
- Track changes snap lyrics to the new position. Only natural adjacent lyric
  transitions animate.
- Desktop and mobile share hierarchy and components, not identical layouts.

## Responsive layout

- Compact: bottom navigation, stacked album detail, full-screen now playing.
- Medium: navigation rail or compact sidebar, two-column detail where space
  permits.
- Desktop: 220-260 px sidebar, flexible content, floating mini player.
- Content should remain useful from 360 px mobile width to wide desktop windows.

## Deliberately excluded from the first release

- SMB
- Online artwork and lyric enrichment
- Playlist editing
- Favorites and cross-device synchronization
- watchOS and tvOS clients
- Visual effects that require platform-specific motion sensors

