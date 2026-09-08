#!/bin/sh

set -eu

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 OUTPUT_DIRECTORY" >&2
    exit 2
fi

tater_script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
tater_repo_dir=$(CDPATH= cd -- "${tater_script_dir}/.." && pwd)
tater_output_dir=$1
tater_qt_version=6.11.2
tater_ffmpeg_version=7.1.5
tater_icu_version=73.2
tater_mpv_version=0.40.0
tater_release_depot=${TATER_STEAM_DEPOT_DIR:-"${tater_repo_dir}/dist/steam/linux-x86_64"}
tater_player_version=$(sed -n 's/^[[:space:]]*VERSION[[:space:]]\{1,\}\([0-9][0-9.]*\).*/\1/p' \
    "${tater_repo_dir}/CMakeLists.txt" | head -n 1)
tater_source_cache_dir=${TATER_SOURCE_CACHE_DIR:-}

if [ -z "${tater_player_version}" ]; then
    echo "Could not read the player version from CMakeLists.txt." >&2
    exit 1
fi
if [ -e "${tater_output_dir}" ]; then
    echo "Refusing to overwrite existing source-offer directory: ${tater_output_dir}" >&2
    exit 1
fi
if [ -n "$(git -C "${tater_repo_dir}" status --porcelain)" ]; then
    echo "The source offer must be generated from a clean source tree." >&2
    exit 1
fi
for tater_release_record in bundled-ffmpeg.txt ffmpeg-build-config.txt \
        mpv-build-options.txt mpv-version.txt; do
    if [ ! -f "${tater_release_depot}/compliance/${tater_release_record}" ]; then
        echo "Missing exact release record: ${tater_release_depot}/compliance/${tater_release_record}" >&2
        exit 1
    fi
done

tater_sha256()
{
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    else
        shasum -a 256 "$1" | awk '{print $1}'
    fi
}

tater_fetch()
{
    tater_file=$1
    tater_url=$2
    tater_expected=$3
    if [ -n "${tater_source_cache_dir}" ] \
        && [ -f "${tater_source_cache_dir}/${tater_file}" ]; then
        cp "${tater_source_cache_dir}/${tater_file}" \
            "${tater_bundle_dir}/upstream/${tater_file}"
    else
        curl -fL --retry 3 --output "${tater_bundle_dir}/upstream/${tater_file}" "${tater_url}"
    fi
    tater_actual=$(tater_sha256 "${tater_bundle_dir}/upstream/${tater_file}")
    if [ "${tater_actual}" != "${tater_expected}" ]; then
        echo "SHA-256 mismatch for ${tater_file}" >&2
        echo "Expected ${tater_expected}; received ${tater_actual}" >&2
        exit 1
    fi
    printf '%s  upstream/%s\n' "${tater_actual}" "${tater_file}" \
        >> "${tater_bundle_dir}/SHA256SUMS"
}

tater_temp_dir=$(mktemp -d)
trap 'rm -rf "${tater_temp_dir}"' EXIT HUP INT TERM
tater_bundle_dir="${tater_temp_dir}/tater-tube-player-third-party-sources-${tater_player_version}"
mkdir -p "${tater_bundle_dir}/upstream" "${tater_output_dir}"

tater_fetch qtbase-everywhere-src-6.11.2.tar.xz \
    https://download.qt.io/official_releases/qt/6.11/6.11.2/submodules/qtbase-everywhere-src-6.11.2.tar.xz \
    5b2e00eccaf5a4d8c14134ffa0ea8dfd0a35ae1ffc7f8d87fa4305a1ed23cf22
tater_fetch qtdeclarative-everywhere-src-6.11.2.tar.xz \
    https://download.qt.io/official_releases/qt/6.11/6.11.2/submodules/qtdeclarative-everywhere-src-6.11.2.tar.xz \
    215b7b70517e380123eabc6b92243f3c47b6f016a91d126057dbe53551c6b430
tater_fetch qtmultimedia-everywhere-src-6.11.2.tar.xz \
    https://download.qt.io/official_releases/qt/6.11/6.11.2/submodules/qtmultimedia-everywhere-src-6.11.2.tar.xz \
    967b5e02ec6b793cdb360622cd6e703132836af983208d678dae4b50f109cd9f
