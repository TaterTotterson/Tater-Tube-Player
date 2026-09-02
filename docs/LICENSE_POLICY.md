# Dependency and asset policy

The new Tater Tube player is being created to have a substantially simpler distribution record
than the existing GPL Tater Tube client.

## Rules

1. Do not copy source code from Tater Tube or its 240-MP ancestry.
2. Record the source, copyright owner, license, version, and exact use of every
   production dependency.
3. Prefer platform SDKs and permissive MIT, BSD, Apache-2.0, ISC, and Zlib-style
   dependencies.
4. Any GPL, AGPL, LGPL, MPL, codec, patent, or proprietary dependency requires a
   written distribution decision before it enters a release build.
5. Keep Steamworks integration optional and isolated until the final licensing
   approach has been reviewed.
6. Generate an SBOM and third-party notices for every store build.
7. Do not bundle emulator cores, game engines, Moonlight, yt-dlp, or the old
   Tater Tube runtime.

## Qt decision gate

The prototype uses Qt Quick because it provides a productive Steam desktop UI.
Before release, choose and document either a commercial Qt license or a fully
compliant dynamic-linking and redistribution plan for the applicable Qt modules.

## Mascot assets

The initial mascot images were copied from the Tater repository at the product
owner's direction. Confirm and document their original creation records and
store-distribution rights before release. Do not assume that source-repository
license text alone establishes standalone artwork rights.

## Server boundary

Tater Tube Server remains a separately deployed network service. No server
source is compiled or copied into this client.
