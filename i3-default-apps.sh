#!/bin/bash

# ==========================================
# i3wm デフォルトアプリケーション設定ツール
# 既存のシステム設定 (cinnamon-settings / gnome-control-center / xdg-mime) と連携し、
# Webブラウザ、ファイルマネージャー、エディタ、ターミナル等の既定アプリを設定・保存します
# ==========================================

CONFIG_DIR="$HOME/.config/i3"
TERMINAL_CONF="$CONFIG_DIR/terminal.conf"

get_app_name() {
    local desktop_file="$1"
    local name=""
    if [ -f "$desktop_file" ]; then
        name=$(grep -m 1 "^Name\[ja\]=" "$desktop_file" 2>/dev/null | cut -d'=' -f2)
        if [ -z "$name" ]; then
            name=$(grep -m 1 "^Name=" "$desktop_file" 2>/dev/null | cut -d'=' -f2)
        fi
    fi
    if [ -z "$name" ]; then
        echo "$(basename "$desktop_file" .desktop)"
    else
        echo "$name"
    fi
}

get_current_default() {
    local mime="$1"
    xdg-mime query default "$mime" 2>/dev/null
}

get_current_default_name() {
    local mime="$1"
    local current_desktop=$(get_current_default "$mime")
    if [ -z "$current_desktop" ]; then
        echo "未設定"
        return
    fi
    for dir in "/usr/share/applications" "$HOME/.local/share/applications" "/var/lib/snapd/desktop/applications" "/var/lib/flatpak/exports/share/applications"; do
        if [ -f "$dir/$current_desktop" ]; then
            get_app_name "$dir/$current_desktop"
            return
        fi
    done
    echo "$current_desktop"
}

set_mime_default() {
    local desktop_basename="$1"
    shift
    local mimes=("$@")

    for m in "${mimes[@]}"; do
        xdg-mime default "$desktop_basename" "$m" 2>/dev/null || true
    done
}

configure_category() {
    local category_name="$1"
    local primary_mime="$2"
    local category_tag="$3"
    shift 3
    local all_mimes=("$@")

    local current_desktop=$(get_current_default "$primary_mime")
    local current_name=$(get_current_default_name "$primary_mime")

    local seen_bases=()
    local options=()
    
    for dir in "/usr/share/applications" "$HOME/.local/share/applications" "/var/lib/snapd/desktop/applications" "/var/lib/flatpak/exports/share/applications"; do
        if [ -d "$dir" ]; then
            for f in "$dir"/*.desktop; do
                [ -e "$f" ] || continue
                if grep -q "$primary_mime" "$f" 2>/dev/null || grep -q "Categories=.*$category_tag" "$f" 2>/dev/null; then
                    local base=$(basename "$f")
                    local app_title=$(get_app_name "$f")
                    if [[ ! " ${seen_bases[*]} " =~ " ${base} " ]]; then
                        seen_bases+=("$base")
                        local prefix="  "
                        local suffix=""
                        if [ "$base" = "$current_desktop" ]; then
                            prefix="⭐ "
                            suffix=" [現在設定中]"
                        fi
                        options+=("${prefix}${app_title} (${base})${suffix}")
                    fi
                fi
            done
        fi
    done

    if [ ${#options[@]} -eq 0 ]; then
        if command -v notify-send &>/dev/null && [ -n "$DISPLAY" ]; then
            notify-send "⚠️ デフォルトアプリ設定" "利用可能な $category_name アプリが見つかりませんでした" 2>/dev/null || true
        else
            echo "⚠️ $category_name アプリが見つかりませんでした"
        fi
        return
    fi

    local selected=""
    if command -v rofi &>/dev/null && [ -n "$DISPLAY" ]; then
        local rofi_input=$(printf '%s\n' "${options[@]}" | rofi -dmenu -i -p "選択: $category_name (現在: $current_name)")
        if [ -n "$rofi_input" ]; then
            selected="$rofi_input"
        fi
    else
        echo "=== $category_name 設定 (現在: $current_name) ==="
        local idx=1
        for opt in "${options[@]}"; do
            echo "$idx) $opt"
            ((idx++))
        done
        read -p "選択番号を入力してください: " num
        if [ "$num" -ge 1 ] && [ "$num" -le "${#options[@]}" ]; then
            selected="${options[$((num-1))]}"
        fi
    fi

    if [ -n "$selected" ]; then
        local chosen_base=$(echo "$selected" | sed -n 's/.*(\(.*\)).*/\1/p')
        local chosen_title=$(echo "$selected" | sed -E 's/^[⭐ ]*//; s/ \([^)]*\).*//')
        if [ -n "$chosen_base" ]; then
            set_mime_default "$chosen_base" "${all_mimes[@]}"
            if command -v notify-send &>/dev/null && [ -n "$DISPLAY" ]; then
                notify-send -h "string:x-dunst-stack-tag:default-app" -t 2000 "✅ デフォルトアプリ変更" "$category_name を「$chosen_title」に設定しました"
            else
                echo "✅ $category_name を「$chosen_title」に設定しました"
            fi
        fi
    fi
}

