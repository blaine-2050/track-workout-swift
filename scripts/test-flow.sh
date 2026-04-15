#!/usr/bin/env bash
# One-command: build app, wipe simulator state, launch, run Maestro flow.
#
# Usage:
#   scripts/test-flow.sh <flow-path>           # runs with iPhone 12, Debug
#   DEVICE="iPhone 17 Pro" scripts/test-flow.sh <flow-path>
#   SKIP_BUILD=1 scripts/test-flow.sh <flow-path>
#
# Env:
#   DEVICE       Simulator device name. Default: "iPhone 12"
#   BUNDLE_ID    App bundle id. Default: com.athenia.TrackWorkout
#   SKIP_BUILD   If set, skip xcodebuild (use last build)

set -euo pipefail

FLOW="${1:-}"
if [[ -z "$FLOW" ]]; then
  echo "usage: $0 <flow-path>" >&2
  exit 64
fi
if [[ ! -f "$FLOW" ]]; then
  echo "flow not found: $FLOW" >&2
  exit 66
fi

DEVICE="${DEVICE:-iPhone 12}"
BUNDLE_ID="${BUNDLE_ID:-com.athenia.TrackWorkout}"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_DIR="$REPO_ROOT/TrackWorkout"
APP_PATH="$PROJECT_DIR/build/Build/Products/Debug-iphonesimulator/TrackWorkout.app"

# Maestro + Java on PATH
export PATH="/opt/homebrew/opt/openjdk/bin:$HOME/.maestro/bin:$PATH"

# 1. Build (unless skipped)
if [[ -z "${SKIP_BUILD:-}" ]]; then
  echo "==> Building ($DEVICE, Debug)"
  xcodebuild \
    -project "$PROJECT_DIR/TrackWorkout.xcodeproj" \
    -scheme TrackWorkout \
    -destination "platform=iOS Simulator,name=$DEVICE" \
    -configuration Debug \
    -derivedDataPath "$PROJECT_DIR/build" \
    build >/tmp/test-flow-build.log 2>&1 \
    || { tail -20 /tmp/test-flow-build.log; exit 1; }
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "built app not found at $APP_PATH" >&2
  exit 1
fi

# 2. Boot simulator if needed
BOOTED=$(xcrun simctl list devices booted | grep -c "$DEVICE" || true)
if [[ "$BOOTED" == "0" ]]; then
  echo "==> Booting $DEVICE"
  xcrun simctl boot "$DEVICE"
  open -a Simulator
  xcrun simctl bootstatus "$DEVICE" -b >/dev/null
fi

# 3. Fresh install
echo "==> Wiping and reinstalling $BUNDLE_ID"
xcrun simctl terminate booted "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl uninstall booted "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl install booted "$APP_PATH"

# 4. Run Maestro (from repo root so runs/screens/ paths resolve)
echo "==> Running $FLOW"
cd "$REPO_ROOT"
maestro test "$FLOW"
