# Third-party notices

Tater Tube Player is licensed under Apache-2.0. The following components are
not relicensed by that license. The exact versions and complete dependency list
for a binary release are recorded in the SBOM shipped with that release.

## Qt

The Linux player dynamically links modules from the Qt Community Edition,
including Qt Core, Qt GUI, Qt Multimedia, Qt Network, Qt QML, Qt Quick, and Qt
Quick Controls. These modules are used under the GNU Lesser General Public
License version 3. Qt remains copyright its respective contributors and The Qt
Company.

The full LGPLv3 and incorporated GPLv3 texts are included in
`packaging/licenses/` and in the `licenses/` directory of the Steam depot.
Including the GPLv3 text does not mean the Player ships a GPL-only Qt module;
the Steam release excludes Qt's GPL-only runtime modules. Instructions for
replacing the shared Qt libraries are in `docs/RELINKING_QT.md`.

- Project: https://www.qt.io/
- Source: https://code.qt.io/
- License information: https://doc.qt.io/qt-6/licensing.html

## FFmpeg used by Qt Multimedia and mpv

Qt Multimedia uses FFmpeg for media playback in the Linux release. FFmpeg is a
separate work and is distributed as shared libraries under its applicable LGPL
terms and other permissive component licenses.

The Steam release builds FFmpeg 7.1.5 from its pinned upstream source archive
with `--disable-gpl`, `--disable-version3`, and `--disable-nonfree`. It is built
as shared libraries and is used by both Qt Multimedia and mpv. No x264, x265,
or other GPL/nonfree external codec library is included.

- Project: https://ffmpeg.org/
- License information: https://ffmpeg.org/legal.html

The full LGPLv2.1 text is included in `packaging/licenses/` and in the Steam
depot. The exact configure invocation, release SBOM, binary evidence, and
source manifest identify the build and all libraries actually shipped.

## SDL / sdl2-compat

Controller discovery and input use the SDL2 API. The Linux executable is built
against SDL 2.32.70 from the pinned Steam Runtime 4 SDK and dynamically uses
the SDL library supplied by the selected Steam Runtime; the depot does not
bundle a second SDL copy. SDL and sdl2-compat use the permissive Zlib license.

- Project: https://www.libsdl.org/
- sdl2-compat: https://github.com/libsdl-org/sdl2-compat

The applicable Zlib license text is included in `packaging/licenses/Zlib-SDL.txt`.

## ICU

The Linux depot includes ICU 73.2 shared libraries from the official Qt 6.11.2
Linux distribution. Qt Core uses these libraries for Unicode, locale, and text
handling. ICU is permissively licensed under the Unicode License and includes
third-party data notices.

The complete ICU 73.2 license and bundled-data notices are included as
`licenses/Unicode-3.0-ICU-73.2.txt`. The release source archive retains the
matching `icu4c-73_2-src.tgz` upstream source archive.

- Project: https://icu.unicode.org/
- Source: https://github.com/unicode-org/icu/releases/tag/release-73-2
- License information: https://github.com/unicode-org/icu/blob/release-73-2/icu4c/LICENSE

## mpv

The Steam/Linux release launches mpv as a separate program for native Vulkan
video output, hardware decoding, HDR presentation through Gamescope, and HDMI
audio passthrough. It is not linked into the Apache-licensed Tater Tube Player
executable.

The release builds mpv 0.40.0 from its pinned upstream source archive with
Meson's `-Dgpl=false` option. GPL-only paths, including mpv's X11 video output,
are disabled; the Steam/Gamescope path uses Wayland and Vulkan. This build is
distributed under LGPLv2.1-or-later. Its complete copyright file, LGPL text,
exact Meson option record, and corresponding source are included with the
release records.

- Project: https://mpv.io/
- Source: https://github.com/mpv-player/mpv
- License information: https://github.com/mpv-player/mpv/blob/master/Copyright

## libass, libplacebo, libjpeg-turbo, Little CMS, and libunibreak

The native mpv playback process dynamically uses libass 0.17.3 for subtitle
rendering and libplacebo 7.349.0 for its Vulkan video-rendering pipeline. The
Steam depot carries the exact shared-library SONAMEs used to build mpv so the
native player does not depend on whichever versions happen to be installed by
SteamOS. The same release carries libjpeg-turbo 2.1.5, which mpv uses for JPEG
image support. libass and libjpeg-turbo use permissive terms; libplacebo is
distributed under LGPLv2.1-or-later. Their complete Debian
copyright and license notices are included in the depot as
`licenses/libass-Copyright.txt`, `licenses/libplacebo-Copyright.txt`, and
`licenses/libjpeg-turbo-Copyright.txt`. The depot also carries Little CMS 2
and libunibreak, permissively licensed transitive dependencies of this native
playback stack, with their complete notices in
`licenses/liblcms2-Copyright.txt` and `licenses/libunibreak-Copyright.txt`.

- libass: https://github.com/libass/libass
- libplacebo: https://code.videolan.org/videolan/libplacebo
- libjpeg-turbo: https://libjpeg-turbo.org/
- Little CMS: https://www.littlecms.com/
- libunibreak: https://github.com/adah1972/libunibreak

## Transitive components

Qt, FFmpeg, and the Linux runtime use additional third-party components. Their
notices are generated from the exact Qt SPDX documents and the final depot's
runtime dependency scan. A release is not uploadable until those records are
present under `compliance/` in the depot and have been reviewed.

Codec patent rights, if any, are not granted by the software licenses above.
The final codec configuration must receive a separate distribution review.
