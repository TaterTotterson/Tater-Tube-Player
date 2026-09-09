# First Steam submission checklist

## Store presence

- [x] Steamworks app created: App ID `5239420`
- [x] Linux content depot created: Depot ID `5239421`
- [x] Product name selected: Tater Tube Player
- [x] English short description drafted
- [x] English About This Software copy drafted
- [x] Server requirement and no-media-included disclosure drafted
- [x] Seven rights-safe 4K 16:9 product screenshots captured; six selected for upload
- [x] At least five screenshots selected for upload
- [x] First 1080p H.264/AAC Steam Deck screen-recorded trailer cut created
- [x] Trailer includes genuine controller-style navigation and moving playback
- [x] Trailer poster frame created
- [x] Required store capsules rendered at current Valve dimensions
- [ ] Required store capsules uploaded in Steamworks
- [x] Website, support, and privacy links prepared for their dedicated fields
- [x] Steamworks field-by-field handoff prepared
- [x] Developer and publisher display names confirmed: `Tater Totterson AI LLC`
- [x] Price chosen: free
- [ ] Release / Coming Soon date chosen
- [ ] Languages set accurately
- [ ] Tags and software categories selected from Steam's available choices
- [ ] Controller-support fields completed without claiming Valve verification
- [ ] Verify the untouched Software-app Steam layout controls every screen on
  Steam Deck and DualSense without user configuration
- [ ] Content Survey completed, including pre-generated and live-generated AI
- [ ] Final store preview checked at desktop and narrow widths
- [ ] Store presence marked ready for review at least seven business days before its target publication

## Build review gates

These do not block drafting the store page, but they block submitting the build
as release-ready.

- [x] Produce a self-contained SteamOS/Linux depot; no Distrobox dependency
- [x] Prepare SteamPipe app/depot templates with preview mode enabled
- [ ] Test on a clean Steam Deck user profile
- [x] Choose and document the Qt LGPLv3 dynamic-linking distribution plan
- [x] Select Apache-2.0 for the player source and reserve the Tater Tube trademarks
- [x] Publish the public source repository
- [ ] Tag the exact submitted revision
- [ ] Confirm the Steam launch option does not use Steam DRM/CEG
- [x] Record Qt Multimedia, FFmpeg, codec libraries, SDL, and every shipped dependency
- [x] Generate the release SBOM and third-party notices
- [ ] Confirm source-offer/relinking obligations for the exact binaries in the depot
- [ ] Confirm mascot and other brand-asset creation/distribution records
- [x] Restrict the Linux settings file containing the paired-player token to the current OS user
- [ ] Verify clean install, first pairing, controller navigation, suspend/resume, output switching, and uninstall
- [ ] Verify direct play, audio-only transcode, video-only transcode, full transcode, HDR-to-SDR, and Tube TV transitions against Tater Tube Server 1.4.34+
- [ ] Supply Valve reviewers with a reachable test server or precise local test-server instructions and a rights-safe demo catalog
- [x] Confirm the draft depot and store media contain no private addresses, credentials, or personal media
- [x] Confirm the draft depot contains no emulator/ROM cores, game ports, Moonlight, downloader, commercial media, or Steamworks SDK binaries
- [x] Replace the GPL mpv draft dependency with an audited LGPL-only build path
- [ ] Complete and privately retain the brand/key-art rights attestation

## Current Valve requirements referenced

- Store screenshots: minimum five, 16:9, at least 1920 x 1080
- Required store capsules: 920 x 430 header, 462 x 174 small,
  1232 x 706 main, and 748 x 896 vertical
- Trailer: up to 1920 x 1080, 30 or 60 fps, 5000+ Kbps recommended;
  H.264 video and AAC audio preferred
- Store-presence review usually takes 3–5 business days; Valve recommends
  submitting at least seven business days before publication

Re-check the linked Steamworks documentation immediately before upload because
Valve can revise asset and review requirements.

- https://partner.steamgames.com/doc/store/assets
- https://partner.steamgames.com/doc/store/trailer
- https://partner.steamgames.com/doc/store/page/description
- https://partner.steamgames.com/doc/store/review_process
- https://partner.steamgames.com/doc/gettingstarted/contentsurvey
