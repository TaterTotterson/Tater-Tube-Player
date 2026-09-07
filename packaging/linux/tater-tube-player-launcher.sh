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

exec "${tater_launcher_dir}/bin/tater-tube-player" "$@"
