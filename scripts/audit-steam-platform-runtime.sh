#!/bin/sh

set -eu

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 DEPOT_DIRECTORY" >&2
    exit 2
fi

tater_depot_dir=$(CDPATH= cd -- "$1" && pwd)
tater_runtime_failures=$(mktemp)
trap 'rm -f "${tater_runtime_failures}"' EXIT HUP INT TERM

find "${tater_depot_dir}" -type f | while IFS= read -r tater_candidate; do
    if file "${tater_candidate}" | grep -q 'ELF 64-bit'; then
        tater_missing=$(LD_LIBRARY_PATH="${tater_depot_dir}/lib" \
            ldd "${tater_candidate}" 2>&1 | grep 'not found' || true)
        if [ -n "${tater_missing}" ]; then
            printf '[%s]\n%s\n' \
                "${tater_candidate#${tater_depot_dir}/}" "${tater_missing}" \
                >> "${tater_runtime_failures}"
        fi
    fi
done

if [ -s "${tater_runtime_failures}" ]; then
    echo "The depot has dependencies missing from Steam Runtime 4:" >&2
    cat "${tater_runtime_failures}" >&2
    exit 1
fi

LD_LIBRARY_PATH="${tater_depot_dir}/lib" \
    "${tater_depot_dir}/bin/tater-tube-player" --version >/dev/null
LD_LIBRARY_PATH="${tater_depot_dir}/lib" \
    "${tater_depot_dir}/bin/tater-mpv" --no-config --version >/dev/null

echo "Steam Runtime 4 platform audit passed."
