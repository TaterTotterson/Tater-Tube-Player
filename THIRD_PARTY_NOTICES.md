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

The full LGPLv3 and GPLv3 texts are included in `packaging/licenses/` and in the
`licenses/` directory of the Steam depot. Instructions for replacing the shared
Qt libraries are in `docs/RELINKING_QT.md`.

- Project: https://www.qt.io/
- Source: https://code.qt.io/
- License information: https://doc.qt.io/qt-6/licensing.html

## FFmpeg used by Qt Multimedia

Qt Multimedia uses FFmpeg for media playback in the Linux release. FFmpeg is a
separate work and is distributed as shared libraries under its applicable LGPL
terms and other permissive component licenses.

The Steam release must use the audited FFmpeg build supplied by the official Qt
distribution, or an equivalently audited build configured without
`--enable-gpl` and without `--enable-nonfree`. Development-distribution FFmpeg
packages that enable GPL components such as x264 or x265 must not be copied into
the Steam depot.

- Project: https://ffmpeg.org/
- License information: https://ffmpeg.org/legal.html

The Qt 6.11.2 Linux package currently ships FFmpeg libraries matching FFmpeg
7.1.5 and configured as shared libraries without GPL or nonfree components.
The full LGPLv2.1 text is included in `packaging/licenses/` and in the Steam
depot. The release SBOM, embedded configuration evidence, and source manifest
identify the exact FFmpeg build and all libraries actually shipped.

## SDL / sdl2-compat

Controller discovery and input use the SDL2 API. The Linux executable is built
against SDL 2.32.70 from the pinned Steam Runtime 4 SDK and dynamically uses
the SDL library supplied by the selected Steam Runtime; the depot does not
bundle a second SDL copy. SDL and sdl2-compat use the permissive Zlib license.

- Project: https://www.libsdl.org/
- sdl2-compat: https://github.com/libsdl-org/sdl2-compat

The applicable Zlib license text is included in `packaging/licenses/Zlib-SDL.txt`.

## Transitive components

Qt, FFmpeg, and the Linux runtime use additional third-party components. Their
notices are generated from the exact Qt SPDX documents and the final depot's
runtime dependency scan. A release is not uploadable until those records are
present under `compliance/` in the depot and have been reviewed.

Codec patent rights, if any, are not granted by the software licenses above.
The final codec configuration must receive a separate distribution review.
