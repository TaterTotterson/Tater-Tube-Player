# Dependency and asset policy

The new Tater Tube player is being created to have a substantially simpler distribution record
than the existing GPL Tater Tube client.

## Rules

1. Do not copy source code from Tater Tube or its 240-MP ancestry.
2. Record the source, copyright owner, license, version, and exact use of every
   production dependency.
3. Prefer platform SDKs and permissive MIT, BSD, Apache-2.0, ISC, and Zlib-style
   dependencies.
4. Any GPL, AGPL, LGPL, MPL, codec, patent, or proprietary dependency requires a
   written distribution decision before it enters a release build.
5. Keep Steamworks integration optional and isolated until the final licensing
   approach has been reviewed.
6. Generate an SBOM and third-party notices for every store build.
7. Do not bundle emulator cores, game engines, Moonlight, yt-dlp, or the old
   Tater Tube runtime.

## Qt distribution decision

The prototype uses Qt Quick because it provides a productive Steam desktop UI.
Playback uses Qt Multimedia with its FFmpeg backend. Qt, Qt Multimedia, FFmpeg,
and every codec library included in a store package must be recorded in the
SBOM and third-party notices, with their applicable source-offer and relinking
requirements satisfied.

The Steam/Linux player uses the Qt Community Edition under LGPLv3. Store builds
must use shared Qt libraries, must permit users to replace those libraries, and
must not apply Steam DRM or another integrity mechanism that prevents a modified
Qt library from loading. Every depot includes the LGPL/GPL texts, prominent Qt
notice, relinking instructions, and a Tater-controlled copy or offer for the
exact corresponding Qt source.

The Arch/Distrobox environment on the test Steam Deck is development-only. Its
system FFmpeg is GPL-enabled and must never be copied into a store depot. The
release build uses the FFmpeg binaries supplied by the official Qt distribution
or another audited shared FFmpeg build configured without GPL or nonfree parts.

The application source is offered under Apache-2.0. This does not replace or
weaken the separate LGPL obligations for Qt and FFmpeg.

Apple TV is a native SwiftUI/AVKit client and does not distribute Qt. Google TV
will receive its own distribution review before an Android build is published.

## Controller input

The Steam Deck development build uses the SDL2-compatible API supplied by
`sdl2-compat` 2.32.70 for controller discovery and input. SDL and sdl2-compat
use the permissive Zlib license. Keep SDL dynamically linked, pin the final
redistributed version, and include its license in store-build third-party
notices.

## Mascot assets

The initial mascot images were copied from the Tater repository at the product
owner's direction. Confirm and document their original creation records and
store-distribution rights before release. Do not assume that source-repository
license text alone establishes standalone artwork rights.

## Server boundary

Tater Tube Server remains a separately deployed network service. No server
source is compiled or copied into this client.
