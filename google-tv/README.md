# Tater Tube Player for Google TV

This directory contains the native Google TV and Android TV edition of Tater
Tube Player. It uses the same additive Tater Tube Server player API as the Steam
and Apple TV clients while using Kotlin, Compose for TV, and AndroidX Media3.

## Current foundation

- TV-only Leanback launcher with no touchscreen requirement
- Black and orange Tater interface with dark glass surfaces and remote focus
- Slide-out navigation, Home hero, Continue Watching, Recently Added, and live shelves
- Pairing with private-LAN HTTP support and HTTPS enforcement for remote hosts
- Player token encrypted by Android Keystore
- Cached Home response displayed before background refresh
- Cached Library shelves and pages with complete movie, show, season, and episode navigation
- Compact Tube TV guide with channel logos, current-program progress, and grouped commercial breaks
- Discover catalog, title feeds, release search, multi-file selection, and prepared playback
- Scheduled Tater Picks with per-title reasons and automatic Tater voice playback
- Display, codec, HDR, HDMI audio, resolution, and channel capability reporting
- Server-selected direct, selective-transcode, or full-transcode playback plan
- Media3 playback with subtitles off by default, English audio preference,
  native audio/subtitle cycling, remote seeking, a Tater playback overlay,
  MediaSession, sleep prevention, and automatic next-episode playback
- Immediate local progress updates followed by server synchronization
- Android TV Watch Next publishing and direct resume links for Continue Watching
- Fictional demo mode with bundled rights-safe H.264/AAC playback available
  from the pairing screen

The shared server contract is used without a Google-TV-specific migration.
Physical-device QA remains necessary for remote focus behavior, decoder and
HDMI capability reporting, playback transitions, and launcher integration.

## Build

Install Android SDK Platform 37 and JDK 17 or newer, then run:

```bash
./gradlew :app:assembleDebug
```

The debug APK is written to:

```text
app/build/outputs/apk/debug/app-debug.apk
```

Install it on a network-connected Google TV or Android TV device with:

```bash
adb connect DEVICE_IP
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

Open the app from the TV launcher and choose **Try Demo** or pair it with Tater
Tube Server using the server address and pairing code.

## Signed Google Play bundle

The unified `Release builds` GitHub Actions workflow builds the production AAB
on a hosted Linux runner. It requires these repository secrets:

- `ANDROID_RELEASE_KEYSTORE_BASE64`
- `ANDROID_RELEASE_STORE_PASSWORD`
- `ANDROID_RELEASE_KEY_ALIAS`
- `ANDROID_RELEASE_KEY_PASSWORD`

Run the workflow manually for validation, optionally supplying a version name
and monotonically increasing Play version code. Publishing a matching GitHub
release builds all three Player editions and attaches the signed AAB plus its
SHA-256 checksum to that release. The Google TV job runs unit tests and release
lint, rejects missing or partial signing configuration, and verifies the bundle
signature before publishing it.

The upload keystore and its password backup must remain outside the repository.
Use the upload key for Play Console delivery and leave Play App Signing enabled.

Google Play graphics, reviewer notes, provenance, and the submission checklist
are under [`../store/google-play/`](../store/google-play/).
