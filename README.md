# driftwm-config

Мой личный конфиг для оконного менеджера [**driftwm**](https://github.com/malbiruk/driftwm)
(trackpad-first infinite-canvas Wayland-компоновщик на Rust) + скрипт автоматической установки.

> Это **не** сам компоновщик, а только пользовательская конфигурация поверх него.
> Сам driftwm и его исходники — у авторов проекта по ссылке выше.

## Что внутри

| Файл / папка        | Описание                                                              |
| ------------------- | -------------------------------------------------------------------- |
| `config.fixed.toml` | Конфиг driftwm (починенный райс: без поворота экрана, без хардкод-путей) |
| `install.sh`        | Автоустановка конфига и `extras` в `~/.config/driftwm`                |
| `extras/`           | Райс: waybar, fuzzel, swaync, виджеты, обои-шейдеры, скрипты          |

## Установка

```bash
git clone https://github.com/bigtaed-sys/driftwm-config.git
cd driftwm-config
./install.sh            # установит конфиг + extras в ~/.config/driftwm
./install.sh --check    # то же + прогонит `driftwm --check-config`
```

Существующий `~/.config/driftwm/config.toml` не затирается молча — делается
резервная копия `config.toml.bak-<дата>`.

## Зависимости (внешние программы)

Конфиг рассчитывает на установленные программы (часть `autostart`/биндингов).
Доустанови из репозиториев дистрибутива или закомментируй ненужное в
`~/.config/driftwm/config.toml`:

```
waybar swaync fuzzel alacritty swayosd swayidle
sway-audio-idle-inhibit brightnessctl
```

Плюс тема курсора `elementary`. Виджеты `drift-*` требуют `python`/`uv`
(запускаются через `extras/widgets/launch.sh`).

Упавший `autostart` или битый биндинг не роняют сам компоновщик — driftwm
продолжит работать.

## Шрифты и иконки

- **Иконки в виджетах** (`drift-*`) — это глифы **Nerd Font**. Без него вместо
  иконок будут квадратики. Установи любой Nerd Font; проще всего символьный набор
  (fontconfig подставит глифы как fallback):
  - Arch: `sudo pacman -S ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-mono`
  - Fedora: `sudo dnf install nerd-fonts`
  - Универсально: распакуй
    [NerdFontsSymbolsOnly.zip](https://github.com/ryanoasis/nerd-fonts/releases/latest)
    в `~/.local/share/fonts` и выполни `fc-cache -f`.

  Виджеты берут `extras/alacritty/alacritty.toml`, где шрифт задан как
  `JetBrainsMono Nerd Font` — поставь его или поменяй имя на свой Nerd Font.

- **Иконки приложений в taskbar** (левая панель waybar) берутся из **темы иконок**,
  а не из шрифта. Нужна установленная тема (`elementary` и т.п.) — см.
  `extras/icons/icons.md`.

## Лицензия / атрибуция

Содержимое `extras/` происходит из проекта [driftwm](https://github.com/malbiruk/driftwm).
Все права на сам driftwm принадлежат его авторам. Этот репозиторий —
производная конфигурация для личного использования.
