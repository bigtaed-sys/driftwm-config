#!/usr/bin/env bash
# Автоматическая установка конфига driftwm (починенный райс автора).
#
# Использование:
#   ./install.sh            установить конфиг + extras в ~/.config/driftwm
#   ./install.sh --check    дополнительно прогнать `driftwm --check-config`
#
# Существующий config.toml не затирается молча — делается резервная копия
# config.toml.bak-<дата>.

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
        *) echo "Неизвестный аргумент: $arg" >&2; exit 1 ;;
    esac
done

if [[ ! -d "$SRC_DIR/extras" ]]; then
    echo "Ошибка: рядом со скриптом нет папки extras/ (запускай из корня репозитория)." >&2
    exit 1
fi

if [[ ! -f "$SRC_DIR/config.fixed.toml" ]]; then
    echo "Ошибка: не найден config.fixed.toml рядом со скриптом." >&2
    exit 1
fi

echo "==> Цель: $CONFIG_DIR"
mkdir -p "$CONFIG_DIR"

echo "==> Копирую extras -> $CONFIG_DIR/extras"
rm -rf "$CONFIG_DIR/extras"
cp -r "$SRC_DIR/extras" "$CONFIG_DIR/extras"

if [[ -f "$CONFIG_DIR/config.toml" ]]; then
    backup="$CONFIG_DIR/config.toml.bak-$(date +%Y%m%d-%H%M%S)"
    echo "==> Найден существующий config.toml, сохраняю в $backup"
    cp "$CONFIG_DIR/config.toml" "$backup"
fi

echo "==> Копирую config.fixed.toml -> $CONFIG_DIR/config.toml"
cp "$SRC_DIR/config.fixed.toml" "$CONFIG_DIR/config.toml"

echo "==> Делаю скрипты исполняемыми"
chmod +x "$CONFIG_DIR"/extras/scripts/*.sh 2>/dev/null || true
chmod +x "$CONFIG_DIR"/extras/widgets/launch.sh 2>/dev/null || true

echo "==> Готово."

if [[ "$RUN_CHECK" -eq 1 ]]; then
    if command -v driftwm >/dev/null 2>&1; then
        echo "==> driftwm --check-config"
        driftwm --check-config
    else
        echo "!! driftwm не найден в PATH — пропускаю --check-config." >&2
    fi
fi

cat <<'EOF'

Дальше:
  - Доставь внешние программы, если используешь их (autostart/биндинги):
      waybar swaync fuzzel alacritty swayosd swayidle
      sway-audio-idle-inhibit brightnessctl
    плюс тему курсора "elementary".
  - Виджеты drift-* требуют python/uv (extras/widgets/launch.sh).
  - Не нужное — закомментируй в ~/.config/driftwm/config.toml.
EOF
