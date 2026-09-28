#!/usr/bin/env bash
set -euo pipefail
kpackagetool6 -t Plasma/Applet -r com.github.jamesstuder.claudeusage 2>/dev/null || true
rm -f "$HOME/.local/bin/claude-usage"
echo "Removed (config in ~/.config/claude-usage and cache in ~/.cache/claude-usage were kept)."