configure_terminal() {
    local terminals=("i3-sensible-terminal" "gnome-terminal" "kitty" "alacritty" "xterm" "konsole" "tilix" "xfce4-terminal")
    local installed=()
    for t in "${terminals[@]}"; do
        if command -v "$t" &>/dev/null; then
            installed+=("$t")
        fi
    done

    local current_term="i3-sensible-terminal"
    if [ -f "$TERMINAL_CONF" ]; then
        current_term=$(grep "^set \$term" "$TERMINAL_CONF" | awk '{print $3}')
    fi

    local options=()
    for t in "${installed[@]}"; do
        if [ "$t" = "$current_term" ]; then
            options+=("⭐ $t [現在設定中]")
        else
            options+=("  $t")
        fi
    done

    local selected=""
    if command -v rofi &>/dev/null && [ -n "$DISPLAY" ]; then
        selected=$(printf '%s\n' "${options[@]}" | rofi -dmenu -i -p "💻 標準ターミナル選択 (現在: $current_term)")
    else
        echo "=== 💻 標準ターミナル選択 (現在: $current_term) ==="
        local idx=1
        for opt in "${options[@]}"; do
            echo "$idx) $opt"
            ((idx++))
        done
        read -p "選択番号を入力してください: " num
        if [ "$num" -ge 1 ] && [ "$num" -le "${#options[@]}" ]; then
            selected="${options[$((num-1))]}"
        fi
    fi

    if [ -n "$selected" ]; then
        local chosen_term=$(echo "$selected" | sed -E 's/^[⭐ ]*//; s/ \[.*\]//')
        mkdir -p "$CONFIG_DIR"
        echo "# i3wm Configured Terminal" > "$TERMINAL_CONF"
        echo "set \$term $chosen_term" >> "$TERMINAL_CONF"
        if command -v i3-msg &>/dev/null && pgrep -x i3 &>/dev/null; then
            i3-msg reload >/dev/null 2>&1 || true
        fi
        if command -v notify-send &>/dev/null && [ -n "$DISPLAY" ]; then
            notify-send -h "string:x-dunst-stack-tag:default-app" -t 2000 "✅ ターミナル変更" "標準ターミナルを「$chosen_term」に設定しました"
        else
            echo "✅ 標準ターミナルを「$chosen_term」に設定しました"
        fi
    fi
}

main_menu() {
    local cur_browser=$(get_current_default_name "text/html")
    local cur_fm=$(get_current_default_name "inode/directory")
    local cur_editor=$(get_current_default_name "text/plain")
    local cur_img=$(get_current_default_name "image/png")
    local cur_media=$(get_current_default_name "video/mp4")
    local cur_mail=$(get_current_default_name "x-scheme-handler/mailto")
    
    local cur_term="i3-sensible-terminal"
    if [ -f "$TERMINAL_CONF" ]; then
        cur_term=$(grep "^set \$term" "$TERMINAL_CONF" | awk '{print $3}')
    fi

    local menu_items=(
        "🌐 Web ブラウザ (現在: $cur_browser)"
        "📁 ファイルマネージャー (現在: $cur_fm)"
        "📝 テキストエディタ (現在: $cur_editor)"
        "🖼️ 画像ビューア (現在: $cur_img)"
        "🎬 動画・音楽プレーヤー (現在: $cur_media)"
        "✉️ メールクライアント (現在: $cur_mail)"
        "💻 標準ターミナル (現在: $cur_term)"
    )

    if command -v cinnamon-settings &>/dev/null; then
        menu_items+=("⚙️ Cinnamon GUI設定ツールを起動")
    elif command -v gnome-control-center &>/dev/null; then
        menu_items+=("⚙️ GNOME GUI設定ツールを起動")
    fi

    local choice=""
    if command -v rofi &>/dev/null && [ -n "$DISPLAY" ]; then
        choice=$(printf '%s\n' "${menu_items[@]}" | rofi -dmenu -i -p "⚙️ デフォルトアプリケーション設定")
    elif [ ! -t 0 ] && [ -n "$DISPLAY" ]; then
        if command -v i3-sensible-terminal &>/dev/null; then
            exec i3-sensible-terminal -e "$0"
        elif command -v x-terminal-emulator &>/dev/null; then
            exec x-terminal-emulator -e "$0"
        fi
    else
        echo "=========================================="
        echo "⚙️ デフォルトアプリケーション設定"
        echo "=========================================="
        local idx=1
        for item in "${menu_items[@]}"; do
            echo "$idx) $item"
            ((idx++))
        done
        read -p "選択してください [1-${#menu_items[@]}]: " num
        if [ "$num" -ge 1 ] && [ "$num" -le "${#menu_items[@]}" ]; then
            choice="${menu_items[$((num-1))]}"
        fi
    fi

    case "$choice" in
        *"Web ブラウザ"*)
            configure_category "Web ブラウザ" "text/html" "WebBrowser" "text/html" "x-scheme-handler/http" "x-scheme-handler/https"
            ;;
        *"ファイルマネージャー"*)
            configure_category "ファイルマネージャー" "inode/directory" "FileManager" "inode/directory"
            ;;
        *"テキストエディタ"*)
            configure_category "テキストエディタ" "text/plain" "TextEditor" "text/plain"
            ;;
        *"画像ビューア"*)
            configure_category "画像ビューア" "image/png" "Viewer" "image/png" "image/jpeg" "image/gif" "image/webp"
            ;;
        *"動画・音楽プレーヤー"*)
            configure_category "メディアプレーヤー" "video/mp4" "AudioVideo" "video/mp4" "video/x-matroska" "video/webm" "audio/mpeg" "audio/flac"
            ;;
        *"メールクライアント"*)
            configure_category "メールクライアント" "x-scheme-handler/mailto" "Email" "x-scheme-handler/mailto"
            ;;
        *"標準ターミナル"*)
            configure_terminal
            ;;
        *"Cinnamon GUI"*|*"GNOME GUI"*)
            if command -v cinnamon-settings &>/dev/null; then
                cinnamon-settings default &
            elif command -v gnome-control-center &>/dev/null; then
                gnome-control-center default-apps &
            fi
            ;;
    esac
}

main_menu
