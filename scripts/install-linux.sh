#!/usr/bin/env bash
# Install or update Tater Tube Player for one Linux user.
set -Eeuo pipefail

unset LD_LIBRARY_PATH LD_PRELOAD

readonly REPOSITORY="TaterTotterson/Tater-Tube-Player"
readonly DEFAULT_RELEASE_BASE="https://github.com/${REPOSITORY}/releases/latest/download"

ADD_TO_STEAM="auto"
SHOW_DIALOGS="yes"
RELEASE_BASE="${TATER_PLAYER_RELEASE_BASE:-${DEFAULT_RELEASE_BASE}}"
INSTALL_BASE="${TATER_PLAYER_INSTALL_BASE:-${XDG_DATA_HOME:-${HOME}/.local/share}/tater-tube-player}"
BIN_DIR="${TATER_PLAYER_BIN_DIR:-${HOME}/.local/bin}"
APPLICATIONS_DIR="${TATER_PLAYER_APPLICATIONS_DIR:-${XDG_DATA_HOME:-${HOME}/.local/share}/applications}"
CACHE_BASE="${TATER_PLAYER_CACHE_BASE:-${XDG_CACHE_HOME:-${HOME}/.cache}/tater-tube-player-installer}"
APP_DIR="${INSTALL_BASE}/app"
LAUNCHER="${BIN_DIR}/tater-tube-player"
DESKTOP_FILE="${APPLICATIONS_DIR}/com.taterassistant.TaterTubePlayer.desktop"

usage() {
    printf '%s\n' \
        "Usage: install-linux.sh [--add-to-steam|--no-add-to-steam|--quiet]" \
        "" \
        "Installs or updates Tater Tube Player without sudo. Settings and" \
        "pairing information are preserved between updates." \
        "" \
        "  --add-to-steam     Request a non-Steam shortcut after installation." \
        "  --no-add-to-steam  Install only the desktop application." \
        "  --quiet            Do not show desktop completion or error dialogs."
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --add-to-steam) ADD_TO_STEAM="yes" ;;
        --no-add-to-steam) ADD_TO_STEAM="no" ;;
        --quiet) SHOW_DIALOGS="no" ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

show_error() {
    printf 'ERROR: %s\n' "$*" >&2
    if [ "${SHOW_DIALOGS}" = "yes" ] && command -v kdialog >/dev/null 2>&1 \
            && { [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; }; then
        kdialog --title "Tater Tube Player Installer" --error "$*" >/dev/null 2>&1 || true
    fi
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || show_error "Required command not found: $1"
}

[ "$(id -u)" -ne 0 ] || show_error "Run the installer as your normal user, not with sudo."
[ "$(uname -s)" = "Linux" ] && [ "$(uname -m)" = "x86_64" ] \
    || show_error "Tater Tube Player currently requires 64-bit x86 Linux or Steam Deck."
for command in awk curl sha256sum sort tar; do
    require_command "${command}"
done

mkdir -p "${CACHE_BASE}"
RUN_DIR="$(mktemp -d "${CACHE_BASE}/run.XXXXXX")"
cleanup() {
    case "${RUN_DIR:-}" in
        "${CACHE_BASE}"/run.*) rm -rf -- "${RUN_DIR}" ;;
    esac
}
trap cleanup EXIT

CHECKSUM_FILE="${RUN_DIR}/SHA256SUMS.txt"
if [ -n "${TATER_PLAYER_CHECKSUM_PATH:-}" ]; then
    cp -- "${TATER_PLAYER_CHECKSUM_PATH}" "${CHECKSUM_FILE}"
else
    printf '%s\n' "Downloading the latest release information…"
    curl -fL --retry 3 --progress-bar -o "${CHECKSUM_FILE}" \
        "${RELEASE_BASE}/SHA256SUMS.txt"
fi

archive_name="$(awk '
    {
        name = $2
        sub(/^\*/, "", name)
        if (name ~ /^Tater-Tube-Player-v[0-9]+\.[0-9]+\.[0-9]+([-A-Za-z0-9.]*)-linux-x86_64\.tar\.gz$/) {
            print name
            exit
        }
    }
' "${CHECKSUM_FILE}")"
[ -n "${archive_name}" ] || show_error "The release does not contain a Linux player archive."

ARCHIVE_FILE="${RUN_DIR}/${archive_name}"
if [ -n "${TATER_PLAYER_ARCHIVE_PATH:-}" ]; then
    cp -- "${TATER_PLAYER_ARCHIVE_PATH}" "${ARCHIVE_FILE}"
else
    printf 'Downloading %s…\n' "${archive_name}"
    curl -fL --retry 3 --progress-bar -o "${ARCHIVE_FILE}" \
        "${RELEASE_BASE}/${archive_name}"
