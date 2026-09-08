# Corresponding source for binary releases

The complete Tater Tube Player source is published at:

https://github.com/TaterTotterson/Tater-Tube-Player

Each Steam build is made from a tagged revision. The matching GitHub release
must contain:

- the Tater Tube Player source archive generated from that tag;
- the exact corresponding source for every distributed Qt module;
- the exact corresponding source and configuration for FFmpeg and mpv;
- source or authoritative source references required by every other reciprocal
  dependency in the depot;
- `source-manifest.txt`, containing versions, download locations, archive
  hashes, and applied patches.

These release-controlled copies are required even when no Qt or FFmpeg source
was modified. Linking only to an upstream Qt download is not sufficient for the
project's LGPL distribution policy.

The same source manifest is installed under `licenses/` in the Steam depot. A
release must not be submitted until its source archives are publicly reachable
and controlled by the Tater Tube project.
