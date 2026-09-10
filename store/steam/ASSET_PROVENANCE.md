# Store and bundled-asset provenance

This file records the release-facing provenance categories. Keep original
prompts, editable sources, licenses, receipts, and owner attestations in the
private company release archive. Do not commit signatures or private account
information.

## Project-created generative assets

The following assets were created specifically for Tater Tube Player with
OpenAI image-generation tools, reviewed by the product owner, and intentionally
exclude real performers, existing entertainment characters, third-party logos,
and watermarks:

- `assets/demo/*.png`
- `assets/discovery/*.png`
- `assets/mascot/tater-hero-remote.png`
- the portrait CRT-room adaptation at
  `store/steam/graphics/source/library-room-vertical-1024x1536.png`

The detailed fictional demo-title prompts are in `DEMO_ART_PROMPTS.md`. Retain
the conversation/export records for the category, channel, mascot, and key-art
variants in the private release archive.

## Existing Tater brand assets — private company rights record

The product owner supplied the following existing Tater project assets for use
in the Player and has stated that the underlying Tater logo/wordmark is covered
by the company's trademark rights. The `Tube` addition and complete composite
must not be described as separately registered without a matching registration
record. The company keeps its ownership and Steam store distribution
confirmation in the private release archive:

- `assets/mascot/tater-front.png`
- `assets/mascot/tater-salute.png`
- `assets/mascot/tater-wave.png`
- `assets/tater-tube-logo-leaning-transparent.png`
- all capsule/library/client graphics derived from that logo and mascot

## Supplied CRT-room key art — private company rights record

The orange CRT-room image used by the Steam capsules and Library Hero was
supplied by the product owner on September 7, 2026. Retain its original file
and creation/license record, and cover it in the rights attestation. The store
crops, darkened page background, and portrait adaptation are derivatives of
that source.

## Programmatic UI assets

`assets/tater-scanlines.png` and `assets/ui/tater-orange-glow.png` are simple
project-created UI textures. Store screenshots and trailer poster frames are
derivative captures of the Player UI and the cleared assets documented here.

## Licensed third-party trailer footage

The trailer's moving playback excerpt is Borys Zaitsev's Pexels video
“Stunning abstract animation of galaxy and stars in deep space.” Its source,
Pexels license, attribution, and source-file SHA-256 are retained in
`MEDIA_MANIFEST.md` and `trailer/README.md`. No music or third-party audio is
included in the trailer.

## Release check

Before each store-media update, verify that captures were made in demo mode and
contain no personal-server addresses, tokens, viewing history, scraped posters,
commercial media footage, real channel branding, or unreviewed assets.
