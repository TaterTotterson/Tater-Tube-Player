#!/bin/sh

set -eu

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 DEPOT_DIRECTORY" >&2
    exit 2
fi

tater_depot_dir=$(CDPATH= cd -- "$1" && pwd)
tater_binary="${tater_depot_dir}/bin/tater-tube-player"
tater_failed=0

tater_require_file() {
    if [ ! -f "${tater_depot_dir}/$1" ]; then
        echo "Missing required depot file: $1" >&2
        tater_failed=1
    fi
}

for tater_required in \
    tater-tube-player \
    bin/tater-tube-player \
    licenses/LICENSE \
    licenses/NOTICE \
    licenses/PRIVACY.md \
    licenses/THIRD_PARTY_NOTICES.md \
    licenses/LGPL-3.0-only.txt \
    licenses/GPL-3.0-only.txt \
    licenses/LGPL-2.1-or-later.txt \
    licenses/RELINKING_QT.md \
    licenses/source-manifest.txt \
    compliance/runtime-dependencies.txt \
    compliance/all-runtime-dependencies.txt \
    compliance/bundled-ffmpeg.txt \
    compliance/steam-runtime.txt \
    compliance/SHA256SUMS; do
    tater_require_file "${tater_required}"
done

if [ ! -x "${tater_depot_dir}/tater-tube-player" ]; then
    echo "The top-level Steam launcher is not executable." >&2
    tater_failed=1
fi

if grep -q 'not found' "${tater_depot_dir}/compliance/all-runtime-dependencies.txt" 2>/dev/null; then
    echo "At least one shipped ELF or Qt plugin has an unresolved dependency:" >&2
    grep -B 1 'not found' "${tater_depot_dir}/compliance/all-runtime-dependencies.txt" >&2
    tater_failed=1
fi

if grep -E -q -- '--enable-(gpl|nonfree|libx264|libx265)' \
    "${tater_depot_dir}/compliance/bundled-ffmpeg.txt" 2>/dev/null; then
    echo "The bundled FFmpeg configuration enables a forbidden GPL/nonfree component." >&2
    tater_failed=1
fi

if [ -f "${tater_binary}" ]; then
    if ! file "${tater_binary}" | grep -q 'ELF 64-bit.*x86-64'; then
        echo "The player is not a Linux x86-64 ELF executable." >&2
        tater_failed=1
    fi

    tater_ldd=$(LD_LIBRARY_PATH="${tater_depot_dir}/lib" ldd "${tater_binary}" 2>&1 || true)
    if printf '%s\n' "${tater_ldd}" | grep -q 'not found'; then
        echo "The depot has unresolved runtime dependencies:" >&2
        printf '%s\n' "${tater_ldd}" | grep 'not found' >&2
        tater_failed=1
    fi
    if ! printf '%s\n' "${tater_ldd}" | grep -q 'libQt6Core.so'; then
        echo "Qt Core was not detected as a dynamic dependency." >&2
        tater_failed=1
    fi
fi

if find "${tater_depot_dir}" -type f \
    \( -name 'libx264.so*' -o -name 'libx265.so*' -o -name 'libQt6HttpServer.so*' \
       -o -name 'libQt6VirtualKeyboard.so*' -o -name 'libsteam_api.so*' \) \
    | grep -q .; then
    echo "The depot contains a forbidden GPL-only or Steamworks runtime library." >&2
    find "${tater_depot_dir}" -type f \
        \( -name 'libx264.so*' -o -name 'libx265.so*' -o -name 'libQt6HttpServer.so*' \
           -o -name 'libQt6VirtualKeyboard.so*' -o -name 'libsteam_api.so*' \) >&2
    tater_failed=1
fi

if grep -R -I -E -n \
    '(Bearer[[:space:]]+[A-Za-z0-9._-]{20,}|password[[:space:]]*[:=][[:space:]]*[^[:space:]]+|10\.[0-9]+\.[0-9]+\.[0-9]+|192\.168\.[0-9]+\.[0-9]+)' \
    "${tater_depot_dir}" \
    --exclude='audit-steam-depot.sh' >/dev/null 2>&1; then
    echo "The depot contains a possible credential or private address." >&2
    tater_failed=1
fi

if grep -q 'attach before Steam submission' \
    "${tater_depot_dir}/licenses/source-manifest.txt" 2>/dev/null; then
    if [ "${TATER_STEAM_DRAFT:-0}" = "1" ]; then
        echo "Draft depot: corresponding-source archive locations are still placeholders." >&2
    else
        echo "The corresponding-source manifest still contains release placeholders." >&2
        tater_failed=1
    fi
fi

if grep -q 'Tree state: dirty-draft' \
    "${tater_depot_dir}/licenses/source-manifest.txt" 2>/dev/null; then
    if [ "${TATER_STEAM_DRAFT:-0}" = "1" ]; then
        echo "Draft depot: player source tree contains uncommitted work." >&2
    else
        echo "The depot was built from a dirty source tree." >&2
        tater_failed=1
    fi
fi

if [ "${tater_failed}" -ne 0 ]; then
    echo "Steam depot audit failed." >&2
    exit 1
fi

echo "Steam depot audit passed."
