# Tater Tube Player architecture

## Boundary

Tater Tube Player is a thin player for Tater Tube Server. The server is the source of
truth for catalogs, metadata, artwork, playback state, streams, Tube TV
schedules, commercial breaks, bumpers, and Tater awareness.

```text
Local media / The Tube
          |
          v
 Tater Tube Server
 catalog | artwork | playback plans | HLS | Tube TV | Tater
      /             |                \
 Steam desktop   Apple TV         Google TV
```

The old Tater Tube desktop client is a behavioral reference only. Features are
reimplemented against documented HTTP contracts and fixtures.

## Client responsibilities

- Pair a player and retain its token; move it into platform-secure storage
  before release.
- Render home, library, details, search, guide, and player surfaces.
- Report playback state and Tater viewing events.
- Advertise device playback capabilities.
- Play a direct URL or HLS URL selected by the server.
- Present audio, subtitle, and accessibility controls using platform conventions.

## Server responsibilities

- Normalize local and Newznab-backed items into one media model.
- Resolve poster, backdrop, logo, and thumbnail artwork.
- Decide direct play versus transcoding for each device.
- Produce HLS for Tube TV and incompatible on-demand media.
- Own commercial, bumper, and station-ID scheduling.
- Maintain resume state, next episodes, and Continue Watching.
- Broker recommendations and narration between players and Tater Core.

## Versioned player API

The existing `/api/tater/*` routes remain the compatibility surface for the
original players. The modern player adds new `/api/v1/player/*` routes without
renaming or changing those routes.

Implemented:

```text
GET  /api/v1/player/home
GET  /api/v1/player/artwork/local
```

The home response aggregates capabilities, Continue Watching, Recently Added,
library roots, and lightweight Tube TV now/next data. Local artwork accepts
media-adjacent `poster`, `folder`, `cover`, and title-matched images.

Planned surface:

```text
GET  /api/v1/player/server
POST /api/v1/player/pair
GET  /api/v1/player/libraries
GET  /api/v1/player/items/{id}
GET  /api/v1/player/search
POST /api/v1/player/playback/sessions
POST /api/v1/player/playback/progress
GET  /api/v1/player/tv/lineup
GET  /api/v1/player/images/{id}/{kind}
```

`playback/sessions` should accept codec, container, HDR, audio, subtitle, and
resolution capabilities and return either a direct stream or an HLS stream.

## Platform plan

- Steam/Steam Deck: this Qt Quick desktop client, built for Windows and Linux.
- Apple TV: a thin SwiftUI/AVKit client using the same server contract.
- Google TV: a thin Kotlin/Compose TV/Media3 client using the same contract.

UI implementation is platform-specific. Product behavior, API fixtures, design
tokens, copy, artwork rules, and acceptance tests are shared.

## Security note

The milestone-zero desktop prototype stores its paired-player token with
`QSettings`. Release builds must move that token to the operating system's
credential store (Windows Credential Manager, macOS Keychain, or the equivalent
Linux secret service) before store submission.
