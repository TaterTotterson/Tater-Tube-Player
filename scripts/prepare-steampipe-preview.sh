#!/bin/sh
set -eu

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 APP_ID DEPOT_ID" >&2
    exit 2
fi

tater_app_id=$1
tater_depot_id=$2

case "$tater_app_id" in
    *[!0-9]*|'')
        echo "APP_ID must contain only digits." >&2
        exit 2
        ;;
esac

case "$tater_depot_id" in
    *[!0-9]*|'')
        echo "DEPOT_ID must contain only digits." >&2
        exit 2
        ;;
esac

tater_repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tater_depot_name=${TATER_STEAM_DEPOT_NAME:-linux-x86_64}
tater_steampipe_name=${TATER_STEAMPIPE_NAME:-steampipe}
tater_builder_image=${TATER_STEAM_BUILDER_IMAGE:-tater-tube-player-steam-builder:latest}

case "$tater_depot_name" in
    *[!A-Za-z0-9._-]*|'')
        echo "TATER_STEAM_DEPOT_NAME must be a directory name under dist/steam." >&2
        exit 2
        ;;
esac
case "$tater_steampipe_name" in
    *[!A-Za-z0-9._-]*|'')
        echo "TATER_STEAMPIPE_NAME must be a directory name under dist/steam." >&2
        exit 2
        ;;
esac

tater_depot_dir="$tater_repo_dir/dist/steam/$tater_depot_name"
tater_output_dir="$tater_repo_dir/dist/steam/$tater_steampipe_name"
tater_scripts_dir="$tater_output_dir/scripts"
tater_version=$(awk '
    /^project\(TaterTubePlayer/ { in_project = 1 }
    in_project && $1 == "VERSION" { print $2; exit }
' "$tater_repo_dir/CMakeLists.txt")

if [ -z "$tater_version" ]; then
    echo "Could not read the player version from CMakeLists.txt." >&2
    exit 1
fi

if [ ! -x "$tater_depot_dir/tater-tube-player" ]; then
    echo "Build and audit dist/steam/$tater_depot_name before preparing SteamPipe." >&2
    exit 1
fi

case "$(uname -s)" in
    Linux)
        "$tater_repo_dir/scripts/audit-steam-depot.sh" "$tater_depot_dir"
        ;;
    *)
        if ! command -v docker >/dev/null 2>&1 || \
            ! docker image inspect "$tater_builder_image" >/dev/null 2>&1; then
            echo "The non-Linux host needs the $tater_builder_image image to audit the depot." >&2
            echo "Build the image as documented in packaging/steam/README.md, then retry." >&2
            exit 1
        fi
        docker run --rm --platform linux/amd64 \
            --env "TATER_STEAM_DRAFT=${TATER_STEAM_DRAFT:-0}" \
            --volume "$tater_repo_dir:/workspace" \
            "$tater_builder_image" \
            ./scripts/audit-steam-depot.sh "/workspace/dist/steam/$tater_depot_name"
        ;;
esac

mkdir -p "$tater_scripts_dir" "$tater_output_dir/output"

sed \
    -e "s/@APP_ID@/$tater_app_id/g" \
    -e "s/@DEPOT_ID@/$tater_depot_id/g" \
    -e "s/@VERSION@/$tater_version/g" \
    -e "s|@CONTENT_ROOT@|../../$tater_depot_name|g" \
    "$tater_repo_dir/packaging/steam/app_build_APPID.vdf.in" \
    > "$tater_scripts_dir/app_build_$tater_app_id.vdf"

sed \
    -e "s/@DEPOT_ID@/$tater_depot_id/g" \
    "$tater_repo_dir/packaging/steam/depot_build_DEPOTID.vdf.in" \
    > "$tater_scripts_dir/depot_build_$tater_depot_id.vdf"

echo "SteamPipe preview scripts ready:"
echo "  $tater_scripts_dir/app_build_$tater_app_id.vdf"
echo "  $tater_scripts_dir/depot_build_$tater_depot_id.vdf"
echo
echo "Preview is enabled, so SteamCMD will validate the file mapping without uploading content."
