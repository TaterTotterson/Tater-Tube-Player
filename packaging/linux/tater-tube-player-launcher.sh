#!/bin/sh

set -eu

tater_launcher_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

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

# Steam Linux Runtime containers do not always include xrandr. Ask Qt for the
# active Gamescope display size instead so a docked 4K screen still uses the
# same television-sized logical canvas as a 1600x900/1080p display.
if [ -z "${QT_SCALE_FACTOR:-}" ]; then
    tater_display_mode=$("${tater_launcher_dir}/bin/tater-tube-player" \
        --print-screen-size 2>/dev/null || true)
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

exec "${tater_launcher_dir}/bin/tater-tube-player" "$@"
