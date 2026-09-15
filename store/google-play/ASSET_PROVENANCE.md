# Google Play asset provenance

Keep this record with the private company rights attestation for every release.

## Brand elements

- The Tater Tube name, wordmark, and mascot are Tater Totterson AI LLC brand
  assets.
- `../../assets/tater-tube-logo-leaning-transparent.png` supplies the unchanged
  wordmark and leaning mascot used in the feature graphic and TV banner.
- `../../google-tv/app/src/main/res/drawable-nodpi/tater_launcher_icon.png`
  supplies the mascot used in the Play Store icon.

## AI-assisted background

The original background retained as `source/tater-tv-room-master.png` was
generated for this project with OpenAI's image-generation tool on September 15,
2026 and reviewed before inclusion. It contains no third-party entertainment
artwork, characters, logos, or readable media labels.

Final generation prompt:

> Create a polished cinematic Tater Tube brand backdrop featuring a centered
> mid-century CRT television glowing with rich orange static in a dark
> retro-futurist media room. Use black and charcoal surfaces, subtle shelves of
> generic blank tapes and media, a small orange lava lamp, restrained warm
> orange practical lights, OLED-friendly blacks, and clean negative space for
> the existing logo. Include no people, mascot, logo, words, recognizable media,
> copyrighted characters, or watermark.

The final graphics were composed deterministically from that background and the
existing brand assets. No `Player` subtitle or third-party media art appears.

## Demo media and screenshots

- `../../google-tv/app/src/main/res/raw/tater_demo_reel.mp4` is assembled only
  from the fictional demo-library artwork in `../../assets/demo/`.
- Its audio is an original procedural tone bed created during encoding; it does
  not contain commercial music, speech, or sampled audio.
- Final screenshots must be captured in Try Demo mode from the signed Google TV
  build and must not contain a user's library or discovery results.

When Play Console asks whether an uploaded asset was generated or edited with
AI, answer accurately for the applicable background, fictional artwork, mascot,
or screenshot.
