#!/bin/sh

set -eu

container_name="tater-player-build"
player_root="${HOME}/Tater-Tube-Player"
player_binary="${player_root}/build-deck/tater-tube-player"
runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
pulse_socket="${runtime_dir}/pulse/native"

if [ ! -x "${player_binary}" ]; then
    echo "Tater Tube Player has not been built at ${player_binary}." >&2
    exit 1
fi

if [ -S "${pulse_socket}" ]; then
    exec /usr/bin/distrobox enter --no-tty "${container_name}" -- \
        env XDG_RUNTIME_DIR="${runtime_dir}" PULSE_SERVER="unix:${pulse_socket}" \
        "${player_binary}" --compatible-playback "$@"
fi

exec /usr/bin/distrobox enter --no-tty "${container_name}" -- \
    env XDG_RUNTIME_DIR="${runtime_dir}" \
    "${player_binary}" --compatible-playback "$@"
