#!/bin/sh

set -eu

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 DEPOT_DIRECTORY" >&2
    exit 2
fi

tater_depot_dir=$(CDPATH= cd -- "$1" && pwd)
tater_binary="${tater_depot_dir}/bin/tater-tube-player"
tater_mpv_binary="${tater_depot_dir}/bin/tater-mpv"
tater_failed=0

tater_require_file() {
    if [ ! -f "${tater_depot_dir}/$1" ]; then
        echo "Missing required depot file: $1" >&2
        tater_failed=1
    fi
}

tater_require_mpv_option() {
    tater_option=$1
    tater_value=$2

    if ! grep -E -i -q \
        "^[[:space:]]*${tater_option}[[:space:]]+${tater_value}([[:space:]]|$)" \
        "${tater_depot_dir}/compliance/mpv-build-options.txt" 2>/dev/null; then
        echo "The mpv build record does not show ${tater_option}=${tater_value}." >&2
        tater_failed=1
    fi
}

for tater_required in \
    tater-tube-player \
    bin/tater-tube-player \
    bin/tater-mpv \
    licenses/LICENSE \
    licenses/NOTICE \
    licenses/PRIVACY.md \
    licenses/THIRD_PARTY_NOTICES.md \
    licenses/LGPL-3.0-only.txt \
    licenses/GPL-3.0-only.txt \
    licenses/LGPL-2.1-or-later.txt \
    licenses/mpv-Copyright.txt \
    licenses/mpv-LGPL-2.1-or-later.txt \
    licenses/libass-Copyright.txt \
    licenses/libplacebo-Copyright.txt \
    licenses/libjpeg-turbo-Copyright.txt \
    licenses/RELINKING_QT.md \
    licenses/Unicode-3.0-ICU-73.2.txt \
    licenses/source-manifest.txt \
    compliance/runtime-dependencies.txt \
    compliance/all-runtime-dependencies.txt \
    compliance/bundled-ffmpeg.txt \
    compliance/ffmpeg-build-config.txt \
    compliance/mpv-build-options.txt \
    compliance/mpv-runtime-dependencies.txt \
    compliance/mpv-version.txt \
    compliance/steam-runtime.txt \
    compliance/SHA256SUMS; do
    tater_require_file "${tater_required}"
done

for tater_native_runtime in lib/libass.so.9 lib/libplacebo.so.349 lib/libjpeg.so.62; do
    tater_require_file "${tater_native_runtime}"
done

if [ ! -x "${tater_depot_dir}/tater-tube-player" ]; then
    echo "The top-level Steam launcher is not executable." >&2
    tater_failed=1
fi

if [ ! -x "${tater_mpv_binary}" ]; then
    echo "The native Steam playback engine is not executable." >&2
    tater_failed=1
elif ! LD_LIBRARY_PATH="${tater_depot_dir}/lib" \
    "${tater_mpv_binary}" --no-config --version >/dev/null 2>&1; then
    echo "The native Steam playback engine could not start." >&2
    tater_failed=1
fi

if find "${tater_depot_dir}" -type l | grep -q .; then
    echo "The depot contains symbolic links that SteamPipe may omit." >&2
    find "${tater_depot_dir}" -type l >&2
    tater_failed=1
fi

tater_require_mpv_option gpl false
if grep -E -i -q 'gpl[[:space:]]+true' \
    "${tater_depot_dir}/compliance/mpv-build-options.txt" 2>/dev/null; then
    echo "The mpv build record enables GPL code." >&2
    tater_failed=1
fi
for tater_mpv_disabled in \
    x11 gl-x11 egl-x11 vdpau dmabuf-wayland vaapi-drm lcms2; do
    tater_require_mpv_option "${tater_mpv_disabled}" disabled
done
for tater_mpv_enabled in wayland vulkan vaapi vaapi-wayland; do
    tater_require_mpv_option "${tater_mpv_enabled}" enabled
done

# The build SDK can contain libraries that Valve's pressure-vessel runtime does
# not. Audit mpv's direct dependency surface explicitly instead of trusting an
# ldd run made only inside the SDK container.
if command -v readelf >/dev/null 2>&1 && [ -f "${tater_mpv_binary}" ]; then
    for tater_mpv_needed in $(readelf -d "${tater_mpv_binary}" 2>/dev/null \
        | sed -n 's/.*Shared library: \[\(.*\)\]/\1/p'); do
        case "${tater_mpv_needed}" in
            libass.so.9|libavcodec.so.61|libavfilter.so.10|libavformat.so.61|\
            libavutil.so.59|libplacebo.so.349|libswresample.so.5|libswscale.so.8|\
            libjpeg.so.62|libm.so.6|libz.so.1|libasound.so.2|\
            libpipewire-0.3.so.0|libpulse.so.0|libwayland-client.so.0|\
            libwayland-cursor.so.0|libxkbcommon.so.0|libEGL.so.1|\
            libwayland-egl.so.1|libvulkan.so.1|libva-wayland.so.2|libva.so.2|\
            libc.so.6)
                ;;
            *)
                echo "The native playback engine has an unapproved Steam runtime dependency: ${tater_mpv_needed}" >&2
                tater_failed=1
                ;;
        esac
    done
