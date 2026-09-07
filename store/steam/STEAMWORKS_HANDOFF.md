# Steamworks handoff

Use this order for the first Tater Tube Player submission. Nothing in this file
contains Steam account credentials, an App ID, or a Depot ID.

## 1. Create or select the Steamworks app

- App type: Software
- Product name: Tater Tube Player
- Price model: Free
- First platform: SteamOS / Linux, 64-bit
- Do not enable Steam DRM/CEG for the executable

Record the assigned App ID and Linux Depot ID. Generate the preview-only
SteamPipe files with:

```sh
./scripts/prepare-steampipe-preview.sh APP_ID DEPOT_ID
```

## 2. Enter the store copy

Use `STORE_PAGE.md` for the short description, About This Software text,
feature list, disclosures, system requirements, and dedicated URLs. Confirm the
developer and publisher display names before saving them in Steamworks.

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
named `Tater Tube Player — Product Tour`. The AAC silence is intentional.

## 5. Complete declarations

- Use `AI_DISCLOSURE.md` for the pre-generated and live-generated AI portions
  of the Steam Content Survey.
- State that Tater Tube Server 1.4.33 or newer is required and is not included.
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
