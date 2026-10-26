#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${HOME}/.local/bin"
BIN_PATH="${BIN_DIR}/auto-im-abc"
CONFIG_DIR="${HOME}/.config/auto-im-abc"
CONFIG_FILE="${CONFIG_DIR}/apps.txt"
LAUNCH_AGENTS_DIR="${HOME}/Library/LaunchAgents"
LABEL="com.auto-im-abc"
PLIST_PATH="${LAUNCH_AGENTS_DIR}/${LABEL}.plist"

echo "==> Compiling auto-im-abc (Release -O)..."
mkdir -p "${BIN_DIR}" "${CONFIG_DIR}" "${LAUNCH_AGENTS_DIR}"
swiftc -O "${REPO_DIR}/Sources/auto-im-abc/main.swift" -o "${BIN_PATH}"

if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo "==> Creating default config at ${CONFIG_FILE}..."
    cp "${REPO_DIR}/config/apps.txt" "${CONFIG_FILE}"
else
    echo "==> Keeping existing config at ${CONFIG_FILE}"
fi

# Clean up legacy label if present
if [[ -f "${LAUNCH_AGENTS_DIR}/com.kun.auto-im-abc.plist" ]]; then
    launchctl bootout "gui/$(id -u)/com.kun.auto-im-abc" 2>/dev/null || true
    rm -f "${LAUNCH_AGENTS_DIR}/com.kun.auto-im-abc.plist"
fi

echo "==> Installing LaunchAgent to ${PLIST_PATH}..."
sed -e "s|__LABEL__|${LABEL}|g" \
    -e "s|__BIN_PATH__|${BIN_PATH}|g" \
    "${REPO_DIR}/config/com.auto-im-abc.plist.template" > "${PLIST_PATH}"

launchctl bootout "gui/$(id -u)/${LABEL}" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "${PLIST_PATH}"

echo "==> Installed and started ${LABEL} successfully!"
"${BIN_PATH}" --status
