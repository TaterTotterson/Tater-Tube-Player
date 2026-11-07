# Dependency and asset policy

The Tater Tube Player keeps a substantially simpler distribution record than
the existing GPL Tater Tube client.

## Rules

1. Do not copy source code from Tater Tube or its 240-MP ancestry.
2. Record the source, copyright owner, license, version, and exact use of every
   production dependency.
3. Prefer platform SDKs and permissive MIT, BSD, Apache-2.0, ISC, and Zlib-style
   dependencies.
4. Any copyleft, MPL, or proprietary dependency requires a documented
   distribution plan before it enters a release build.
5. Do not link or distribute proprietary storefront SDKs in the portable Linux
   bundle.
6. Generate an SBOM and third-party notices for every release build.
7. Do not bundle emulator cores, game engines, Moonlight, yt-dlp, or the old
   Tater Tube runtime.

## Qt distribution decision

The Linux player uses Qt Quick for a polished ten-foot and desktop UI.
Playback uses Qt Multimedia with its FFmpeg backend. Qt, Qt Multimedia, FFmpeg,
and every codec library included in a release package must be recorded in the
SBOM and third-party notices, with their applicable source-offer and relinking
requirements satisfied.

The Linux player uses the Qt Community Edition under LGPLv3. Release builds
must use shared Qt libraries, must permit users to replace those libraries, and
must not apply DRM or another integrity mechanism that prevents a modified
Qt library from loading. Every bundle includes the LGPL/GPL texts, prominent Qt
notice, relinking instructions, and a Tater-controlled copy or offer for the
exact corresponding Qt source.

The Arch/Distrobox environment on the test Steam Deck is development-only. Its
system FFmpeg and mpv packages must never be copied into a release bundle. The
Linux release builds a shared FFmpeg 7.1.5 with GPL, version-3, and nonfree
parts disabled. Both Qt Multimedia and an mpv 0.40.0 build configured with
`-Dgpl=false` use that audited FFmpeg build. mpv's GPL-only X11 output is
disabled. In Steam Gaming Mode, playback uses mpv's LGPL-compatible SDL video
output on Gamescope's XWayland surface; compatible desktop sessions may use
the retained Wayland/Vulkan path.

The bundle also carries the exact Debian libass 0.17.3-1+deb13u1, libplacebo
7.349.0-3, and libjpeg-turbo 2.1.5-4 shared-library SONAMEs used by the audited
mpv build. Their notices are installed in the bundle. The release source bundle
preserves each matching upstream archive together with the signed Debian
source descriptor and full Debian source delta, including libplacebo's LGPL
corresponding source and Debian build-system patch.

The application source is offered under Apache-2.0. This does not replace or
weaken the separate LGPL obligations for Qt, FFmpeg, or mpv.

Apple TV is a native SwiftUI/AVKit client and does not distribute Qt. Google TV
is a native Kotlin/Compose TV/Media3 client and does not distribute Qt or mpv.
Its AndroidX, Media3, Coil, OkHttp, Kotlin, and coroutine dependencies use
permissive Apache-2.0 terms and remain covered by the Android release notices.

## Controller input

The Linux development build uses the SDL2-compatible API supplied by
`sdl2-compat` 2.32.70 for controller discovery and input. SDL and sdl2-compat
use the permissive Zlib license. Keep SDL dynamically linked, pin the final
redistributed version, and include its license in release-build third-party
notices.

## Mascot assets

The Tater-branded assets were supplied by the product owner. Their creation and
distribution records belong in the private company release archive; the
public repository intentionally contains no signatures or registration records.
Do not assume that source-repository license text alone establishes standalone
artwork rights.

## Server boundary

Tater Tube Server remains a separately deployed network service. No server
source is compiled or copied into this client.
