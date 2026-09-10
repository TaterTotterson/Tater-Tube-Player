# Steam release-rights audit

Audit date: September 10, 2026

This is an engineering and release-record audit, not legal advice. Valve makes
the final distribution decision, and the Steam Distribution Agreement places
the rights warranty on the developer.

## Scope

The audit covers the Tater Tube Player source tree, the generated Linux x86-64
Steam depot, and the Steam store media under `store/steam/`. It does not cover
Tater Tube Classic, Tater Tube Server, user libraries, or server-installed
plugins because none of those are copied into the Player depot.

## Material difference from Tater Tube Classic

The Player is an independent client rather than a repackaging of the retired
retro application. Its source and depot contain no RetroArch or libretro
cores, emulator packages, game ports, ROM or BIOS files, Moonlight runtime,
YouTube downloader, Plex/Emby/Jellyfin client, or commercial movie/television
content. Tater Tube Server is contacted only through its network API and is
not distributed with the Player.

The Player also does not link or ship the Steamworks SDK. In particular, the
depot contains no `libsteam_api.so`, and the release plan forbids Steam DRM or
CEG so users remain able to replace LGPL libraries.

## Distributed software

| Component | Distribution relationship | License plan | Status |
| --- | --- | --- | --- |
| Tater Tube Player | Main application | Apache-2.0; public tagged source | Ready after clean release tag |
| Qt 6.11.2 | Dynamically linked shared libraries and QML plugins | LGPLv3; license, source, module SBOMs, and relinking instructions | Plan complete; final source URLs pending |
| FFmpeg 7.1.5 | Dynamically linked shared libraries used by Qt Multimedia and mpv | LGPLv2.1+ and permissive parts; GPL/version3/nonfree disabled | Configuration audited; final source URL pending |
| ICU 73.2 | Dynamically linked shared libraries supplied with Qt | Unicode License; full license/data notices included | Recorded |
| SDL 2.32.70 | Dynamically linked from Steam Runtime 4; not copied into depot | Zlib | Recorded |
| mpv 0.40.0 | Separate executable launched through local IPC; not linked into the Player | LGPLv2.1+ build with `-Dgpl=false`; GPL-only X11 path disabled | Configuration audited; final source URL and hardware validation pending |
| Steamworks SDK | Not linked or distributed | Not applicable | Confirmed absent from draft depot |

The earlier test draft's Debian GPL mpv package has been removed from the
release path. The release container now builds mpv from pinned source with
`-Dgpl=false` and builds its shared FFmpeg dependency with GPL, version-3, and
nonfree parts disabled. The exact build records and licenses are installed in
the depot and checked by the release audit. Gamescope uses the retained
Wayland/Vulkan path rather than mpv's GPL-only X11 output.

## Shipped and marketing content

Demo mode ships only fictional catalog data and project-created artwork. Store
screenshots are genuine captures of that mode. The trailer uses a documented,
licensed Pexels clip; its source URL, license URL, author, and source-file hash
are recorded in `store/steam/MEDIA_MANIFEST.md`.

Generative tools assisted with original mascot, demo-library, category, and
channel art. The Steam Content Survey must disclose both this pre-generated
material and the optional live Tater Picks feature exactly as documented in
`store/steam/AI_DISCLOSURE.md`.

The owner has stated that the underlying Tater logo/wordmark is protected by
the company's trademark rights. The `Tube` addition and combined presentation
are not represented as a separately registered composite. The remaining
asset-chain item is a written owner confirmation covering distribution of the
complete Tater Tube logo, mascot, and supplied orange CRT-room key art. Use
`store/steam/RIGHTS_ATTESTATION_TEMPLATE.md` and retain the signed record with
the release archive; do not place a signature or private information in the
public repository.

## Blocks on final build submission

The current uploaded build is a private test draft and must not be submitted
for Valve build review. A final build is blocked until all of the following
are true:

1. Validate the LGPL-only mpv/FFmpeg candidate on Steam Deck and HDMI displays.
2. Commit all intended code and media, create the exact release tag, and build
   from a clean tree.
3. Publish the Player and third-party source archives for that tag, then place
   their reachable URLs and SHA-256 hashes in the depot source manifest.
4. Complete and retain the logo, mascot, and CRT-room rights attestation.
   Confirm the company's ownership or distribution authority for the original
   application contributions at the same time.
5. Complete the Steam AI/content disclosures and ensure the store page states
   that Tater Tube Server is required and no media is included.
6. Keep Steam DRM/CEG disabled and rerun the non-draft depot audit.
7. Test the exact uploaded final build on a clean Steam Deck account/profile
   and provide Valve a rights-safe demo server or deterministic demo mode.
8. Complete a separate codec-patent review for the intended distribution
   territories; open-source copyright licenses do not grant patent rights.

The audit script intentionally rejects a dirty final build, a revision that is
not the exact matching version tag, placeholder or non-HTTPS source locations,
invalid source hashes, forbidden ROM/game/media payloads, old-runtime
components, Steamworks binaries, a mismatched depot SHA-256 inventory, an mpv
build that is not recorded with `gpl=false`, or an FFmpeg build missing the
required GPL/nonfree disable flags.

## Suggested Valve reviewer note

> Tater Tube Player is a new, standalone personal-media client and is not the
> previously retired Tater Tube retro application. This build contains no
> emulators, ROM cores, BIOS files, game ports, or bundled movies/television.
> It connects only to a user-operated Tater Tube Server. The application source
> is Apache-2.0 and public. Third-party license texts, exact versions, SBOMs,
> source locations, and relinking instructions are included in the depot. The
> app does not link or distribute the Steamworks SDK and does not use Steam
> DRM/CEG. Reviewers may use the built-in rights-safe demo mode without a
> personal media library.

Add the final public release/tag and corresponding-source links to that note
before sending it.
