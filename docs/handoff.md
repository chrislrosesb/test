# Handoff Notes

## 2026-10-26 — TestFlight refresh (build 3)

- The old TestFlight builds (build 2, ~April 2026) had expired (TestFlight builds last 90 days), so the app stopped launching.
- Uploaded fresh **iOS** and **Mac Catalyst** builds, version 1.0 (build 3), to App Store Connect / TestFlight. Both uploads succeeded and were processing at session end.
- `CURRENT_PROJECT_VERSION` bumped 2 → 3 in `ios/ReadingList/ReadingList.xcodeproj/project.pbxproj` and pushed to `main`.
- Gotcha hit this session: `~/Library/Developer` on this Mac is a symlink to `/Volumes/Extreme SSD Data/Developer`. That volume was attached but **unmounted**, which made every `xcodebuild` fail with "Couldn't create workspace arena folder". Fix: `diskutil mount disk5s1` (volume name "Extreme SSD Data"). Check this first if builds mysteriously fail.
- Build recipe (unchanged, matches CLAUDE.md): `xcodebuild archive` per platform, then `xcodebuild -exportArchive` with `ios/build/ExportOptions.plist` (`method: app-store-connect`, `destination: upload`, team `2V5659YMQ8`, automatic signing). Remember to bump `CURRENT_PROJECT_VERSION` on every upload.
- Nothing left to do: next TestFlight expiry will be ~late January 2027.
