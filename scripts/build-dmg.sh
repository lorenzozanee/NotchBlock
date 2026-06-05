#!/bin/bash
set -euo pipefail
# NotchBlock DMG Build Script — thin wrapper around build_dmg.py (dmgbuild).
# dmgbuild writes .DS_Store directly, avoiding the unreliable AppleScript/Finder approach.
cd "$(dirname "$0")/.."
exec python3 scripts/build_dmg.py "$@"
