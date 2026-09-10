#!/bin/sh

set -eu

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 OUTPUT_DIRECTORY" >&2
    exit 2
fi

tater_script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
tater_repo_dir=$(CDPATH= cd -- "${tater_script_dir}/.." && pwd)
tater_output_dir=$1
tater_qt_version=6.11.2
tater_ffmpeg_version=7.1.5
tater_icu_version=73.2
tater_mpv_version=0.40.0
tater_libass_version=0.17.3-1+deb13u1
tater_libplacebo_version=7.349.0-3
tater_libjpeg_turbo_version=2.1.5-4
tater_release_depot=${TATER_STEAM_DEPOT_DIR:-"${tater_repo_dir}/dist/steam/linux-x86_64"}
tater_player_version=$(sed -n 's/^[[:space:]]*VERSION[[:space:]]\{1,\}\([0-9][0-9.]*\).*/\1/p' \
    "${tater_repo_dir}/CMakeLists.txt" | head -n 1)
tater_source_cache_dir=${TATER_SOURCE_CACHE_DIR:-}

if [ -z "${tater_player_version}" ]; then
    echo "Could not read the player version from CMakeLists.txt." >&2
    exit 1
fi
if [ -e "${tater_output_dir}" ]; then
    echo "Refusing to overwrite existing source-offer directory: ${tater_output_dir}" >&2
    exit 1
fi
if [ -n "$(git -C "${tater_repo_dir}" status --porcelain)" ]; then
    echo "The source offer must be generated from a clean source tree." >&2
    exit 1
fi
for tater_release_record in bundled-ffmpeg.txt ffmpeg-build-config.txt \
        mpv-build-options.txt mpv-version.txt; do
    if [ ! -f "${tater_release_depot}/compliance/${tater_release_record}" ]; then
        echo "Missing exact release record: ${tater_release_depot}/compliance/${tater_release_record}" >&2
        exit 1
    fi
done

tater_sha256()
{
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    else
        shasum -a 256 "$1" | awk '{print $1}'
    fi
}

tater_fetch()
{
    tater_file=$1
    tater_url=$2
    tater_expected=$3
    if [ -n "${tater_source_cache_dir}" ] \
        && [ -f "${tater_source_cache_dir}/${tater_file}" ]; then
        cp "${tater_source_cache_dir}/${tater_file}" \
            "${tater_bundle_dir}/upstream/${tater_file}"
    else
        curl -fL --retry 3 --output "${tater_bundle_dir}/upstream/${tater_file}" "${tater_url}"
    fi
    tater_actual=$(tater_sha256 "${tater_bundle_dir}/upstream/${tater_file}")
    if [ "${tater_actual}" != "${tater_expected}" ]; then
        echo "SHA-256 mismatch for ${tater_file}" >&2
        echo "Expected ${tater_expected}; received ${tater_actual}" >&2
        exit 1
    fi
    printf '%s  upstream/%s\n' "${tater_actual}" "${tater_file}" \
        >> "${tater_bundle_dir}/SHA256SUMS"
}

tater_temp_dir=$(mktemp -d)
trap 'rm -rf "${tater_temp_dir}"' EXIT HUP INT TERM
tater_bundle_dir="${tater_temp_dir}/tater-tube-player-third-party-sources-${tater_player_version}"
mkdir -p "${tater_bundle_dir}/upstream" "${tater_output_dir}"

tater_fetch qtbase-everywhere-src-6.11.2.tar.xz \
    https://download.qt.io/official_releases/qt/6.11/6.11.2/submodules/qtbase-everywhere-src-6.11.2.tar.xz \
    5b2e00eccaf5a4d8c14134ffa0ea8dfd0a35ae1ffc7f8d87fa4305a1ed23cf22
tater_fetch qtdeclarative-everywhere-src-6.11.2.tar.xz \
    https://download.qt.io/official_releases/qt/6.11/6.11.2/submodules/qtdeclarative-everywhere-src-6.11.2.tar.xz \
    215b7b70517e380123eabc6b92243f3c47b6f016a91d126057dbe53551c6b430
