# Steam Linux depot

The production depot targets 64-bit Linux under Steam Linux Runtime 4.0. Valve
recommends compiling native Linux applications in the matching runtime SDK; the
Containerfile supplies that environment and installs the official shared Qt
distribution.

The Steam Deck Arch/Distrobox build is only for fast hardware development. Its
GPL-enabled system FFmpeg must not be redistributed.

## Build

From the repository root on a machine with Docker:

```sh
docker build --platform linux/amd64 \
  --file packaging/steam/Containerfile \
  --tag tater-tube-player-steam-builder .

docker run --rm --platform linux/amd64 \
  --volume "$PWD:/workspace" \
  tater-tube-player-steam-builder \
  ./scripts/build-steam-depot.sh
```

The script creates `dist/steam/linux-x86_64/`. It refuses to overwrite an
existing depot so stale libraries cannot silently survive between builds.

After committing the exact release revision, prepare the retained source
archives with:

```sh
./scripts/prepare-steam-source-offer.sh dist/steam/source-offer-release
```

Publish both generated archives with the matching GitHub release, then pass
their public URLs and SHA-256 values as `TATER_APP_SOURCE_*`,
`TATER_QT_SOURCE_*`, and `TATER_FFMPEG_SOURCE_*` when producing the final
non-draft depot. The final audit rejects dirty source trees and placeholder
source locations.

## Steamworks launch settings

- Executable: `tater-tube-player`
- Operating system: Linux
- Architecture: 64-bit
- Linux Runtime: Steam Linux Runtime 4.0
- Arguments: none
- Steam DRM/CEG: disabled

Upload the complete `linux-x86_64` directory as the Linux depot. The top-level
launcher is required because it makes the shipped shared libraries and QML
modules replaceable and relocatable.

## SteamPipe preview

After Steamworks assigns the app and Linux depot IDs, generate the build files:

```sh
./scripts/prepare-steampipe-preview.sh APP_ID DEPOT_ID
```

This re-runs the depot audit and creates the matching files under
`dist/steam/steampipe/scripts/`. The generated app build has SteamPipe's
`Preview` option enabled and no `SetLive` value, so the first SteamCMD run only
validates the manifest and file mapping. It does not upload or publish the
depot.

Run that preview with the current Steamworks SDK, replacing the account name:

```sh
steamcmd +login STEAM_BUILD_ACCOUNT \
  +run_app_build "$PWD/dist/steam/steampipe/scripts/app_build_APP_ID.vdf" \
  +quit
```

Once the preview manifest is correct, change `"Preview" "1"` to
`"Preview" "0"` in the generated file and run it again to upload. Leave
`SetLive` absent for the first submission; select the uploaded build on a
private test branch in Steamworks after upload. Never put a Steam password or
Steam Guard code in this repository or a build script.
