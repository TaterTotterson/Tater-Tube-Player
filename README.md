# Tater Tube Player

Tater Tube Player is a modern, artwork-first television and desktop player for
[Tater Tube Server](https://github.com/TaterTotterson/tater-tube-server).

This repository contains the new store player. It is intentionally independent
from the GPL-licensed retro player: no source code from that client is copied
here. Existing Tater Tube applications keep their current names and behavior.

![Modern Tater Tube home screen](docs/screenshots/home.png)

## Product direction

- Tater Tube Server only; no Plex, Emby, or Jellyfin integrations
- Steam and Steam Deck first
- Native Apple TV and Google TV clients after the server contract stabilizes
- Grey, graphite, white, and Tater orange visual system
- Poster and backdrop artwork, Continue Watching, search, and details
- Tube TV channels, guide data, user-supplied commercial breaks, and bumpers
- Tater recommendations and narration through Tater Tube Server

## Current milestone

The current milestone is a Steam Deck-ready browsing and playback prototype
with:

- a couch-friendly modern home screen;
- a Home-only navigation strip plus an edge-triggered slide-out menu for TV remotes;
- keyboard, controller, and remote-visible focus states;
- Tater Tube Server URL and six-digit PIN pairing;
- prototype persistence for the server address and player token;
- live Continue Watching, Recently Added, and Tube TV home rows from
  `/api/v1/player/home`;
- full-screen direct playback for local movies and episodes;
- server-backed Library browsing across local collections, discovery filters,
  folders, shows, and seasons, with incremental title rendering;
- a refreshable Live TV lineup with channel now/next information and one-click
  tuning;
- automatic H.264 1080p server transcoding when direct playback fails;
- Tube TV HLS playback that preserves server-scheduled commercials, spots,
  bumpers, and station IDs;
- play/pause, 10-second seeking, volume, back, and auto-hiding playback controls
  for Steam Input, keyboard, and touch;
- resume-position loading and periodic playback progress updates;
- local poster discovery for media-adjacent `poster`, `folder`, `cover`, and
  title-matched JPG, PNG, or WebP files;
- a deterministic demo mode for visual development and screenshots.

The content shown in demo mode is fictional placeholder data. Normal paired
mode uses the versioned Tater Tube Server player API.

The pairing surface is captured in
[`docs/screenshots/pairing.png`](docs/screenshots/pairing.png).

## Build

Requirements:

- CMake 3.24+
- Qt 6.8+ with Quick, Quick Controls, QML, Multimedia, Network, and Test
- A C++20 compiler
- Tater Tube Server with the `/api/v1/player/home` endpoint
- Tater Tube Server 1.4.16+ for fast library loading and audio-only compatibility
  transcoding

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Debug
cmake --build build --parallel
ctest --test-dir build --output-on-failure
./build/tater-tube-player --demo                         # Windows/Linux
./build/tater-tube-player.app/Contents/MacOS/tater-tube-player --demo  # macOS
```

Create an offscreen design snapshot:

```bash
QT_QPA_PLATFORM=offscreen \
  ./build/tater-tube-player.app/Contents/MacOS/tater-tube-player \
  --demo --screenshot=build/home.png
```

### Steam Deck development build

For early hardware testing, the player can run from an isolated Arch Distrobox
without unlocking SteamOS. Create a container named `tater-player-build` with
CMake, Ninja, Qt 6 (including Qt Multimedia), FFmpeg, PulseAudio client
libraries, SDL2, and a C++ compiler, then configure the Deck build at
`~/Tater-Tube-Player/build-deck`.

The development launcher is:

```bash
./scripts/run-steam-deck-dev.sh
```

`packaging/linux/com.taterassistant.TaterTubePlayer.desktop` can be added to
Steam as a non-Steam game for Gaming Mode and Steam Input testing. This
Distrobox launcher is only for development; the Steam release will ship a
self-contained runtime and will not require Distrobox.

The Deck launcher forwards SteamOS's PipeWire/Pulse audio socket into the
development container. For on-demand video, it keeps the original video stream
untouched and asks the server to convert only the audio to stereo AAC. If that
video cannot be copied into the compatibility stream, the player falls back to
a full H.264/AAC transcode.

## Licensing status

The application license has not been selected yet. Until it is, this repository
is not offered under an open-source license. See
[`docs/LICENSE_POLICY.md`](docs/LICENSE_POLICY.md) before adding dependencies.
