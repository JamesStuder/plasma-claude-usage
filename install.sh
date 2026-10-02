#!/usr/bin/env bash
# Install the Claude Code Usage widget and its helper for the current user.
set -euo pipefail
cd "$(dirname "$0")"
command -v kpackagetool6 >/dev/null || { echo "kpackagetool6 not found (KDE Plasma 6 required)" >&2; exit 1; }

install -Dm755 bin/claude-usage "$HOME/.local/bin/claude-usage"
[ -e "$HOME/.config/claude-usage/config.toml" ] || install -Dm644 config.example.toml "$HOME/.config/claude-usage/config.toml"

if kpackagetool6 -t Plasma/Applet -l 2>/dev/null | grep -qx com.github.jamesstuder.claudeusage; then
    kpackagetool6 -t Plasma/Applet -u package
else
    kpackagetool6 -t Plasma/Applet -i package
fi
echo
echo "Installed. Add it via: right-click your panel → Add or Manage Widgets → 'Claude Code Usage'."
echo "(A Plasma restart may be needed the first time: systemctl --user restart plasma-plasmashell)"
