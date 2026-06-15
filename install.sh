#!/usr/bin/env bash
# Self-contained installer for the driftwm config (fixed personal rice).
#
# By default it: installs system dependencies (needs sudo), installs a Nerd
# Font + uv, then copies the config and extras into ~/.config/driftwm.
#
# Usage:
#   ./install.sh                 deps + fonts + uv + config (full setup)
#   ./install.sh --config-only   only copy config + extras (no root, no fonts)
#   ./install.sh --no-deps       skip system packages
#   ./install.sh --no-fonts      skip Nerd Font / uv install
#   ./install.sh --check         also run `driftwm --check-config` at the end
#
# An existing config.toml is never overwritten silently: a backup
# config.toml.bak-<date> is made first. Missing distro packages are reported
# at the end instead of aborting the whole run.

set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/driftwm"
FONT_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/fonts"

DO_DEPS=1
DO_FONTS=1
RUN_CHECK=0
FAILED_PKGS=()

for arg in "$@"; do
    case "$arg" in
        --config-only) DO_DEPS=0; DO_FONTS=0 ;;
        --no-deps)     DO_DEPS=0 ;;
        --no-fonts)    DO_FONTS=0 ;;
        --check)       RUN_CHECK=1 ;;
        -h|--help)     sed -n '2,18p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Unknown argument: $arg" >&2; exit 1 ;;
    esac
done

have() { command -v "$1" >/dev/null 2>&1; }

SUDO=""
if [[ "$(id -u)" -ne 0 ]]; then SUDO="sudo"; fi

detect_pm() {
    if have pacman; then echo pacman
    elif have dnf; then echo dnf
    elif have apt-get; then echo apt
    elif have zypper; then echo zypper
    else echo unknown; fi
}

# Packages per manager. Names that don't exist on a given distro are simply
# reported as failures at the end (often AUR/COPR: swaync, swayosd,
# sway-audio-idle-inhibit, elementary cursor theme).
packages_for() {
    case "$1" in
        pacman) echo waybar fuzzel alacritty swayidle swaylock swaync swayosd \
                     sway-audio-idle-inhibit grim slurp wlr-randr wl-clipboard \
                     ffmpeg brightnessctl polkit-gnome networkmanager wireplumber \
                     bluez-utils python unzip curl ;;
        dnf)    echo waybar fuzzel alacritty swayidle swaylock swaync grim slurp \
                     wlr-randr wl-clipboard ffmpeg-free brightnessctl \
                     polkit-gnome NetworkManager wireplumber bluez python3 unzip curl ;;
        apt)    echo waybar fuzzel alacritty swayidle swaylock \
                     sway-notification-center grim slurp wlr-randr wl-clipboard \
                     ffmpeg brightnessctl policykit-1-gnome network-manager \
                     wireplumber bluez python3 unzip curl ;;
        zypper) echo waybar fuzzel alacritty swayidle swaylock grim slurp \
                     wlr-randr wl-clipboard ffmpeg brightnessctl \
                     polkit-gnome NetworkManager wireplumber bluez python3 unzip curl ;;
    esac
}

pm_install_one() {
    case "$PM" in
        pacman) $SUDO pacman -S --needed --noconfirm "$1" ;;
        dnf)    $SUDO dnf install -y "$1" ;;
        apt)    $SUDO apt-get install -y "$1" ;;
        zypper) $SUDO zypper --non-interactive install --no-recommends "$1" ;;
    esac
}

install_packages() {
    PM="$(detect_pm)"
    if [[ "$PM" == "unknown" ]]; then
        echo "!! Unknown package manager - skipping system packages." >&2
        echo "   Install manually: waybar fuzzel alacritty swayidle swaylock swaync" >&2
        echo "   swayosd grim slurp wlr-randr wl-clipboard ffmpeg brightnessctl" >&2
        return
    fi
    echo "==> Installing system packages via $PM (sudo may prompt)"
    [[ "$PM" == "apt" ]] && $SUDO apt-get update -y >/dev/null 2>&1 || true
    for p in $(packages_for "$PM"); do
        printf '  -> %-28s' "$p"
        if pm_install_one "$p" >/dev/null 2>&1; then
            echo "ok"
        else
            echo "FAILED"
            FAILED_PKGS+=("$p")
        fi
    done
}

