<p align="center">
  <img src="./assets/tater-tube-logo-leaning-transparent.png" alt="Tater Tube" width="560" />
</p>

<p align="center">
  <a href="https://tatertube.tv">
    <img alt="Visit Tater Tube" src="https://img.shields.io/badge/Tater%20Tube-Visit%20Website-F28C28?style=for-the-badge&logo=googlechrome&logoColor=white" />
  </a>
</p>

<p align="center">
  <a href="https://github.com/TaterTotterson/tater-tube-server">
    <img alt="Get Tater Tube Server" src="https://img.shields.io/badge/Tater%20Tube%20Server-View%20on%20GitHub-24292F?style=for-the-badge&logo=github&logoColor=white" />
  </a>
  <a href="https://discord.gg/w52namKyXT">
    <img alt="Join the Tater community on Discord" src="https://img.shields.io/badge/Discord-Join%20the%20Community-5865F2?style=for-the-badge&logo=discord&logoColor=white" />
  </a>
</p>

# Tater Tube Player

Tater Tube Player is the modern, couch-friendly client for
[Tater Tube Server](https://github.com/TaterTotterson/tater-tube-server). Pair
it with a six-digit code, browse with a controller or remote, and play the
movies, shows, and personal Tube TV channels served from your own collection.

Tater Tube Server is required and is not included. Tater Tube Player does not
include movies, television programs, live channels, or other media.

This repository contains the official Tater Tube Player family. The Qt client
at the repository root targets Steam and Steam Deck, and the native SwiftUI
Apple TV client lives in `apple-tv/`. A native `google-tv/` client will join it
when that platform begins. Shared API contracts, design assets, demo content,
and release policy stay together.

The Player is intentionally independent from the GPL-licensed retro player: no
source code, emulator cores, or ROM content from that client is included here.
Existing Tater Tube applications keep their current names and behavior.

![Modern Tater Tube home screen](docs/screenshots/home.png)

## Highlights

- Artwork-rich Home and Library shelves with Continue Watching, Recently
  Added, genres, all movies, and all television series.
- Show, season, and episode views with viewing progress, resume support,
  automatic next-episode playback, and season-to-season continuation.
- A couch-friendly Tube TV guide for server-generated and user-created
  channels, including channel artwork, schedule progress, commercial breaks,
  station IDs, spots, and Tater bumpers.
- Optional Discovery browsing when Newznab streaming is configured on the
  user's server. Partially watched Discovery titles can be resumed from
  Continue Watching.
- Optional Tater Picks recommendations, explanations, and voice briefing when
  the user separately configures Tater Link.
- A compact playback overlay with progress, playback-path details, subtitle
  selection, and alternate audio-track selection. Subtitles start off by
  default.
- Controller-first navigation with held D-pad scrolling, page jumps, Back, and
  a slide-out navigation rail. Touch and keyboard input remain available.
- Resolution-aware rendering for the Steam Deck display and connected 1080p,
  1440p, or 4K televisions.
- Persistent content and artwork caches so shelves appear immediately while
  changed content refreshes in the background.
- A deterministic demo mode with fictional content for review, screenshots,
  and visual development.

Normal paired mode uses authenticated, versioned Tater Tube Server player APIs.
The content shown in demo mode is fictional placeholder data.

The pairing surface is captured in
[`docs/screenshots/pairing.png`](docs/screenshots/pairing.png).

## Playback and transcoding

Before playback, the Player reports the active display resolution, decoder,
audio output, channel count, and detected HDMI capabilities. Tater Tube Server
then chooses the least destructive compatible path:

- direct play when both tracks are compatible;
- copy the video and convert only the audio;
- convert only the video and preserve compatible audio; or
- convert both tracks when required.

The Steam build uses a separately replaceable, LGPL-compatible mpv executable
for playback. It selects the best non-commentary English audio track by default,
allows audio and subtitle tracks to be changed during playback, and requests
encoded HDMI audio passthrough only for formats reported by the connected
display. Unsupported audio is decoded or converted instead.

Tube TV remains scheduled by the server, so transitions between programs,
commercials, spots, bumpers, and station IDs stay synchronized across players.
The Player reports live and on-demand progress back to the server for resume
state, Continue Watching, playback history, and the server dashboard.

## Server compatibility

Tater Tube Player connects only to Tater Tube Server; it does not connect to
Plex, Emby, or Jellyfin. Tater Tube Server 1.4.46 or newer is recommended for
the complete current Player feature set.

The modern `/api/v1/player/*` routes are separate from the compatibility routes
used by the original Tater Tube players.

## Build from source

Requirements:

- CMake 3.24+
- Qt 6.8+ with Quick, Quick Controls, QML, Multimedia, Network, and Test
- A C++20 compiler
- Tater Tube Server for paired operation

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Debug
cmake --build build --parallel
ctest --test-dir build --output-on-failure
./build/tater-tube-player --demo                         # Linux
./build/tater-tube-player.app/Contents/MacOS/tater-tube-player --demo  # macOS
```

Create an offscreen design snapshot:

```bash
QT_QPA_PLATFORM=offscreen \
  ./build/tater-tube-player.app/Contents/MacOS/tater-tube-player \
  --demo --screenshot=build/home.png
```

### Steam Deck development

The release on Steam is packaged as a self-contained Linux build and does not
require a development container. For source development on a Steam Deck, the
project can also be built in an isolated Arch Distrobox containing CMake,
Ninja, Qt 6, FFmpeg, PulseAudio client libraries, SDL2, and a C++ compiler.

The development launcher is:

```bash
./scripts/run-steam-deck-dev.sh
```

`packaging/linux/com.taterassistant.TaterTubePlayer.desktop` can be added to
Steam as a non-Steam application while testing a local development build in
Gaming Mode.

### Apple TV development

The Apple TV edition requires Xcode 26 or newer and targets tvOS 18 or newer.
Open `apple-tv/TaterTubePlayerTV.xcodeproj` in Xcode, then select an Apple TV
simulator or a development Apple TV. It uses native Liquid Glass on tvOS 26
and a dark translucent material on older supported tvOS releases. See
[`apple-tv/README.md`](apple-tv/README.md) for the current parity roadmap.

## Security and privacy

On Steam, the paired-player token is stored in the current operating-system
user's Qt settings file; Linux restricts that file to the user (`0600`). Apple
TV stores it in the device Keychain. The token is sent only to the paired Tater
Tube Server and is never forwarded across HTTP redirects.

Tater Picks is optional and hidden unless Tater Link is configured. The Player
communicates with the user's Tater Tube Server rather than directly with an AI
provider. See [PRIVACY.md](PRIVACY.md) for the complete data-flow description.

## Platform direction

The current clients target Steam, Steam Deck, and Apple TV. A future native
Google TV client will share the same server contracts, design assets, and
product behavior while using Android's native media framework.

## License

Tater Tube Player is open-source software licensed under the
[Apache License 2.0](LICENSE). The Tater Tube name, logo, and mascot remain
protected brand identifiers; see [TRADEMARKS.md](TRADEMARKS.md).

Steam release builds dynamically link Qt under LGPLv3. Qt, FFmpeg, SDL, mpv,
and other third-party components retain their respective licenses. The native
Apple TV target does not use Qt or mpv. Notices, source availability, and Qt
relinking instructions for the Steam edition are provided in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md),
[docs/SOURCE_CODE.md](docs/SOURCE_CODE.md), and
[docs/RELINKING_QT.md](docs/RELINKING_QT.md).
