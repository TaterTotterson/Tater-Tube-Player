# Google Play submission checklist

## Release bundle

- [x] TV-only Leanback launcher declared
- [x] Touchscreen marked optional
- [x] `minSdk` is 31 or lower
- [x] Current target SDK requirement met
- [x] 32-bit and 64-bit architectures present
- [x] Native libraries use 16 KB ELF alignment
- [x] Signed AAB workflow rejects missing signing secrets
- [x] Unit tests and release lint run before bundle creation
- [ ] Download the signed workflow artifact and upload it to an internal test
- [ ] Confirm package ID `com.tatertotterson.tatertubeplayer` before first upload
- [ ] Keep Play App Signing enabled
- [ ] Increase `version_code` for every subsequent Play upload

## Store listing

- [x] 512 x 512 Play Store icon
- [x] 1024 x 500 feature graphic
- [x] 1280 x 720 Android TV banner
- [x] Capture at least four current 1920 x 1080 Google TV screenshots
- [ ] Mention Android TV and Google TV in the full description
- [ ] Clearly state that Tater Tube Server is separately installed and no media
      is included
- [ ] Add support email and support URL
- [ ] Add https://tatertube.tv/privacy/ as the privacy policy URL
- [ ] Declare AI-generated or AI-edited assets accurately when prompted

## App content

- [ ] Complete Data Safety from the actual release behavior
- [ ] Complete the ads declaration
- [ ] Complete target audience and content rating
- [ ] Add the steps from `REVIEW_NOTES.md` under App access
- [ ] Complete any content-rights declaration accurately
- [ ] Opt the release into the Android TV form factor

Tater Tube Player does not include an ad SDK or developer-supplied paid
advertising. User-configured station breaks on a user's own Tater Tube Server do
not give Tater Totterson AI LLC access to or control over that media.

## Final TV verification

- [ ] Install from Google Play's internal test track, not ADB
- [ ] Test cold launch and Try Demo playback
- [ ] Test pairing and reconnect
- [ ] Test local movie and episode playback
- [ ] Test Discover playback and resume
- [ ] Test Tube TV program, bumper, and commercial transitions
- [ ] Verify channel logo hides during breaks
- [ ] Verify audio and subtitle selection
- [ ] Verify seeking, Back behavior, MediaSession, and sleep prevention
- [ ] Run a 30-minute playback soak test and briefly interrupt the network
