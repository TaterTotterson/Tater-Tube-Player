# Steam store media manifest

All screenshots in this folder are genuine captures of the current Tater Tube
Player UI running in its deterministic demo mode. The media titles and artwork
are fictional, and no personal-server addresses, tokens, account details,
viewing history, or commercial entertainment artwork are present.

## Recommended screenshot upload order

1. `screenshots/01-home.png` — Home, Continue Watching, and Tube TV shelves
2. `screenshots/02-library.png` — movie and television library rows
3. `screenshots/03-details.png` — artwork, metadata, resume, restart, and reset
4. `screenshots/05-live-tv.png` — full guide with channel logos and break timing
5. `screenshots/04-tater-picks.png` — optional personalized recommendations
6. `screenshots/06-search.png` — title search

`screenshots/03-discover.png` is retained for website use but should not lead
the first Steam submission. The first store page should establish Tater Tube
Player primarily as a self-hosted personal-library and Tube TV client.

Every screenshot is a native 3840 x 2160 PNG at 16:9, exceeding Steam's
1920 x 1080 minimum.

## Trailer

- File: `trailer/tater-tube-player-store-trailer-v1.mp4`
- Suggested title: `Tater Tube Player — Product Tour`
- Suggested Steam category: `Gameplay` (the footage shows the actual product UI)
- Video: H.264, 1920 x 1080, 30 fps
- Audio: AAC, 48 kHz stereo silence
- Duration: approximately 48 seconds
- Average bitrate: approximately 8.1 Mbps
- Poster: `trailer/trailer-poster-1920x1080.png`

This cut is a genuine screen recording of the current Linux build running on a
Steam Deck. It shows live controller-style navigation through Home, Library,
Discover, Live TV, Tater Picks, and the title-details dialog, followed by real
moving playback inside the player. It is not assembled from moving still
images.

The playback excerpt uses Borys Zaitsev's Pexels video “Stunning abstract
animation of galaxy and stars in deep space,” downloaded from
<https://www.pexels.com/video/stars-in-space-12275372/>. Pexels permits free
commercial use and modification under <https://www.pexels.com/license/>.
Source-file SHA-256:
`1e4f7dd3580cf4bc13e5db65c0b1785308f1d762747b9f0b1190554681e1a267`.

## Store graphics

- `graphics/store/header-capsule-920x430.png`
- `graphics/store/small-capsule-462x174.png`
- `graphics/store/main-capsule-1232x706.png`
- `graphics/store/vertical-capsule-748x896.png`
- `graphics/store/page-background-1438x810.png` (optional)

## Steam Library and client graphics

- `graphics/library/library-capsule-600x900.png`
- `graphics/library/library-hero-3840x1240.png`
- `graphics/library/library-logo-1280x720.png`
- `graphics/library/header-capsule-920x430.png`
- `graphics/client/shortcut-icon-256.png`
- `graphics/client/app-icon-184.jpg`

The Header, Small, Main, and Vertical Store Capsules use the Tater Tube wordmark
with the leaning mascot and intentionally omit `PLAYER`. They share the orange
CRT-room artwork used by the Library graphics. The Page Background uses a
darkened, softened version of the room without a logo so it remains ambient
behind Steam's store-page content. The Library Capsule, Library Header Capsule,
and transparent Library Logo also use only the Tater Tube wordmark with the
leaning mascot. The Library Hero contains only the supplied orange CRT-room
artwork. The portrait room adaptation used by the vertical capsules is retained
at `graphics/source/library-room-vertical-1024x1536.png`.

## Generated demo artwork prompts

The image-generation prompts used for the six fictional landscape titles and
the Cosmic Drift portrait poster requested entirely original cinematic art,
with no actors, existing characters, brands, logos, readable text, or
watermarks. Generation used the built-in image-generation tool. Final project
assets are stored in `assets/demo/`; the complete prompt record is in
`DEMO_ART_PROMPTS.md`, and source outputs remain in the Codex generated-images
archive.