tater_fetch qtmultimedia-everywhere-src-6.11.2.tar.xz \
    https://download.qt.io/official_releases/qt/6.11/6.11.2/submodules/qtmultimedia-everywhere-src-6.11.2.tar.xz \
    967b5e02ec6b793cdb360622cd6e703132836af983208d678dae4b50f109cd9f
tater_fetch qtsvg-everywhere-src-6.11.2.tar.xz \
    https://download.qt.io/official_releases/qt/6.11/6.11.2/submodules/qtsvg-everywhere-src-6.11.2.tar.xz \
    d594337feca84c26fb67fe87b85e6a5c12fda404b611d905f9d138210c311876
tater_fetch qtwayland-everywhere-src-6.11.2.tar.xz \
    https://download.qt.io/official_releases/qt/6.11/6.11.2/submodules/qtwayland-everywhere-src-6.11.2.tar.xz \
    8eb7615e39332a10f506e8dd70f02d5954bb5949ff54f6dcbf8bd6168222f9df
tater_fetch ffmpeg-7.1.5.tar.xz \
    https://ffmpeg.org/releases/ffmpeg-7.1.5.tar.xz \
    de668509caf9e35e3cd162473441fdb29538c6d96ed080292b3cf9e6fc5d558f
tater_fetch icu4c-73_2-src.tgz \
    https://github.com/unicode-org/icu/releases/download/release-73-2/icu4c-73_2-src.tgz \
    818a80712ed3caacd9b652305e01afc7fa167e6f2e94996da44b90c2ab604ce1
tater_fetch mpv_0.40.0.orig.tar.gz \
    https://deb.debian.org/debian/pool/main/m/mpv/mpv_0.40.0.orig.tar.gz \
    10a0f4654f62140a6dd4d380dcf0bbdbdcf6e697556863dc499c296182f081a3
tater_fetch libass_0.17.3.orig.tar.xz \
    https://deb.debian.org/debian/pool/main/liba/libass/libass_0.17.3.orig.tar.xz \
    eae425da50f0015c21f7b3a9c7262a910f0218af469e22e2931462fed3c50959
tater_fetch libass_0.17.3.orig.tar.xz.asc \
    https://deb.debian.org/debian/pool/main/liba/libass/libass_0.17.3.orig.tar.xz.asc \
    71383b2d1138bf13008d2919da911a2c381bb196fe546571e2698e44d336b7b1
tater_fetch libass_0.17.3-1+deb13u1.debian.tar.xz \
    https://deb.debian.org/debian/pool/main/liba/libass/libass_0.17.3-1+deb13u1.debian.tar.xz \
    441b33f8e13162d1f7613bc0d644f3b4710d190ae177046b3bc85a80910d2cc3
tater_fetch libass_0.17.3-1+deb13u1.dsc \
    https://deb.debian.org/debian/pool/main/liba/libass/libass_0.17.3-1+deb13u1.dsc \
    c5691038593afa304a9923a1d9dbbe72e7f0788991094dce45787d517c9df398
tater_fetch libplacebo_7.349.0.orig.tar.gz \
    https://deb.debian.org/debian/pool/main/libp/libplacebo/libplacebo_7.349.0.orig.tar.gz \
    79120e685a1836344b51b13b6a5661622486a84e4d4a35f6c8d01679a20fbc86
tater_fetch libplacebo_7.349.0-3.debian.tar.xz \
    https://deb.debian.org/debian/pool/main/libp/libplacebo/libplacebo_7.349.0-3.debian.tar.xz \
    31003c3fbf9b739649c070598438805b618e4985f4d8ef27eba97338bd2306f9
tater_fetch libplacebo_7.349.0-3.dsc \
    https://deb.debian.org/debian/pool/main/libp/libplacebo/libplacebo_7.349.0-3.dsc \
    4ba8c1f5e3f39f16fbfb853dfcf9fc7cb3c7b8ad54a5dee5cb7296292126400f
