#!/bin/bash

# ==========================================
# i3wm システム全体 ライト/ダークテーマ設定ツール
# 動作中の全アプリケーション(GTK3/4, D-Bus Portal, Qt, Electron, i3bar, i3status)へ
# 完全分離された高コントラスト設定(ダーク/ライト)を一括適用・同期します
# ==========================================

THEME_FILE="$HOME/.config/i3/current_theme"
I3_DIR="$HOME/.config/i3"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"

get_current_theme() {
    if [ -f "$THEME_FILE" ]; then
        cat "$THEME_FILE"
    else
        echo "dark"
    fi
}

find_config() {
    local name="$1"
    if [ -f "$I3_DIR/$name" ]; then
        echo "$I3_DIR/$name"
    elif [ -f "$SCRIPT_DIR/$name" ]; then
        echo "$SCRIPT_DIR/$name"
    fi
}

apply_system_theme() {
    local theme_name="$1"     # "Adwaita-dark" or "Adwaita"
    local prefer_dark="$2"    # 1 or 0
    local color_scheme="$3"   # "prefer-dark" or "prefer-light"
    local portal_scheme="$4"  # 1 (dark) or 2 (light)

    # 1. freedesktop.org Portal D-Bus 通知 (Firefox, Chromium, Flatpak, VSCode, Libadwaita 用)
    if command -v dbus-send &>/dev/null && [ -n "$DISPLAY" ]; then
        dbus-send --session --dest=org.freedesktop.portal.Desktop \
            --type=method_call /org/freedesktop/portal/desktop \
            org.freedesktop.portal.Settings.Set \
            string:"org.freedesktop.appearance" string:"color-scheme" variant:uint32:"$portal_scheme" 2>/dev/null || true
    fi

    # 2. gsettings 環境設定 (GNOME / GTK アプリ用)
    if command -v gsettings &>/dev/null; then
        gsettings set org.gnome.desktop.interface color-scheme "$color_scheme" 2>/dev/null || true
        gsettings set org.gnome.desktop.interface gtk-theme "$theme_name" 2>/dev/null || true
    fi

    # 3. GTK 3.0 および 4.0 設定ファイルの更新
    mkdir -p "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"
    cat <<EOF > "$HOME/.config/gtk-3.0/settings.ini"
[Settings]
gtk-theme-name=$theme_name
gtk-application-prefer-dark-theme=$prefer_dark
EOF
    cat <<EOF > "$HOME/.config/gtk-4.0/settings.ini"
[Settings]
gtk-theme-name=$theme_name
gtk-application-prefer-dark-theme=$prefer_dark
EOF

    # 4. xsettingsd 設定の更新とシグナル送信 (起動中X11アプリへのリアルタイムテーマ変更ブロードキャスト)
    mkdir -p "$HOME/.config/xsettingsd"
    cat <<EOF > "$HOME/.config/xsettingsd/xsettingsd.conf"
Net/ThemeName "$theme_name"
Gtk/ApplicationPreferDarkTheme $prefer_dark
Gtk/ColorScheme "$color_scheme"
EOF

    if command -v xsettingsd &>/dev/null; then
        if pgrep -x xsettingsd >/dev/null; then
            pkill -HUP -x xsettingsd 2>/dev/null || true
        else
            xsettingsd &>/dev/null &
        fi
    fi
}

apply_dark_theme() {
    echo "dark" > "$THEME_FILE"
    
    # 1. システム環境設定の適用 (Dark)
    apply_system_theme "Adwaita-dark" 1 "prefer-dark" 1

    # 2. i3status.conf (専用ダークモード設定ファイルのロード)
    local dark_conf=$(find_config "i3status-dark.conf")
    mkdir -p "$I3_DIR"
    if [ -n "$dark_conf" ]; then
        cp "$dark_conf" "$I3_DIR/i3status.conf"
    fi

    # 3. i3 config テーマ定義の書き換え (Dark)
    cat <<EOF > "$I3_DIR/theme.conf"
# i3wm Dark Theme Colors
set \$theme_bg #181825
set \$theme_fg #CDD6F4
set \$theme_separator #45475A
set \$theme_focused_bg #89B4FA
set \$theme_focused_fg #11111B
set \$theme_active_bg #45475A
set \$theme_active_fg #CDD6F4
set \$theme_inactive_bg #181825
set \$theme_inactive_fg #A6ADC8
set \$theme_urgent_bg #F38BA8
set \$theme_urgent_fg #11111B
EOF

    # 4. i3status プロセスを再起動して設定を適用
    pkill -x i3status 2>/dev/null || true

    if command -v notify-send &>/dev/null && [ -n "$DISPLAY" ]; then
        notify-send -h "string:x-dunst-stack-tag:theme" -t 1500 "🌙 システムテーマ変更" "ダークモードを適用しました"
    else
        echo "✅ 全アプリケーションへダークモードを適用しました"
    fi
}

