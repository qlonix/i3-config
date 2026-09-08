#!/bin/bash

# ==========================================
# i3wm システム全体 ライト/ダークテーマ設定ツール
# 動作中の全アプリケーション(GTK3/4, D-Bus Portal, Qt, Electron)のテーマを一括切り替え
# ステータスバーの安定表示を最優先し、画面下の表示を壊さずアプリテーマをリアルタイム同期します
# ==========================================

THEME_FILE="$HOME/.config/i3/current_theme"

get_current_theme() {
    if [ -f "$THEME_FILE" ]; then
        cat "$THEME_FILE"
    else
        echo "dark"
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
    apply_system_theme "Adwaita-dark" 1 "prefer-dark" 1

    if command -v notify-send &>/dev/null && [ -n "$DISPLAY" ]; then
        notify-send -h "string:x-dunst-stack-tag:theme" -t 1500 "🌙 システムテーマ変更" "アプリ全体にダークモードを適用しました"
    else
        echo "✅ アプリ全体にダークモードを適用しました"
    fi
}

apply_light_theme() {
    echo "light" > "$THEME_FILE"
    apply_system_theme "Adwaita" 0 "prefer-light" 2

    if command -v notify-send &>/dev/null && [ -n "$DISPLAY" ]; then
        notify-send -h "string:x-dunst-stack-tag:theme" -t 1500 "☀️ システムテーマ変更" "アプリ全体にライトモードを適用しました"
    else
        echo "✅ アプリ全体にライトモードを適用しました"
    fi
}

toggle_theme() {
    local current=$(get_current_theme)
    if [ "$current" = "dark" ]; then
        apply_light_theme
    else
        apply_dark_theme
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
        exit 0
        ;;
    light)
        apply_light_theme
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
    CHOICE=$(echo -e "🌙 ダークモード (Dark Theme)\n☀️ ライトモード (Light Theme)\n🔄 ダーク/ライト切り替え (Toggle)" | rofi -dmenu -i -p "🎨 システムテーマ設定 (現在: $CURRENT)")
    
    case "$CHOICE" in
        *"ダークモード"*)
            apply_dark_theme
            ;;
        *"ライトモード"*)
            apply_light_theme
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
        1) apply_dark_theme ;;
        2) apply_light_theme ;;
        3) toggle_theme ;;
    esac
fi
