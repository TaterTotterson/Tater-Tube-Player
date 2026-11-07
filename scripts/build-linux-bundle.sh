#!/bin/sh

set -eu

tater_script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
tater_repo_dir=$(CDPATH= cd -- "${tater_script_dir}/.." && pwd)
tater_build_dir=${TATER_LINUX_BUILD_DIR:-"${tater_repo_dir}/build-linux"}
tater_bundle_dir=${TATER_LINUX_BUNDLE_DIR:-"${tater_repo_dir}/dist/linux/x86_64"}

if [ "$(uname -s)" != "Linux" ] || [ "$(uname -m)" != "x86_64" ]; then
    echo "Portable bundles must be built in the Linux x86-64 runtime SDK." >&2
    exit 1
fi

if [ "${TATER_LINUX_DRAFT:-0}" != "1" ]; then
    if [ -n "$(git -C "${tater_repo_dir}" status --porcelain)" ]; then
        echo "A final Linux bundle must be built from a clean, tagged source tree." >&2
        echo "Use TATER_LINUX_DRAFT=1 only for an explicitly non-release test bundle." >&2
        exit 1
    fi

    tater_release_version=$(awk '
        /^project\(TaterTubePlayer/ { in_project = 1 }
        in_project && $1 == "VERSION" { print $2; exit }
    ' "${tater_repo_dir}/CMakeLists.txt")
    tater_release_tag=$(git -C "${tater_repo_dir}" describe --tags --exact-match HEAD \
        2>/dev/null || true)
    if [ -z "${tater_release_version}" ] \
        || [ "${tater_release_tag}" != "v${tater_release_version}" ]; then
        echo "A final Linux bundle must be built from the matching v${tater_release_version:-unknown} tag." >&2
        exit 1
    fi
fi

if [ -e "${tater_bundle_dir}" ]; then
    echo "Refusing to overwrite existing bundle: ${tater_bundle_dir}" >&2
    echo "Move it aside or set TATER_LINUX_BUNDLE_DIR to a new path." >&2
    exit 1
fi

cmake -S "${tater_repo_dir}" -B "${tater_build_dir}" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_TESTING=ON \
    -DTATER_LINUX_BUNDLE=ON \
    -DTATER_DEPLOY_QT_RUNTIME=ON
cmake --build "${tater_build_dir}" --parallel
ctest --test-dir "${tater_build_dir}" --output-on-failure
cmake --install "${tater_build_dir}" --prefix "${tater_bundle_dir}"

# Materialize file links so the portable archive behaves consistently when it
# is extracted on SteamOS and ordinary desktop Linux filesystems. Fail closed
# if a future package introduces a directory or broken link.
find "${tater_bundle_dir}" -type l -exec sh -eu -c '
    for tater_link do
        if [ ! -f "${tater_link}" ]; then
            echo "Cannot materialize non-file bundle link: ${tater_link}" >&2
            exit 1
        fi
        tater_link_copy="${tater_link}.tater-materialized"
        cp -L --preserve=mode,timestamps "${tater_link}" "${tater_link_copy}"
        mv -f "${tater_link_copy}" "${tater_link}"
    done
' sh {} +

"${tater_script_dir}/prepare-linux-compliance.sh" "${tater_bundle_dir}"
"${tater_script_dir}/audit-linux-bundle.sh" "${tater_bundle_dir}"

echo "Portable Linux bundle ready: ${tater_bundle_dir}"
