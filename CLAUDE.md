# CLAUDE.md — track-workout-ios-swift

## Source of truth
This repo implements Track Workout on iOS. **Behavior, data model, and acceptance criteria come from the core spec repo**, not from this repo's code.

Before non-trivial work, fetch the relevant core-repo file:
- Product: https://github.com/blaine-2050/track-workout-core/blob/main/PRD.md
- Data model: https://github.com/blaine-2050/track-workout-core/blob/main/DATA_MODEL.md
- Computer-use protocol: https://github.com/blaine-2050/track-workout-core/blob/main/COMPUTER_USE_PROTOCOL.md
- Workout scripts: https://github.com/blaine-2050/track-workout-core/tree/main/WORKOUT_SCRIPTS
- Decisions: https://github.com/blaine-2050/track-workout-core/blob/main/DECISIONS.md

If this repo's code disagrees with the core spec, the spec wins unless there's a decision recorded here or in core explaining the divergence.

## Stack (one line)
Swift + SwiftUI + Core Data. Min iOS 16. Xcode 14+.

## iOS-specific adapter notes (binding to COMPUTER_USE_PROTOCOL)

| Capability | Command |
|------------|---------|
| Build | `xcodebuild -project TrackWorkout/TrackWorkout.xcodeproj -scheme TrackWorkout -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build` |
| Boot simulator | `xcrun simctl boot "iPhone 15 Pro"` |
| Install | `xcrun simctl install booted <path>.app` |
| Launch | `xcrun simctl launch booted com.example.TrackWorkout` |
| Screenshot | `xcrun simctl io booted screenshot runs/screens/<file>.png` |
| UI driving | Tap-by-coordinate via `simctl` is brittle; prefer accessibility IDs when added. Until then, Claude Desktop's computer-use via the Simulator window is the fallback. |

## Gym-test checklist (physical device, free provisioning)

Pre-gym:
1. Plug iPhone into Mac. Trust computer if prompted.
2. Open Xcode project. Confirm signing team = your Apple ID.
3. Build & run to device (⌘R). Verify app launches and Core Data seed ran.
4. Unplug. Take phone to gym.

In-gym:
5. Log real sets. Note anything that feels slow, awkward, or wrong.
6. Take screen recordings of any unclear moment.
7. If the app crashes, capture the crash via Settings → Privacy → Analytics → Analytics Data.

Post-gym:
8. Back at the Mac: drop notes into `runs/<date>-gym.md`. Attach screen recordings / screenshots.
9. Open an issue on GitHub referencing the run file so it's readable from the Claude iOS app.

Cert re-sign ritual (weekly): rebuild + re-install via Xcode. Free certs expire every 7 days.

## Deployment
- **Now (pre-paid):** Xcode cable install only. No TestFlight. No App Store.
- **Future (post-paid):** TestFlight via `xcrun altool` or `fastlane pilot`. Commands documented here when $99 is paid.

## Project conventions
- Core Data entities in `Models/` must mirror `DATA_MODEL.md`. When that spec changes, migrate Core Data with a lightweight migration step.
- Weight unit is per-`LogEntry`, not global. This is non-negotiable — flagged in core spec.
- Never bypass the outbox. All writes go through local persistence first.

## Run reports
- Self-test runs land in `runs/<date>-<script>.md` with screenshots in `runs/screens/`.
- Commit reports and screenshots so they're reviewable from the Claude iOS app on GitHub.
- `runs/screens/` is not gitignored — mobile review depends on GitHub rendering them.