apply_light_theme() {
    echo "light" > "$THEME_FILE"
    
    # 1. システム環境設定の適用 (Light)
    apply_system_theme "Adwaita" 0 "prefer-light" 2

    # 2. i3status.conf (専用ライトモード高コントラスト設定ファイルのロード)
    local light_conf=$(find_config "i3status-light.conf")
    mkdir -p "$I3_DIR"
    if [ -n "$light_conf" ]; then
        cp "$light_conf" "$I3_DIR/i3status.conf"
    fi

    # 3. i3 config テーマ定義の書き換え (Light: 漆黒テキストで視認性を確保)
    cat <<EOF > "$I3_DIR/theme.conf"
# i3wm Light Theme Colors
set \$theme_bg #E6E9EF
set \$theme_fg #111827
set \$theme_separator #9CA0B0
set \$theme_focused_bg #1E66F5
set \$theme_focused_fg #FFFFFF
set \$theme_active_bg #CCD0DA
set \$theme_active_fg #111827
set \$theme_inactive_bg #E6E9EF
set \$theme_inactive_fg #4B5563
set \$theme_urgent_bg #D20F39
set \$theme_urgent_fg #FFFFFF
EOF

    # 4. i3status プロセスを再起動して設定を適用
    pkill -x i3status 2>/dev/null || true

    if command -v notify-send &>/dev/null && [ -n "$DISPLAY" ]; then
        notify-send -h "string:x-dunst-stack-tag:theme" -t 1500 "☀️ システムテーマ変更" "ライトモードを適用しました"
    else
        echo "✅ 全アプリケーションへライトモードを適用しました"
    fi
}

toggle_theme() {
    local current=$(get_current_theme)
    if [ "$current" = "dark" ]; then
        apply_light_theme
    else
        apply_dark_theme
    fi
    if command -v i3-msg &>/dev/null && pgrep -x i3 &>/dev/null; then
        i3-msg restart
    fi
}

# 引数別処理
case "$1" in
    apply)
        CURRENT=$(get_current_theme)
        if [ "$CURRENT" = "light" ]; then
            apply_light_theme
        else
            apply_dark_theme
        fi
        exit 0
        ;;
    dark)
        apply_dark_theme
        if command -v i3-msg &>/dev/null && pgrep -x i3 &>/dev/null; then
            i3-msg restart
        fi
        exit 0
        ;;
    light)
        apply_light_theme
        if command -v i3-msg &>/dev/null && pgrep -x i3 &>/dev/null; then
            i3-msg restart
        fi
        exit 0
        ;;
    toggle)
        toggle_theme
        exit 0
        ;;
esac

# GUI (Rofi) または CLI メニュー表示
if command -v rofi &>/dev/null && [ -n "$DISPLAY" ]; then
    CURRENT=$(get_current_theme)
    CHOICE=$(echo -e "🌙 ダークモード (Dark Theme)\n☀️ ライトモード (Light Theme)\n🔄 ダーク/ライト切り替え (Toggle)" | rofi -dmenu -i -p "🎨 テーマ設定 (現在: $CURRENT)")
    
    case "$CHOICE" in
        *"ダークモード"*)
            apply_dark_theme
            i3-msg restart
            ;;
        *"ライトモード"*)
            apply_light_theme
            i3-msg restart
            ;;
        *"切り替え"*)
            toggle_theme
            ;;
    esac
elif [ ! -t 0 ] && [ -n "$DISPLAY" ]; then
    if command -v i3-sensible-terminal &>/dev/null; then
        exec i3-sensible-terminal -e "$0"
    elif command -v x-terminal-emulator &>/dev/null; then
        exec x-terminal-emulator -e "$0"
    fi
else
    echo "🎨 システム全般テーマ設定 (現在: $(get_current_theme))"
    echo "----------------------------"
    echo "1) 🌙 ダークモード"
    echo "2) ☀️ ライトモード"
    echo "3) 🔄 モード切替 (Toggle)"
    read -p "選択してください [1-3]: " num
    case "$num" in
        1) apply_dark_theme; command -v i3-msg &>/dev/null && i3-msg restart ;;
        2) apply_light_theme; command -v i3-msg &>/dev/null && i3-msg restart ;;
        3) toggle_theme ;;
    esac
fi
