#!/bin/sh

set -eu

tater_launcher_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

# Render fullscreen at the active Gamescope/X11 output resolution while keeping
# the television UI near its 1600x900 design size in logical pixels.
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

if [ -n "${LD_LIBRARY_PATH:-}" ]; then
    LD_LIBRARY_PATH="${tater_launcher_dir}/lib:${LD_LIBRARY_PATH}"
else
    LD_LIBRARY_PATH="${tater_launcher_dir}/lib"
fi
export LD_LIBRARY_PATH

if [ -n "${QT_PLUGIN_PATH:-}" ]; then
    QT_PLUGIN_PATH="${tater_launcher_dir}/plugins:${QT_PLUGIN_PATH}"
else
    QT_PLUGIN_PATH="${tater_launcher_dir}/plugins"
fi
export QT_PLUGIN_PATH

if [ -n "${QML2_IMPORT_PATH:-}" ]; then
    QML2_IMPORT_PATH="${tater_launcher_dir}/qml:${QML2_IMPORT_PATH}"
else
    QML2_IMPORT_PATH="${tater_launcher_dir}/qml"
fi
export QML2_IMPORT_PATH

exec "${tater_launcher_dir}/bin/tater-tube-player" "$@"
