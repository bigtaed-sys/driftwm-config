#!/usr/bin/env bash
# Automatic installer for the driftwm config (fixed personal rice).
#
# Usage:
#   ./install.sh            install config + extras into ~/.config/driftwm
#   ./install.sh --check    also run `driftwm --check-config`
#
# An existing config.toml is never overwritten silently: a backup
# config.toml.bak-<date> is made first.

set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/driftwm"
RUN_CHECK=0

for arg in "$@"; do
    case "$arg" in
        --check) RUN_CHECK=1 ;;
        -h|--help)
            sed -n '2,9p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *) echo "Unknown argument: $arg" >&2; exit 1 ;;
    esac
done

if [[ ! -d "$SRC_DIR/extras" ]]; then
    echo "Error: no extras/ folder next to the script (run from the repo root)." >&2
    exit 1
fi

if [[ ! -f "$SRC_DIR/config.fixed.toml" ]]; then
    echo "Error: config.fixed.toml not found next to the script." >&2
    exit 1
fi

echo "==> Target: $CONFIG_DIR"
mkdir -p "$CONFIG_DIR"

echo "==> Copying extras -> $CONFIG_DIR/extras"
rm -rf "$CONFIG_DIR/extras"
cp -r "$SRC_DIR/extras" "$CONFIG_DIR/extras"

if [[ -f "$CONFIG_DIR/config.toml" ]]; then
    backup="$CONFIG_DIR/config.toml.bak-$(date +%Y%m%d-%H%M%S)"
    echo "==> Existing config.toml found, backing up to $backup"
    cp "$CONFIG_DIR/config.toml" "$backup"
fi

echo "==> Copying config.fixed.toml -> $CONFIG_DIR/config.toml"
cp "$SRC_DIR/config.fixed.toml" "$CONFIG_DIR/config.toml"

echo "==> Making scripts executable"
chmod +x "$CONFIG_DIR"/extras/scripts/*.sh 2>/dev/null || true
chmod +x "$CONFIG_DIR"/extras/widgets/launch.sh 2>/dev/null || true

echo "==> Done."

if [[ "$RUN_CHECK" -eq 1 ]]; then
    if command -v driftwm >/dev/null 2>&1; then
        echo "==> driftwm --check-config"
        driftwm --check-config
    else
        echo "!! driftwm not found in PATH - skipping --check-config." >&2
    fi
fi

cat <<'EOF'

Next steps:
  - Install the external programs you use (autostart / keybindings):
      waybar swaync fuzzel alacritty swayosd swayidle
      sway-audio-idle-inhibit brightnessctl
    plus the "elementary" cursor theme.
  - The drift-* widgets need python/uv (extras/widgets/launch.sh).
  - Comment out anything you do not need in ~/.config/driftwm/config.toml.
EOF
