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
- Cached home response and artwork appear before the background refresh finishes
- Demo mode uses the same fictional, rights-safe catalog as the Steam store build

Open `TaterTubePlayerTV.xcodeproj` in Xcode and select an Apple TV simulator or a
development Apple TV. The project does not require Qt or any other third-party
runtime.

Add `--demo` to the scheme's launch arguments to start directly in the fictional
demo catalog without pairing to a server.

## Feature-parity roadmap

The first native milestone includes pairing, persistent credentials, cached home
content, adaptive navigation, server capability-based sections, and demo mode.
The next milestones bring over the existing Steam behavior in this order:

1. Playback-session negotiation, progress reporting, and native AVKit playback
2. Movies, series, seasons, episodes, resume, and next-episode playback
3. Tube TV guide, channel transitions, and playback overlays
4. Discovery search, result selection, resume, and viewing history
5. Tater Picks, recommendation reasons, and the server-generated spoken message

The server contract remains backward compatible. tvOS-specific capability fields
will be additive so the existing Steam and retro players keep their current paths.
