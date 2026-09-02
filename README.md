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

The current milestone is a clean desktop shell with:

- a couch-friendly modern home screen;
- keyboard, controller, and remote-visible focus states;
- Tater Tube Server URL and six-digit PIN pairing;
- prototype persistence for the server address and player token;
- live Continue Watching, Recently Added, and Tube TV home rows from
  `/api/v1/player/home`;
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
- Qt 6.8+ with Quick, Quick Controls, QML, Network, and Test
- A C++20 compiler
- Tater Tube Server with the `/api/v1/player/home` endpoint

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

## Licensing status

The application license has not been selected yet. Until it is, this repository
is not offered under an open-source license. See
[`docs/LICENSE_POLICY.md`](docs/LICENSE_POLICY.md) before adding dependencies.