fi
if grep -q 'not found' "${tater_depot_dir}/compliance/all-runtime-dependencies.txt" 2>/dev/null; then
    echo "At least one shipped ELF or Qt plugin has an unresolved dependency:" >&2
    grep -B 1 'not found' "${tater_depot_dir}/compliance/all-runtime-dependencies.txt" >&2
    tater_failed=1
fi

if grep -E -q -- '--enable-(gpl|nonfree|version3|libx264|libx265)' \
    "${tater_depot_dir}/compliance/ffmpeg-build-config.txt" 2>/dev/null; then
    echo "The bundled FFmpeg configuration enables a forbidden GPL/nonfree component." >&2
    tater_failed=1
fi
for tater_ffmpeg_flag in --disable-gpl --disable-nonfree --disable-version3; do
    if ! grep -q -- "${tater_ffmpeg_flag}" \
        "${tater_depot_dir}/compliance/ffmpeg-build-config.txt" 2>/dev/null; then
        echo "The bundled FFmpeg configuration is missing ${tater_ffmpeg_flag}." >&2
        tater_failed=1
    fi
done

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
    \( -name 'libx264.so*' -o -name 'libx265.so*' -o -name 'libpostproc.so*' \
       -o -name 'libQt6CanvasPainter.so*' -o -name 'libQt6Coap.so*' \
       -o -name 'libQt6Graphs*.so*' -o -name 'libQt6Grpc*.so*' \
       -o -name 'libQt6HttpServer.so*' -o -name 'libQt6Lottie.so*' \
       -o -name 'libQt6Mqtt.so*' -o -name 'libQt6NetworkAuth.so*' \
       -o -name 'libQt6Quick3D*.so*' -o -name 'libQt6QuickTimeline.so*' \
       -o -name 'libQt6VirtualKeyboard.so*' \
       -o -name 'libQt6WaylandCompositor.so*' -o -name 'libsteam_api.so*' \) \
    | grep -q .; then
    echo "The depot contains a forbidden GPL-only or Steamworks runtime library." >&2
    find "${tater_depot_dir}" -type f \
        \( -name 'libx264.so*' -o -name 'libx265.so*' -o -name 'libpostproc.so*' \
           -o -name 'libQt6CanvasPainter.so*' -o -name 'libQt6Coap.so*' \
           -o -name 'libQt6Graphs*.so*' -o -name 'libQt6Grpc*.so*' \
           -o -name 'libQt6HttpServer.so*' -o -name 'libQt6Lottie.so*' \
           -o -name 'libQt6Mqtt.so*' -o -name 'libQt6NetworkAuth.so*' \
           -o -name 'libQt6Quick3D*.so*' -o -name 'libQt6QuickTimeline.so*' \
           -o -name 'libQt6VirtualKeyboard.so*' \
           -o -name 'libQt6WaylandCompositor.so*' -o -name 'libsteam_api.so*' \) >&2
    tater_failed=1
fi

if find "${tater_depot_dir}" -type f \
    \( -iname '*libretro*' -o -iname '*retroarch*' -o -iname '*mame*' \
       -o -iname '*dolphin*' -o -iname '*pcsx*' -o -iname '*moonlight*' \
       -o -iname '*yt-dlp*' -o -iname '*steam_api*' \) \
    | grep -q .; then
    echo "The depot contains a forbidden emulator, streaming, downloader, or Steamworks component." >&2
    tater_failed=1
fi

if grep -a -E -i -l \
    '(libretro|retroarch|moonlight-embedded|libsteam_api|SteamAPI_Init)' \
    "${tater_binary}" "${tater_mpv_binary}" >/dev/null 2>&1; then
    echo "A shipped executable contains a forbidden old-runtime or Steamworks marker." >&2
    tater_failed=1
fi

if ! find "${tater_depot_dir}/lib" -maxdepth 1 -type f -name 'libicu*.so.*' \
    | grep -q .; then
    echo "The audited ICU libraries were not found in the depot." >&2
    tater_failed=1
fi

if command -v sha256sum >/dev/null 2>&1; then
    if ! (cd "${tater_depot_dir}" && sha256sum -c compliance/SHA256SUMS >/dev/null); then
        echo "The depot does not match its SHA-256 inventory." >&2
        tater_failed=1
    fi
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
