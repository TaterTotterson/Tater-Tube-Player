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

- Pair a player and retain its token with permissions restricted to the current
  operating-system user.
- Keep full navigation on Home, use the remote/controller Back action on
  secondary screens, and expose an edge-triggered side rail for navigation.
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
GET  /api/v1/player/library
GET  /api/v1/player/artwork/local
POST /api/v1/player/playback/sessions
GET  /api/tater/local/stream
GET  /api/tater/usenet/catalog
GET  /api/tater/usenet/items
GET  /api/tater/tv/lineup
POST /api/tater/playstate
```

The home response aggregates capabilities, Continue Watching, Recently Added,
library roots, and lightweight Tube TV now/next data. Local artwork accepts
media-adjacent `poster`, `folder`, `cover`, and title-matched images. Before
on-demand playback, the player reports its current display, audio output,
decoder, resolution, channel, and passthrough capabilities. The server probes
the source codec, bit depth, HDR metadata, and Dolby Vision profile, then selects
one of four track-level plans:

```text
Video direct     + Audio direct/bitstream = direct play
Video direct     + Audio transcode        = audio-only transcode
Video transcode  + Audio direct/bitstream = video-only transcode
Video transcode  + Audio transcode        = full transcode
```

Selective video transcoding uses H.264 while copying the original audio track;
selective audio transcoding copies the original video while producing AAC.
Playback activity records the video and audio paths separately so the server UI
can describe what is actually happening. If a selective stream fails, the
player falls back to a full H.264/AAC `hdmi_1080p` transcode. Tube TV channel
URLs are server-produced HLS and keep server-scheduled commercials, bumpers,
spots, and station IDs intact.

The version 2 capability report separates decoder HDR formats from connected
display HDR formats. The server direct-plays HDR only when the complete path is
available, uses an HDR10-compatible base layer for suitable Dolby Vision/HDR10+
sources, and otherwise requests HDR-to-SDR tone mapping. Audio remains direct or
bitstreamed when it does not need conversion. Linux reads display formats from
EDID; platform-native Apple TV and Google TV clients will populate the same
fields from their display and media APIs.

Qt Multimedia exposes decoded audio capabilities and follows the system's
default output, but this Steam client does not advertise encoded HDMI
passthrough. Native Apple TV and Google TV clients can use the same contract and
advertise passthrough only when their platform playback engine and connected
audio route confirm it.

The Library landing page uses one compact versioned request to populate its
media shelves, while deeper browsing and Live TV still use the existing
authenticated item-browse and lineup compatibility routes. Those routes are not
altered, so original Tater Tube clients remain unaffected.

Planned surface:

```text
GET  /api/v1/player/server
POST /api/v1/player/pair
GET  /api/v1/player/items/{id}
GET  /api/v1/player/search
POST /api/v1/player/playback/progress
GET  /api/v1/player/tv/lineup
GET  /api/v1/player/images/{id}/{kind}
```

Future playback-session revisions can add bandwidth, HDR, subtitle, and
container-specific decisions without changing the track-level modes.

## Platform plan

- Steam/Steam Deck: this Qt Quick desktop client, initially released for Linux.
- Apple TV: a thin SwiftUI/AVKit client using the same server contract.
- Google TV: a thin Kotlin/Compose TV/Media3 client using the same contract.

UI implementation is platform-specific. Product behavior, API fixtures, design
tokens, copy, artwork rules, and acceptance tests are shared.

## Security note

The Linux client stores its paired-player token in the current user's Qt
settings and forces that file to mode `0600`. Authenticated requests reject
cross-origin redirects so the token cannot be forwarded to another host. Native
platform clients may use their platform credential stores when implemented.
