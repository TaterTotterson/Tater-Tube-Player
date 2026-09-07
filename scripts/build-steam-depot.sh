#!/bin/sh

set -eu

tater_script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
tater_repo_dir=$(CDPATH= cd -- "${tater_script_dir}/.." && pwd)
tater_build_dir=${TATER_STEAM_BUILD_DIR:-"${tater_repo_dir}/build-steam"}
tater_depot_dir=${TATER_STEAM_DEPOT_DIR:-"${tater_repo_dir}/dist/steam/linux-x86_64"}

if [ "$(uname -s)" != "Linux" ] || [ "$(uname -m)" != "x86_64" ]; then
    echo "Steam depots must be built in the Linux x86-64 Steam Runtime SDK." >&2
    exit 1
fi

if [ "${TATER_STEAM_DRAFT:-0}" != "1" ] \
    && [ -n "$(git -C "${tater_repo_dir}" status --porcelain)" ]; then
    echo "A final Steam depot must be built from a clean, tagged source tree." >&2
    echo "Use TATER_STEAM_DRAFT=1 only for an explicitly non-release test depot." >&2
    exit 1
fi

if [ -e "${tater_depot_dir}" ]; then
    echo "Refusing to overwrite existing depot: ${tater_depot_dir}" >&2
    echo "Move it aside or set TATER_STEAM_DEPOT_DIR to a new path." >&2
    exit 1
fi

cmake -S "${tater_repo_dir}" -B "${tater_build_dir}" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_TESTING=ON \
    -DTATER_STEAM_RELEASE=ON \
    -DTATER_DEPLOY_QT_RUNTIME=ON
cmake --build "${tater_build_dir}" --parallel
ctest --test-dir "${tater_build_dir}" --output-on-failure
cmake --install "${tater_build_dir}" --prefix "${tater_depot_dir}"

"${tater_script_dir}/prepare-steam-compliance.sh" "${tater_depot_dir}"
"${tater_script_dir}/audit-steam-depot.sh" "${tater_depot_dir}"

echo "Steam depot ready: ${tater_depot_dir}"
