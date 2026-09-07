#!/bin/sh

set -eu

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 DEPOT_DIRECTORY" >&2
    exit 2
fi

tater_script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
tater_repo_dir=$(CDPATH= cd -- "${tater_script_dir}/.." && pwd)
tater_depot_dir=$(CDPATH= cd -- "$1" && pwd)
tater_compliance_dir="${tater_depot_dir}/compliance"
tater_license_dir="${tater_depot_dir}/licenses"
tater_binary="${tater_depot_dir}/bin/tater-tube-player"

mkdir -p "${tater_compliance_dir}/qt-sbom"

LD_LIBRARY_PATH="${tater_depot_dir}/lib" \
    "${tater_binary}" --version > "${tater_compliance_dir}/player-version.txt"

if command -v qtpaths6 >/dev/null 2>&1; then
    tater_qtpaths=qtpaths6
elif command -v qtpaths >/dev/null 2>&1; then
    tater_qtpaths=qtpaths
else
    echo "qtpaths is required to prepare the release compliance records." >&2
    exit 1
fi

"${tater_qtpaths}" --qt-version > "${tater_compliance_dir}/qt-version.txt"
tater_qt_prefix=$("${tater_qtpaths}" --query QT_INSTALL_PREFIX)

{
    echo "Builder: ${TATER_STEAM_RUNTIME_IMAGE:-unrecorded}"
    uname -a
    if command -v dpkg-query >/dev/null 2>&1; then
        dpkg-query -W -f='${Package} ${Version}\n' libsdl2-2.0-0 libsdl2-dev 2>/dev/null || true
    fi
} > "${tater_compliance_dir}/steam-runtime.txt"

for tater_sbom_root in \
    "${tater_qt_prefix}/share/qt/sbom" \
    "${tater_qt_prefix}/share/qt6/sbom" \
    "${tater_qt_prefix}/sbom"; do
    if [ -d "${tater_sbom_root}" ]; then
        find "${tater_sbom_root}" -maxdepth 1 -type f \
            \( -name 'qtbase-*.spdx' -o -name 'qtdeclarative-*.spdx' \
               -o -name 'qtmultimedia-*.spdx' \) \
            -exec cp {} "${tater_compliance_dir}/qt-sbom/" \;
    fi
done

if ! find "${tater_compliance_dir}/qt-sbom" -type f -name '*.spdx' | grep -q .; then
    echo "The official Qt SPDX documents were not found in ${tater_qt_prefix}." >&2
    exit 1
fi

for tater_qt_license_root in \
    "${tater_qt_prefix}/LICENSES" \
    "${tater_qt_prefix}/share/qt/LICENSES" \
    "${tater_qt_prefix}/share/qt6/LICENSES"; do
    if [ -d "${tater_qt_license_root}" ]; then
        mkdir -p "${tater_license_dir}/qt"
        cp "${tater_qt_license_root}"/* "${tater_license_dir}/qt/"
    fi
done

LD_LIBRARY_PATH="${tater_depot_dir}/lib" \
    ldd "${tater_binary}" > "${tater_compliance_dir}/runtime-dependencies.txt"

: > "${tater_compliance_dir}/all-runtime-dependencies.txt"
find "${tater_depot_dir}" -type f | while IFS= read -r tater_candidate; do
    if file "${tater_candidate}" | grep -q 'ELF 64-bit'; then
        printf '\n[%s]\n' "${tater_candidate#${tater_depot_dir}/}" \
            >> "${tater_compliance_dir}/all-runtime-dependencies.txt"
        LD_LIBRARY_PATH="${tater_depot_dir}/lib" ldd "${tater_candidate}" \
            >> "${tater_compliance_dir}/all-runtime-dependencies.txt" 2>&1 || true
    fi
done

find "${tater_depot_dir}" -type f \
    \( -name 'libavcodec.so*' -o -name 'libavformat.so*' \
       -o -name 'libavutil.so*' -o -name 'libswresample.so*' \
       -o -name 'libswscale.so*' \) \
    -print | sort > "${tater_compliance_dir}/bundled-media-libraries.txt"

tater_ffmpeg_sbom="${tater_compliance_dir}/qt-sbom/qtmultimedia-$(cat "${tater_compliance_dir}/qt-version.txt").spdx"
{
    echo "Bundled FFmpeg evidence"
    if [ -f "${tater_ffmpeg_sbom}" ]; then
        sed -n '/^PackageName: FFmpeg$/,/^Relationship:/p' "${tater_ffmpeg_sbom}"
    fi
    tater_avutil=$(find "${tater_depot_dir}/lib" -type f -name 'libavutil.so.*.*.*' | head -n 1)
    if [ -n "${tater_avutil}" ]; then
        echo
        echo "Embedded configuration string"
        strings "${tater_avutil}" | grep -E -m 1 '(^| )--(enable|disable)-' || true
    fi
} > "${tater_compliance_dir}/bundled-ffmpeg.txt"

tater_player_revision=$(git -C "${tater_repo_dir}" rev-parse HEAD 2>/dev/null || echo unavailable)
tater_player_tree_state=clean
if [ -n "$(git -C "${tater_repo_dir}" status --porcelain 2>/dev/null || true)" ]; then
    tater_player_tree_state=dirty-draft
fi

tater_app_source_url=${TATER_APP_SOURCE_URL:-"https://github.com/TaterTotterson/Tater-Tube-Player"}
tater_app_source_sha256=${TATER_APP_SOURCE_SHA256:-"attach before Steam submission"}
tater_qt_source_url=${TATER_QT_SOURCE_URL:-"attach before Steam submission"}
tater_qt_source_sha256=${TATER_QT_SOURCE_SHA256:-"attach before Steam submission"}
tater_ffmpeg_source_url=${TATER_FFMPEG_SOURCE_URL:-"attach before Steam submission"}
tater_ffmpeg_source_sha256=${TATER_FFMPEG_SOURCE_SHA256:-"attach before Steam submission"}

cat > "${tater_license_dir}/source-manifest.txt" <<EOF
Tater Tube Player source
  ${tater_app_source_url}
  Revision: ${tater_player_revision}
  Tree state: ${tater_player_tree_state}
  SHA-256: ${tater_app_source_sha256}

Qt corresponding source
  Version: $(cat "${tater_compliance_dir}/qt-version.txt")
  Archive: ${tater_qt_source_url}
  SHA-256: ${tater_qt_source_sha256}

FFmpeg corresponding source
  Version and configuration: compliance/bundled-ffmpeg.txt
  Archive: ${tater_ffmpeg_source_url}
  SHA-256: ${tater_ffmpeg_source_sha256}
EOF

if grep -q 'attach before Steam submission' "${tater_license_dir}/source-manifest.txt"; then
    cat >> "${tater_license_dir}/source-manifest.txt" <<EOF

This placeholder is intentionally rejected by audit-steam-depot.sh until the
release-controlled archive locations and SHA-256 hashes are filled in.
EOF
fi

(
    cd "${tater_depot_dir}"
    find . -type f ! -path './compliance/SHA256SUMS' -print0 \
        | sort -z \
        | xargs -0 sha256sum > compliance/SHA256SUMS
)
