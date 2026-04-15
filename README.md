# track-workout-ios-swift

Native iOS implementation of **Track Workout**. Swift + SwiftUI + Core Data.

**Source of truth for behavior:** [`blaine-2050/track-workout-core`](https://github.com/blaine-2050/track-workout-core) — prose specs live there; this repo implements them on iOS.

## Tech Stack

- **Language:** Swift
- **UI:** SwiftUI
- **Storage:** Core Data (SQLite)
- **Min iOS:** 16.0+
- **Xcode:** 14+ (iOS 26.2 SDK used on primary dev machine)

## Project Layout

```
track-workout-ios-swift/
├── TrackWorkout/
│   ├── TrackWorkout.xcodeproj
│   └── TrackWorkout/
│       ├── TrackWorkoutApp.swift
│       ├── ContentView.swift
│       ├── Models/            (Core Data model)
│       ├── Views/
│       ├── ViewModels/
│       ├── Persistence/
│       └── TestFixtures.swift
├── runs/                      (AI self-test reports + screenshots — gitignored bulk, committed reports)
├── CLAUDE.md
└── README.md
```

## Running

### Simulator
```bash
xcodebuild -project TrackWorkout/TrackWorkout.xcodeproj -scheme TrackWorkout \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build
xcrun simctl boot "iPhone 15 Pro" 2>/dev/null || true
open -a Simulator
xcrun simctl install booted <path-to-built-app>
xcrun simctl launch booted com.example.TrackWorkout
```

### Physical device (free provisioning, pre-paid-developer)
1. Open `TrackWorkout/TrackWorkout.xcodeproj` in Xcode.
2. Select your iPhone as destination (connected via cable).
3. Signing → Automatically manage signing, Team = your personal Apple ID.
4. Run. Trust the developer profile on the device: Settings → General → VPN & Device Management.
5. **Re-sign and re-install every 7 days** — free certs expire.

### Physical device (TestFlight, post-paid-developer)
Deferred until $99 Apple Developer account is active. Commands go here then.

## Self-Testing

AI-driven self-tests follow [`track-workout-core` COMPUTER_USE_PROTOCOL](https://github.com/blaine-2050/track-workout-core/blob/main/COMPUTER_USE_PROTOCOL.md).

- Workout scripts: [`track-workout-core/WORKOUT_SCRIPTS/`](https://github.com/blaine-2050/track-workout-core/tree/main/WORKOUT_SCRIPTS)
- Run reports land in `runs/<date>-<script>.md` with screenshots in `runs/screens/`.
- Screenshot command: `xcrun simctl io booted screenshot <path>.png`.

## Data Model

See [`track-workout-core/DATA_MODEL.md`](https://github.com/blaine-2050/track-workout-core/blob/main/DATA_MODEL.md). Core Data entities in `Models/` must mirror these fields.

## Status (as of 2026-04-14)

Migrated from the legacy `track-workout` monorepo (`apps/ios-swift`) into this standalone repo. No feature changes during migration — history starts fresh.