tater_fetch qtsvg-everywhere-src-6.11.2.tar.xz \
    https://download.qt.io/official_releases/qt/6.11/6.11.2/submodules/qtsvg-everywhere-src-6.11.2.tar.xz \
    d594337feca84c26fb67fe87b85e6a5c12fda404b611d905f9d138210c311876
tater_fetch qtwayland-everywhere-src-6.11.2.tar.xz \
    https://download.qt.io/official_releases/qt/6.11/6.11.2/submodules/qtwayland-everywhere-src-6.11.2.tar.xz \
    8eb7615e39332a10f506e8dd70f02d5954bb5949ff54f6dcbf8bd6168222f9df
tater_fetch ffmpeg-7.1.5.tar.xz \
    https://ffmpeg.org/releases/ffmpeg-7.1.5.tar.xz \
    de668509caf9e35e3cd162473441fdb29538c6d96ed080292b3cf9e6fc5d558f
tater_fetch icu4c-73_2-src.tgz \
    https://github.com/unicode-org/icu/releases/download/release-73-2/icu4c-73_2-src.tgz \
    818a80712ed3caacd9b652305e01afc7fa167e6f2e94996da44b90c2ab604ce1
tater_fetch mpv_0.40.0.orig.tar.gz \
    https://deb.debian.org/debian/pool/main/m/mpv/mpv_0.40.0.orig.tar.gz \
    10a0f4654f62140a6dd4d380dcf0bbdbdcf6e697556863dc499c296182f081a3

cp "${tater_repo_dir}/THIRD_PARTY_NOTICES.md" "${tater_bundle_dir}/"
cp "${tater_repo_dir}/docs/RELINKING_QT.md" "${tater_bundle_dir}/"
cp "${tater_repo_dir}/packaging/steam/Containerfile" "${tater_bundle_dir}/"
cp "${tater_release_depot}/compliance/bundled-ffmpeg.txt" "${tater_bundle_dir}/"
cp "${tater_release_depot}/compliance/ffmpeg-build-config.txt" "${tater_bundle_dir}/"
cp "${tater_release_depot}/compliance/mpv-build-options.txt" "${tater_bundle_dir}/"
cp "${tater_release_depot}/compliance/mpv-version.txt" "${tater_bundle_dir}/"

cat > "${tater_bundle_dir}/README.txt" <<EOF
Tater Tube Player ${tater_player_version} corresponding third-party source

This archive contains the exact upstream source releases retained for the
shared Qt and FFmpeg libraries in the Steam/Linux depot:

  Qt ${tater_qt_version}: qtbase, qtdeclarative, qtmultimedia, qtsvg, qtwayland
  FFmpeg ${tater_ffmpeg_version}
  ICU ${tater_icu_version}
  mpv ${tater_mpv_version}

The original compressed archives are preserved under upstream/ and verified by
SHA256SUMS. The build Containerfile, notices, exact FFmpeg configure record,
exact mpv Meson option record, and Qt relinking instructions are included
alongside them. No local patches were applied to Qt, FFmpeg, ICU, or mpv.

The Containerfile builds FFmpeg with GPL, nonfree, and version-3 components
disabled, then builds the separately launched mpv executable with
-Dgpl=false. The resulting mpv is distributed under LGPLv2.1-or-later.
EOF

tater_app_archive="${tater_output_dir}/tater-tube-player-${tater_player_version}-source.tar.gz"
tater_third_party_archive="${tater_output_dir}/tater-tube-player-${tater_player_version}-third-party-sources.tar"

git -C "${tater_repo_dir}" archive --format=tar.gz \
    --prefix="Tater-Tube-Player-${tater_player_version}/" \
    --output="${tater_app_archive}" HEAD
tar -C "${tater_temp_dir}" -cf "${tater_third_party_archive}" \
    "$(basename "${tater_bundle_dir}")"

tater_app_sha256=$(tater_sha256 "${tater_app_archive}")
tater_third_party_sha256=$(tater_sha256 "${tater_third_party_archive}")
{
    printf '%s  %s\n' "${tater_app_sha256}" "$(basename "${tater_app_archive}")"
    printf '%s  %s\n' "${tater_third_party_sha256}" \
        "$(basename "${tater_third_party_archive}")"
} > "${tater_output_dir}/SHA256SUMS"

echo "Steam corresponding-source offer ready: ${tater_output_dir}"
