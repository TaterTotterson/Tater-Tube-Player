# Replacing the Qt libraries in Tater Tube Player

The Steam/Linux edition of Tater Tube Player dynamically links the Qt Community
Edition under LGPLv3. It does not cryptographically verify the bundled Qt
libraries and does not require Steam DRM.

Each binary release includes its exact application revision, Qt version,
FFmpeg version, build configuration, dependency records, and corresponding
source locations under `licenses/` and `compliance/`.

## Rebuild and replacement outline

1. Download the application and third-party source archives identified by the
   release's `source-manifest.txt`.
2. Build the listed Qt version as shared libraries for Linux x86-64, applying
   any patches recorded in that manifest.
3. Build Tater Tube Player against that Qt installation with
   `TATER_STEAM_RELEASE=ON` and `TATER_DEPLOY_QT_RUNTIME=ON`.
4. In a writable copy of the depot, replace the compatible `libQt6*.so.6`
   libraries under `lib/`. Replace matching Qt plugins or QML modules under
   `plugins/` and `qml/` when the modification requires them.
5. Start the writable copy with the top-level `tater-tube-player` launcher.

The launcher resolves libraries, plugins, and QML modules relative to its own
depot directory. No license key or Tater-controlled signature is required to
run a build with compatible modified Qt libraries. Steam's “verify installed
files” feature may restore official files, so experimentation should be done in
a separate writable copy.

ABI-incompatible Qt changes may require rebuilding the Apache-2.0 application
from the published source. This source availability is intentional and is part
of the release's relinking path.
