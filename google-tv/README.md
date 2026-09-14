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
- Display, codec, HDR, HDMI audio, resolution, and channel capability reporting
- Server-selected direct, selective-transcode, or full-transcode playback plan
- Media3 playback with subtitles off by default, English audio preference,
  remote seeking, a Tater playback overlay, MediaSession, and sleep prevention
- Immediate local progress updates followed by server synchronization
- Fictional demo mode available from the pairing screen

Library depth, the full Tube TV guide, Discovery release selection, Tater Picks
speech, full audio/subtitle cycling, and Android TV home recommendations are the
next parity slices. The server contract is already shared; these are native UI
and player integrations rather than server migrations.

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
