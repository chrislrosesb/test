# Handoff Notes

## 2026-10-26 — TestFlight refresh (build 3)

- The old TestFlight builds (build 2, ~April 2026) had expired (TestFlight builds last 90 days), so the app stopped launching.
- Uploaded fresh **iOS** and **Mac Catalyst** builds, version 1.0 (build 3), to App Store Connect / TestFlight. Both uploads succeeded and were processing at session end.
- `CURRENT_PROJECT_VERSION` bumped 2 → 3 in `ios/ReadingList/ReadingList.xcodeproj/project.pbxproj` and pushed to `main`.
- Gotcha hit this session: `~/Library/Developer` on this Mac is a symlink to `/Volumes/Extreme SSD Data/Developer`. That volume was attached but **unmounted**, which made every `xcodebuild` fail with "Couldn't create workspace arena folder". Fix: `diskutil mount disk5s1` (volume name "Extreme SSD Data"). Check this first if builds mysteriously fail.
- Build recipe (unchanged, matches CLAUDE.md): `xcodebuild archive` per platform, then `xcodebuild -exportArchive` with `ios/build/ExportOptions.plist` (`method: app-store-connect`, `destination: upload`, team `2V5659YMQ8`, automatic signing). Remember to bump `CURRENT_PROJECT_VERSION` on every upload.
- Nothing left to do: next TestFlight expiry will be ~late January 2027.

## 2026-10-26 — iPhone Duo exploration (mockups only, no app code changed)

- Research: `docs/iphone-duo-report.md` (Procrastinate-specific) and `docs/designing-for-iphone-duo.md` (reusable hand-off for any AI building Duo apps).
- Mockups: Design canvas "Procrastinate for iPhone Duo — Native" (https://claude.ai/artifact/83w7xDdWnjrWPV5LBUHBq1), 8 boards: closed Read tab, open landscape reader, open portrait full-screen reading, portrait with stories sidebar pulled in, book-pose read & reflect, Split View with Notes, tabletop morning triage, standing idea wall. Built from the app's real dark-mode styling; an older web-styled canvas exists and is superseded.
- Chris's usage note: he rarely listens to Audio Briefing — portrait reading with a pull-in sidebar is the main open-phone use case.
- Next step if pursued: in `ContentView`, pick TabView vs `IPadNavigationView` by `horizontalSizeClass` instead of device idiom, preserve state across the swap, then test in Xcode 27.1 Device Hub.
