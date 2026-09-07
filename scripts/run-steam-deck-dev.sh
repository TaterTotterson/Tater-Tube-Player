#!/bin/sh

set -eu

container_name="tater-player-build"
player_root="${HOME}/Tater-Tube-Player"
player_binary="${player_root}/build-deck/tater-tube-player"
runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
pulse_socket="${runtime_dir}/pulse/native"

# Gamescope exposes the output's physical mode through XRandR. Keep the UI at
# its 1600x900 design size in device-independent pixels while Qt renders every
# pixel of a 1080p, 1440p, or 4K television. The Deck's 1280x800 panel remains
# scale 1 so it also renders at its native resolution.
if [ -z "${QT_SCALE_FACTOR:-}" ] && command -v xrandr >/dev/null 2>&1; then
    tater_display_mode=$(xrandr --current 2>/dev/null \
        | sed -n 's/.*current \([0-9][0-9]*\) x \([0-9][0-9]*\).*/\1 \2/p' \
        | head -n 1)
    if [ -n "${tater_display_mode}" ]; then
        tater_display_width=${tater_display_mode%% *}
        tater_display_height=${tater_display_mode#* }
        tater_width_scale=$((tater_display_width * 1000 / 1600))
        tater_height_scale=$((tater_display_height * 1000 / 900))
        if [ "${tater_width_scale}" -lt "${tater_height_scale}" ]; then
            tater_scale_milli=${tater_width_scale}
        else
            tater_scale_milli=${tater_height_scale}
        fi
        if [ "${tater_scale_milli}" -gt 1000 ]; then
            QT_SCALE_FACTOR=$(printf '%d.%03d' \
                "$((tater_scale_milli / 1000))" "$((tater_scale_milli % 1000))")
            export QT_SCALE_FACTOR
            QT_SCALE_FACTOR_ROUNDING_POLICY=PassThrough
            export QT_SCALE_FACTOR_ROUNDING_POLICY
        fi
    fi
fi

if [ ! -x "${player_binary}" ]; then
    echo "Tater Tube Player has not been built at ${player_binary}." >&2
    exit 1
fi

if [ -S "${pulse_socket}" ]; then
    exec /usr/bin/distrobox enter --no-tty "${container_name}" -- \
        env XDG_RUNTIME_DIR="${runtime_dir}" \
        PULSE_SERVER="unix:${pulse_socket}" \
        QT_AUDIO_BACKEND="pulseaudio" \
        QT_SCALE_FACTOR="${QT_SCALE_FACTOR:-1}" \
        QT_SCALE_FACTOR_ROUNDING_POLICY="${QT_SCALE_FACTOR_ROUNDING_POLICY:-PassThrough}" \
        "${player_binary}" --compatible-playback "$@"
fi

exec /usr/bin/distrobox enter --no-tty "${container_name}" -- \
    env XDG_RUNTIME_DIR="${runtime_dir}" \
    QT_SCALE_FACTOR="${QT_SCALE_FACTOR:-1}" \
    QT_SCALE_FACTOR_ROUNDING_POLICY="${QT_SCALE_FACTOR_ROUNDING_POLICY:-PassThrough}" \
    "${player_binary}" --compatible-playback "$@"