fi

expected_sha="$(awk -v target="${archive_name}" '
    {
        name = $2
        sub(/^\*/, "", name)
        if (name == target) { print $1; exit }
    }
' "${CHECKSUM_FILE}")"
[ -n "${expected_sha}" ] || show_error "No checksum was found for ${archive_name}."
actual_sha="$(sha256sum "${ARCHIVE_FILE}" | awk '{print $1}')"
[ "${actual_sha}" = "${expected_sha}" ] || show_error "The downloaded player failed its security check."

release_root="$(tar -tzf "${ARCHIVE_FILE}" | awk -F/ 'NF && $1 != "." {print $1}' | sort -u)"
case "${release_root}" in
    Tater-Tube-Player-v*-linux-x86_64) ;;
    *) show_error "The release archive has an unexpected layout." ;;
esac

EXTRACT_DIR="${RUN_DIR}/extract"
mkdir -p "${EXTRACT_DIR}"
printf '%s\n' "Installing Tater Tube Player…"
tar -xzf "${ARCHIVE_FILE}" -C "${EXTRACT_DIR}"
STAGED_APP="${EXTRACT_DIR}/${release_root}"
[ -x "${STAGED_APP}/tater-tube-player" ] \
    || show_error "The release is missing its player launcher."

first_install="yes"
[ ! -d "${APP_DIR}" ] || first_install="no"
mkdir -p "${INSTALL_BASE}" "${BIN_DIR}" "${APPLICATIONS_DIR}"
NEW_APP="${INSTALL_BASE}/app.new.$$"
PREVIOUS_APP="${INSTALL_BASE}/app.previous.$$"
rm -rf -- "${NEW_APP}" "${PREVIOUS_APP}"
mv -- "${STAGED_APP}" "${NEW_APP}"
if [ -d "${APP_DIR}" ]; then
    mv -- "${APP_DIR}" "${PREVIOUS_APP}"
fi
if ! mv -- "${NEW_APP}" "${APP_DIR}"; then
    [ ! -d "${PREVIOUS_APP}" ] || mv -- "${PREVIOUS_APP}" "${APP_DIR}"
    show_error "The new player could not be activated."
fi
rm -rf -- "${PREVIOUS_APP}"

launcher_tmp="${LAUNCHER}.tmp.$$"
printf '#!/usr/bin/env bash\nset -euo pipefail\nexec %q "$@"\n' \
    "${APP_DIR}/tater-tube-player" > "${launcher_tmp}"
chmod 0755 "${launcher_tmp}"
mv -- "${launcher_tmp}" "${LAUNCHER}"

icon_path="${APP_DIR}/share/icons/hicolor/256x256/apps/com.taterassistant.TaterTubePlayer.png"
desktop_tmp="${DESKTOP_FILE}.tmp.$$"
printf '%s\n' \
    '[Desktop Entry]' \
    'Type=Application' \
    'Name=Tater Tube Player' \
    'Comment=Watch your Tater Tube library and live channels' \
    "Exec=${LAUNCHER}" \
    "Path=${APP_DIR}" \
    "Icon=${icon_path}" \
    'Terminal=false' \
    'Categories=AudioVideo;Video;' \
    'StartupNotify=true' \
    'StartupWMClass=tater-tube-player' > "${desktop_tmp}"
chmod 0644 "${desktop_tmp}"
mv -- "${desktop_tmp}" "${DESKTOP_FILE}"
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "${APPLICATIONS_DIR}" >/dev/null 2>&1 || true
fi

request_steam_add="no"
case "${ADD_TO_STEAM}" in
    yes) request_steam_add="yes" ;;
    auto) [ "${first_install}" = "no" ] || request_steam_add="yes" ;;
esac

shortcut_message=""
if [ "${request_steam_add}" = "yes" ]; then
    if command -v steamos-add-to-steam >/dev/null 2>&1 \
            && steamos-add-to-steam "${DESKTOP_FILE}" >/dev/null 2>&1; then
        shortcut_message=" It was also added to your Steam Deck library."
    else
        shortcut_message=" Add it as a non-Steam game from Steam’s Games menu if desired."
    fi
fi

installed_version="${release_root#Tater-Tube-Player-}"
installed_version="${installed_version%-linux-x86_64}"
message="Tater Tube Player ${installed_version} is installed.${shortcut_message}"
printf '\n%s\n' "${message}"
if [ "${SHOW_DIALOGS}" = "yes" ] && command -v kdialog >/dev/null 2>&1 \
        && { [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; }; then
    kdialog --title "Tater Tube Player Installer" --msgbox "${message}" >/dev/null 2>&1 || true
fi
