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
| Tater Tube Player | Main application | Apache-2.0; public tagged source | Enforced by the final-depot audit |
| Qt 6.11.2 | Dynamically linked shared libraries and QML plugins | LGPLv3; license, source, module SBOMs, and relinking instructions | Corresponding-source records enforced by the final-depot audit |
| FFmpeg 7.1.5 | Dynamically linked shared libraries used by Qt Multimedia and mpv | LGPLv2.1+ and permissive parts; GPL/version3/nonfree disabled | Configuration and corresponding-source records enforced by the final-depot audit |
| ICU 73.2 | Dynamically linked shared libraries supplied with Qt | Unicode License; full license/data notices included | Recorded |
| SDL 2.32.70 | Dynamically linked from Steam Runtime 4; not copied into depot | Zlib | Recorded |
| mpv 0.40.0 | Separate executable launched through local IPC; not linked into the Player | LGPLv2.1+ build with `-Dgpl=false`; GPL-only X11 path disabled | Configuration and corresponding-source records enforced by the final-depot audit |
| libplacebo 7.349.0-3 | Dynamically linked shared library used by mpv | LGPLv2.1+; upstream source plus exact Debian source delta | Source package revision and delta retained in the release archive |
| Steamworks SDK | Not linked or distributed | Not applicable | Confirmed absent from the release depot |

The earlier test draft's Debian GPL mpv package has been removed from the
release path. The release container now builds mpv from pinned source with
`-Dgpl=false` and builds its shared FFmpeg dependency with GPL, version-3, and
nonfree parts disabled. The exact build records and licenses are installed in
the depot and checked by the release audit. Steam Gaming Mode uses mpv's
LGPL-compatible SDL video output on Gamescope's XWayland surface rather than
mpv's GPL-only native X11 output.

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
are not represented as a separately registered composite. Tater Totterson AI
LLC retains its logo, mascot, and CRT-room ownership/distribution confirmation
privately using `store/steam/RIGHTS_ATTESTATION_TEMPLATE.md`; signatures and
private registration information do not belong in the public repository.

## Release controls

These are Tater Totterson AI LLC release responsibilities, not tasks assigned
to Valve. The automated final-depot process enforces the source and binary
controls; the company completes the Steamworks and ownership records privately.

1. Build only from the clean tag matching the application version.
2. Publish the matching Player and third-party source archives and record their
   reachable HTTPS URLs and SHA-256 hashes in the depot source manifest.
3. Run the final-depot and Steam Runtime 4 audits.
4. Keep Steam DRM/CEG disabled so LGPL libraries remain replaceable.
5. Complete the Steam AI/content disclosures and state that Tater Tube Server
   is required and no media is included.
6. Retain the company ownership/distribution attestation in the private release
   archive.
7. Test the exact uploaded build through Steam and provide Valve the built-in
   rights-safe demo mode for evaluation.

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
> personal media library. The matching application and third-party source are
> published with the versioned release at
> https://github.com/TaterTotterson/Tater-Tube-Player/releases.
