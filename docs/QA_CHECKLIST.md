# Vector Drift — development and operations

**Repository:** https://github.com/peter-dietrich/vector-drift  
**Role:** Original arcade-style vector space shooter  
**Minimum runtime:** macOS 13+  
**Technologies:** SwiftUI, SpriteKit, AppKit  
**Bundle ID:** io.vectordrift.prototype

## Automated verification

A successful GitHub Actions **macOS build** checks that the Xcode project compiles in CI. This is not a complete runtime, visual, licensing, signing or notarization audit. On a Mac, run:

```sh
xcodebuild -project VectorDrift.xcodeproj -scheme VectorDrift -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

Check the **Actions** page for current build runs. Where the repository provides test scripts, run them as well. No workflow should be reported as having passed until the exact commit run says success.

## Manual release-candidate checklist

- [ ] Xcode clean build succeeds with the intended Xcode/macOS versions.
- [ ] Start/title, active game, pause/resume, game-over, restart and window resize work.
- [ ] Test **Classic and Modern** (and other available presentation modes) without rendering regressions.
- [ ] Check keyboard focus, key-repeat, smooth updates, sound on/off and multiple screen sizes.
- [ ] Test local presets, saved games, load/migration, stale save handling and score persistence where supported.
- [ ] Inspect logs for warnings, crashes, sandbox issues, excessive CPU/memory and missing files.
- [ ] Verify `LICENSE`, `THIRD_PARTY_NOTICES.md`, all graphics/audio and external dependencies are reviewed.
- [ ] Validate Developer ID signing, notarization, Gatekeeper launch and downloadable artifacts if distributing externally.
- [ ] For Fun City integration, confirm exact bundle IDs and release asset names.

## Game-specific smoke tests

Verify all three graphics modes, mode-switch persistence, startup nebula visibility, 500-round capacity/recharge, directional controls, scores, shield/missile functions, settings, save/resume and sound.

## Evidence

Record the tested commit SHA, workflow URL, macOS version, Xcode version, test result, known defects and human approver in the release notes. CI passing by itself does **not** establish legal clearance or a notarized public release.