tater_fetch libjpeg-turbo_2.1.5.orig.tar.gz \
    https://deb.debian.org/debian/pool/main/libj/libjpeg-turbo/libjpeg-turbo_2.1.5.orig.tar.gz \
    254f3642b04e309fee775123133c6464181addc150499561020312ec61c1bf7c
tater_fetch libjpeg-turbo_2.1.5-4.debian.tar.xz \
    https://deb.debian.org/debian/pool/main/libj/libjpeg-turbo/libjpeg-turbo_2.1.5-4.debian.tar.xz \
    739e7dc22904dccdc5ab105de57a6e4c1515c0e841e68226e6410ff4976e0e91
tater_fetch libjpeg-turbo_2.1.5-4.dsc \
    https://deb.debian.org/debian/pool/main/libj/libjpeg-turbo/libjpeg-turbo_2.1.5-4.dsc \
    26cbf22aa3b3e327df072513f14a5ddfb4a7b9a3d78c46a5dccfd711c13ac743

cp "${tater_repo_dir}/THIRD_PARTY_NOTICES.md" "${tater_bundle_dir}/"
cp "${tater_repo_dir}/docs/RELINKING_QT.md" "${tater_bundle_dir}/"
cp "${tater_repo_dir}/packaging/steam/Containerfile" "${tater_bundle_dir}/"
cp "${tater_release_depot}/compliance/bundled-ffmpeg.txt" "${tater_bundle_dir}/"
cp "${tater_release_depot}/compliance/ffmpeg-build-config.txt" "${tater_bundle_dir}/"
cp "${tater_release_depot}/compliance/mpv-build-options.txt" "${tater_bundle_dir}/"
cp "${tater_release_depot}/compliance/mpv-version.txt" "${tater_bundle_dir}/"

cat > "${tater_bundle_dir}/README.txt" <<EOF
Tater Tube Player ${tater_player_version} corresponding third-party source

This archive contains the exact upstream source releases retained for the
shared Qt and FFmpeg libraries in the Steam/Linux depot:

  Qt ${tater_qt_version}: qtbase, qtdeclarative, qtmultimedia, qtsvg, qtwayland
  FFmpeg ${tater_ffmpeg_version}
  ICU ${tater_icu_version}
  mpv ${tater_mpv_version}
  libass ${tater_libass_version}
  libplacebo ${tater_libplacebo_version}
  libjpeg-turbo ${tater_libjpeg_turbo_version}

The original compressed archives are preserved under upstream/ and verified by
SHA256SUMS. The build Containerfile, notices, exact FFmpeg configure record,
exact mpv Meson option record, and Qt relinking instructions are included
alongside them. The libass, libplacebo, and libjpeg-turbo entries include the
signed Debian source descriptor and complete Debian source delta for the exact
package revision used by the depot. No Tater Tube patches were applied.

The Containerfile builds FFmpeg with GPL, nonfree, and version-3 components
disabled, then builds the separately launched mpv executable with
-Dgpl=false. The resulting mpv is distributed under LGPLv2.1-or-later.
EOF

tater_app_archive="${tater_output_dir}/tater-tube-player-${tater_player_version}-source.tar.gz"
tater_third_party_archive="${tater_output_dir}/tater-tube-player-${tater_player_version}-third-party-sources.tar"

git -C "${tater_repo_dir}" archive --format=tar.gz \
    --prefix="Tater-Tube-Player-${tater_player_version}/" \
    --output="${tater_app_archive}" HEAD
tar -C "${tater_temp_dir}" -cf "${tater_third_party_archive}" \
    "$(basename "${tater_bundle_dir}")"

tater_app_sha256=$(tater_sha256 "${tater_app_archive}")
tater_third_party_sha256=$(tater_sha256 "${tater_third_party_archive}")
{
    printf '%s  %s\n' "${tater_app_sha256}" "$(basename "${tater_app_archive}")"
    printf '%s  %s\n' "${tater_third_party_sha256}" \
        "$(basename "${tater_third_party_archive}")"
} > "${tater_output_dir}/SHA256SUMS"

echo "Steam corresponding-source offer ready: ${tater_output_dir}"
