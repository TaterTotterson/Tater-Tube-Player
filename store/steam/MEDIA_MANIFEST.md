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

Every screenshot is 3200 x 1800 PNG at 16:9, exceeding Steam's 1920 x 1080
minimum.

## Trailer

- File: `trailer/tater-tube-player-store-trailer-v1.mp4`
- Suggested title: `Tater Tube Player — Product Tour`
- Suggested Steam category: `Gameplay` (the footage shows the actual product UI)
- Video: H.264, 1920 x 1080, 30 fps
- Audio: AAC, 48 kHz stereo silence
- Duration: approximately 26 seconds
- Average bitrate: approximately 9 Mbps
- Poster: `trailer/trailer-poster-1920x1080.png`

The first cut intentionally works without sound and uses only real product
screens. A later cut may add controller navigation and rights-cleared demo
playback footage, but this cut is suitable for assembling the initial store
page.

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

The store and library capsules contain only product artwork, the Tater Tube
wordmark, and the official `PLAYER` subtitle. The Library Hero contains artwork
only, and the Library Logo has a transparent background.

## Generated demo artwork prompts

The image-generation prompts used for the six fictional landscape titles and
the Cosmic Drift portrait poster requested entirely original cinematic art,
with no actors, existing characters, brands, logos, readable text, or
watermarks. Generation used the built-in image-generation tool. Final project
assets are stored in `assets/demo/`; the complete prompt record is in
`DEMO_ART_PROMPTS.md`, and source outputs remain in the Codex generated-images
archive.
