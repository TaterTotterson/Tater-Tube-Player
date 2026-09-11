# Steamworks handoff

Use this order for the first Tater Tube Player submission. Nothing in this file
contains Steam account credentials. All setup, testing, licensing, and rights
steps in this handoff are developer/publisher responsibilities; it does not ask
Valve to perform them.

Confirmed Steamworks identifiers:

- App ID: `5239420`
- Linux content Depot ID: `5239421`

## 1. Create or select the Steamworks app

- App type: Software
- Product name: Tater Tube Player
- Price model: Free
- First platform: SteamOS / Linux, 64-bit
- Do not enable Steam DRM/CEG for the executable

The app and Linux depot are now created. Generate the preview-only SteamPipe
files with:

```sh
TATER_STEAM_DRAFT=1 ./scripts/prepare-steampipe-preview.sh 5239420 5239421
```

`TATER_STEAM_DRAFT=1` is appropriate only while validating an uncommitted test
build. The final upload must be rebuilt from the clean, tagged release tree.

## 2. Enter the store copy

Use `STORE_PAGE.md` for the short description, About This Software text,
feature list, disclosures, system requirements, and dedicated URLs. Set both
the developer and publisher display names to `Tater Totterson AI LLC`.
Paste the About copy as plain text, then use Steamworks' visual editor to style
the standalone headings and bold the server-requirement paragraph. Do not paste
`[h2]` or `[b]` tags because the current editor renders them as text.

## 3. Upload store graphics

Upload the exact-size files from `graphics/store/`:

- Header Capsule: `header-capsule-920x430.png`
- Small Capsule: `small-capsule-462x174.png`
- Main Capsule: `main-capsule-1232x706.png`
- Vertical Capsule: `vertical-capsule-748x896.png`
- Store Page Background, if used: `page-background-1438x810.png`

Upload the Steam Library and client artwork from `graphics/library/` and
`graphics/client/` to their matching fields. Keep the transparent
`library-logo-1280x720.png` separate from the artwork-only Library Hero.

## 4. Upload screenshots and trailer

Upload these screenshots in order:

1. `screenshots/01-home.png`
2. `screenshots/02-library.png`
3. `screenshots/03-details.png`
4. `screenshots/05-live-tv.png`
5. `screenshots/04-tater-picks.png`
6. `screenshots/06-search.png`

Upload `trailer/tater-tube-player-store-trailer-v1.mp4` as a Gameplay trailer
named `Tater Tube Player — Product Tour`. It is a genuine Steam Deck capture
with controller-style menu navigation and real moving demo playback. The AAC
silence is intentional.

## 5. Complete declarations

- Use `AI_DISCLOSURE.md` for the pre-generated and live-generated AI portions
  of the Steam Content Survey.
- State that Tater Tube Server 1.4.46 or newer is required and is not included.
- State that the application supplies no movies, television programs, or live
  channels.
- Do not claim Steam Deck Verified. Valve assigns compatibility after review.
- Answer controller support according to the exact build tested through Steam.

## 6. Configure and test the build

General Installation launch option:

- Executable: `tater-tube-player`
- OS: Linux
- Architecture: 64-bit
- Arguments: none
- Runtime: Steam Linux Runtime 4.0

Steam Input configuration:

- Keep the Steam Input API integration survey set to `No`.
- The Software app type currently receives Steam's standard `Keyboard (WASD)
  and Mouse` controller template. The player intentionally maps its Deck and
  DualSense outputs—WASD, 1/2/3/4, Space, E, R, F, Escape, and Tab—to the same
  navigation and playback actions as a native SDL gamepad.
- During playback, X/R reveals the overlay and then cycles audio tracks; Y/F
  reveals it and then cycles subtitles. The overlay itself has no focus
  navigation state.
- Do not require customers to select a different controller template.
- Test the untouched Steam default on both the built-in Deck controls and a
  DualSense before marking controller-support fields complete.

Run the generated SteamPipe file once while `Preview` remains `1`. After its
manifest is correct, set `Preview` to `0`, upload it without `SetLive`, and put
the resulting build on a private test branch. Install that branch through the
Steam client on a clean Deck profile; do not test only by copying the depot.

Complete every hardware and playback gate in `SUBMISSION_CHECKLIST.md` before
selecting the build for review.

## 7. Submit for review

Publish all pending Steamworks configuration changes, inspect the store page at
desktop and narrow widths, and submit the store presence and build for review.
Allow at least seven business days before the intended public release date.
