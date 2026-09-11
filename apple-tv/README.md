# Tater Tube Player for Apple TV

This directory contains the native tvOS edition of Tater Tube Player. It shares
the Tater Tube Server API with the Steam player while using SwiftUI and AVKit so
the app follows Apple TV interaction, playback, accessibility, and App Store
expectations.

## Platform approach

- Minimum deployment target: tvOS 18
- Native Liquid Glass surfaces on tvOS 26 and newer
- Dark translucent material fallback on tvOS 18–25
- Pairing credentials stored in the tvOS Keychain
- Authenticated requests cannot redirect to another host or downgrade HTTPS
- Cached home, library, guide, Discovery, and artwork data appear before background refreshes finish
- Demo mode uses the same fictional, rights-safe catalog as the Steam store build

Open `TaterTubePlayerTV.xcodeproj` in Xcode and select an Apple TV simulator or a
development Apple TV. The project does not require Qt or any other third-party
runtime.

Add `--demo` to the scheme's launch arguments to start directly in the fictional
demo catalog without pairing to a server.

See [`APP_STORE_REVIEW.md`](APP_STORE_REVIEW.md) for the local-network ATS
justification and the review-access checklist.

## Feature-parity roadmap

The native foundation includes pairing, persistent credentials, cached home
content and artwork, adaptive navigation, server capability-based sections, and
demo mode. The native library now includes complete movie and TV browsing,
naturally sorted seasons and episodes, dedicated artwork fallbacks, contextual
resume actions, live watch progress, lazy grids for large collections, and a
disk-backed page and artwork cache. Tube TV includes a cached native guide,
authenticated channel logos, live progress and commercial-break timing, and
channel playback through the existing server stream. The playback core includes
server capability negotiation, native AVKit playback, subtitles off by default,
system audio/subtitle selection, resume, on-demand progress reporting,
completion handling, and automatic season-to-season episode continuation.
Discovery includes the six server-configured movie and TV collections, bundled
Tater artwork, cached title feeds and searches, complete release filenames,
multi-file selection, native playback, viewing history, and resumable Continue
Watching entries. Tater Picks adds the current server-generated recommendation
set, artwork and per-title reasons, the dedicated spoken group briefing, and
movie, episode, and Tube TV viewing context for future scheduled picks. Speech
stops automatically when the viewer leaves the section.

The native Apple TV feature-parity foundation is complete. Physical-device
playback validation, accessibility review, App Store artwork, and final store
packaging remain release work rather than missing player sections.

Apple TV requests an MPEG-TS-compatible output only when AVKit cannot consume a
source container directly. Compatible video and audio tracks are repackaged
without re-encoding; the server still converts only the incompatible track when
one needs conversion.

The server contract remains backward compatible. tvOS-specific capability fields
will be additive so the existing Steam and retro players keep their current paths.