# swaylock authenticates via PAM. Without /etc/pam.d/swaylock it rejects every
# password (the unlock ring lights up but never accepts) - so resume-from-sleep
# leaves you locked out. Create the file if the package didn't ship one.
setup_swaylock_pam() {
    have swaylock || return 0
    if [[ -f /etc/pam.d/swaylock ]]; then
        echo "==> /etc/pam.d/swaylock already present"
        return 0
    fi
    local base
    if [[ -f /etc/pam.d/system-auth ]]; then base=system-auth
    elif [[ -f /etc/pam.d/common-auth ]]; then base=common-auth
    else
        echo "!! No system-auth/common-auth - configure /etc/pam.d/swaylock by hand." >&2
        return 0
    fi
    echo "==> Creating /etc/pam.d/swaylock (auth include $base)"
    echo "auth include $base" | $SUDO tee /etc/pam.d/swaylock >/dev/null
}

install_uv() {
    if have uv; then echo "==> uv already installed"; return; fi
    echo "==> Installing uv (Python runner for widgets)"
    if have curl; then
        curl -LsSf https://astral.sh/uv/install.sh | sh
    elif have wget; then
        wget -qO- https://astral.sh/uv/install.sh | sh
    else
        echo "!! Neither curl nor wget found - cannot install uv." >&2
    fi
}

install_font() {
    local name="JetBrainsMono" zip url target
    url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${name}.zip"
    target="$FONT_DIR/${name}NerdFont"
    if fc-list 2>/dev/null | grep -qi "JetBrainsMono Nerd Font"; then
        echo "==> JetBrainsMono Nerd Font already installed"
        return
    fi
    echo "==> Installing JetBrainsMono Nerd Font (widget icons)"
    mkdir -p "$target"
    zip="$(mktemp --suffix=.zip)"
    if have curl; then curl -fLo "$zip" "$url"
    elif have wget; then wget -qO "$zip" "$url"
    else echo "!! No curl/wget - cannot download font." >&2; return; fi
    if have unzip; then
        unzip -o "$zip" -d "$target" >/dev/null && echo "  -> unpacked to $target"
    else
        echo "!! unzip not found - cannot extract font." >&2
    fi
    rm -f "$zip"
    have fc-cache && fc-cache -f "$FONT_DIR" >/dev/null 2>&1 || true
}

install_config() {
    if [[ ! -d "$SRC_DIR/extras" || ! -f "$SRC_DIR/config.fixed.toml" ]]; then
        echo "Error: run from the repo root (need extras/ and config.fixed.toml)." >&2
        exit 1
    fi
    echo "==> Target: $CONFIG_DIR"
    mkdir -p "$CONFIG_DIR"

    echo "==> Copying extras -> $CONFIG_DIR/extras"
    rm -rf "$CONFIG_DIR/extras"
    cp -r "$SRC_DIR/extras" "$CONFIG_DIR/extras"

    if [[ -f "$CONFIG_DIR/config.toml" ]]; then
        local backup="$CONFIG_DIR/config.toml.bak-$(date +%Y%m%d-%H%M%S)"
        echo "==> Existing config.toml found, backing up to $backup"
        cp "$CONFIG_DIR/config.toml" "$backup"
    fi

    echo "==> Copying config.fixed.toml -> $CONFIG_DIR/config.toml"
    cp "$SRC_DIR/config.fixed.toml" "$CONFIG_DIR/config.toml"

    echo "==> Making scripts executable"
    chmod +x "$CONFIG_DIR"/extras/scripts/*.sh 2>/dev/null || true
    chmod +x "$CONFIG_DIR"/extras/widgets/launch.sh 2>/dev/null || true
}

[[ "$DO_DEPS"  -eq 1 ]] && { install_packages; setup_swaylock_pam; }
[[ "$DO_FONTS" -eq 1 ]] && { install_uv; install_font; }
install_config

if [[ "$RUN_CHECK" -eq 1 ]]; then
    if have driftwm; then
        echo "==> driftwm --check-config"
        driftwm --check-config
    else
        echo "!! driftwm not found in PATH - skipping --check-config." >&2
    fi
fi

echo "==> Done."

if [[ "${#FAILED_PKGS[@]}" -gt 0 ]]; then
    echo
    echo "Some packages could not be installed automatically:"
    printf '  - %s\n' "${FAILED_PKGS[@]}"
    echo "These are often in the AUR / COPR / not packaged for your distro."
    echo "Install them by hand, or comment out the matching lines in"
    echo "~/.config/driftwm/config.toml. driftwm runs fine without them."
fi

cat <<'EOF'

Notes:
  - The "elementary" cursor theme and the taskbar app-icon theme are not
    auto-installed (distro-specific). See extras/icons/icons.md.
  - Widget icons need a Nerd Font (installed above). If they still show as
    boxes, run: fc-cache -f  and restart the widgets.
EOF
