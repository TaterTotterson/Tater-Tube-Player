# Tater Tube Player

Tater Tube is a modern, artwork-first television and desktop player for
[Tater Tube Server](https://github.com/TaterTotterson/tater-tube-server).

This repository contains the new store player. It is intentionally independent
from the GPL-licensed retro player: no source code from that client is copied
here. The existing Raspberry Pi experience is referred to as **Tater Tube
Classic**, while this application is simply **Tater Tube**.

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

The first milestone is a clean desktop shell with:

- a couch-friendly modern home screen;
- keyboard, controller, and remote-visible focus states;
- Tater Tube Server URL and six-digit PIN pairing;
- prototype persistence for the server address and player token;
- a deterministic demo mode for visual development and screenshots.

The content shown in demo mode is fictional placeholder data. It will be
replaced by the versioned Tater Tube Server player API.

The pairing surface is captured in
[`docs/screenshots/pairing.png`](docs/screenshots/pairing.png).

## Build

Requirements:

- CMake 3.24+
- Qt 6.8+ with Quick, Quick Controls, QML, Network, and Test
- A C++20 compiler

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Debug
cmake --build build --parallel
ctest --test-dir build --output-on-failure
./build/tater-tube --demo                         # Windows/Linux
./build/tater-tube.app/Contents/MacOS/tater-tube --demo  # macOS
```

Create an offscreen design snapshot:

```bash
QT_QPA_PLATFORM=offscreen \
  ./build/tater-tube.app/Contents/MacOS/tater-tube \
  --demo --screenshot=build/home.png
```

## Licensing status

The application license has not been selected yet. Until it is, this repository
is not offered under an open-source license. See
[`docs/LICENSE_POLICY.md`](docs/LICENSE_POLICY.md) before adding dependencies.
