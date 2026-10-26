#!/usr/bin/env bash
set -euo pipefail

BIN_PATH="${HOME}/.local/bin/auto-im-abc"
LAUNCH_AGENTS_DIR="${HOME}/Library/LaunchAgents"

for label in "com.auto-im-abc" "com.kun.auto-im-abc"; do
    launchctl bootout "gui/$(id -u)/${label}" 2>/dev/null || true
    rm -f "${LAUNCH_AGENTS_DIR}/${label}.plist"
done

rm -f "${BIN_PATH}"
echo "==> Stopped LaunchAgent and removed ${BIN_PATH}."
echo "    (Config file ~/.config/auto-im-abc/apps.txt was preserved.)"
