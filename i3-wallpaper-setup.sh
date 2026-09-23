#!/bin/bash

# ==========================================
# i3wm デスクトップ壁紙 & ロック画面設定ツール (ncurses / dialog)
# ==========================================

CONF_DIR="$HOME/.config/i3"
WALL_CONF="$CONF_DIR/wallpaper.conf"
LOCK_IMG="$CONF_DIR/lockscreen.png"
HELPER_PY="$CONF_DIR/i3-wallpaper-helper.py"

# デフォルト設定値
DEFAULT_WALLPAPER="/usr/share/backgrounds/linuxmint/default_background.jpg"
WALLPAPER_PATH="$DEFAULT_WALLPAPER"
LOCK_STYLE="blur"     # blur / original / color
BG_COLOR="#1E1E2E"

# 設定ファイルの読み込み
if [ -f "$WALL_CONF" ]; then
    . "$WALL_CONF"
fi

# ==========================================
# apply モード: i3起動時・再読み込み時に壁紙を適用
# ==========================================
apply_wallpaper() {
    # 1. デスクトップ壁紙の適用 (feh)
    if [ -n "$WALLPAPER_PATH" ] && [ -f "$WALLPAPER_PATH" ]; then
        if command -v feh &>/dev/null && [ -n "$DISPLAY" ]; then
            feh --bg-fill "$WALLPAPER_PATH" 2>/dev/null || true
        fi
    elif [ -n "$BG_COLOR" ]; then
        if command -v xsetroot &>/dev/null && [ -n "$DISPLAY" ]; then
            xsetroot -solid "$BG_COLOR" 2>/dev/null || true
        fi
    fi

    # 2. ロック画面用画像の生成 (存在しない場合)
    if [ ! -f "$LOCK_IMG" ] && [ -f "$HELPER_PY" ]; then
        python3 "$HELPER_PY" "$WALLPAPER_PATH" "$LOCK_IMG" "$LOCK_STYLE" "$BG_COLOR" >/dev/null 2>&1 || true
    fi
}

if [ "$1" = "apply" ]; then
    apply_wallpaper
    exit 0
fi

# 非対話環境(端末なし)で呼ばれた場合はターミナルを起動
if [ ! -t 1 ] && [ -n "$DISPLAY" ]; then
    if command -v i3-sensible-terminal &>/dev/null; then
        exec i3-sensible-terminal -e "$0"
    elif command -v x-terminal-emulator &>/dev/null; then
        exec x-terminal-emulator -e "$0"
    fi
fi

save_config() {
    mkdir -p "$CONF_DIR"
    cat <<EOF > "$WALL_CONF"
# i3wm Wallpaper & Lockscreen Configuration
WALLPAPER_PATH="$WALLPAPER_PATH"
LOCK_STYLE="$LOCK_STYLE"
BG_COLOR="$BG_COLOR"
EOF

    # デスクトップ壁紙の即時反映
    if [ -f "$WALLPAPER_PATH" ]; then
        feh --bg-fill "$WALLPAPER_PATH" 2>/dev/null || true
    fi

    # ロック画面画像の再生成
    if [ -f "$HELPER_PY" ]; then
        python3 "$HELPER_PY" "$WALLPAPER_PATH" "$LOCK_IMG" "$LOCK_STYLE" "$BG_COLOR" >/dev/null 2>&1 || true
    fi

    if command -v notify-send &>/dev/null && [ -n "$DISPLAY" ]; then
        notify-send "🖼️ 壁紙・ロック画面設定" "新しい壁紙とロック画面を適用しました"
    fi
}

# ==========================================
# ncurses (dialog) メニュー実装
# ==========================================

menu_mint_wallpapers() {
    local bg_dirs=("/usr/share/backgrounds/linuxmint" "/usr/share/backgrounds/linuxmint-wallpapers")
    local items=()
    local i=1

    for d in "${bg_dirs[@]}"; do
        if [ -d "$d" ]; then
            for img in "$d"/*.jpg "$d"/*.png; do
                if [ -f "$img" ]; then
                    local base=$(basename "$img")
                    items+=("$img" "$base")
                fi
            done
        fi
    done

    if [ ${#items[@]} -eq 0 ]; then
        dialog --title "情報" --msgbox "システム壁紙が見つかりませんでした。" 7 40
        return
    fi

    local chosen
    chosen=$(dialog --clear \
        --backtitle "i3wm Wallpaper & Lockscreen Manager" \
        --title "🖼️ Linux Mint 公式壁紙一覧" \
        --menu "使用したい壁紙を選択してください:" 20 70 12 \
        "${items[@]}" \
        2>&1 >/dev/tty)

    if [ $? -eq 0 ] && [ -n "$chosen" ]; then
        WALLPAPER_PATH="$chosen"
        save_config
        dialog --title "完了" --msgbox "✅ 壁紙とロック画面を適用しました！\n\n選択: $(basename "$chosen")" 8 55
    fi
}

menu_custom_file() {
    local start_dir="$HOME/Pictures"
    [ ! -d "$start_dir" ] && start_dir="$HOME"

    local chosen
    chosen=$(dialog --clear \
        --backtitle "i3wm Wallpaper & Lockscreen Manager" \
        --title "📁 画像ファイルを選択" \
        --fselect "$start_dir/" 15 65 \
        2>&1 >/dev/tty)

    if [ $? -eq 0 ] && [ -f "$chosen" ]; then
        WALLPAPER_PATH="$chosen"
        save_config
        dialog --title "完了" --msgbox "✅ 壁紙とロック画面を適用しました！\n\n選択: $(basename "$chosen")" 8 55
    fi
}

menu_colors() {
    local colors=(
        "#1E1E2E" "Catppuccin Mocha (ダークネイビー)"
        "#2E3440" "Nord (北欧風ダークグレー)"
        "#000000" "OLED Black (純黒)"
        "#181825" "Catppuccin Mantle (ディープグレー)"
        "#282A36" "Dracula (ドラキュラダーク)"
        "#1A1B26" "Tokyo Night (東京ナイト)"
    )

    local chosen
    chosen=$(dialog --clear \
        --backtitle "i3wm Wallpaper & Lockscreen Manager" \
        --title "🎨 単色カラー背景" \
        --menu "背景色を選択してください:" 16 60 8 \
        "${colors[@]}" \
        2>&1 >/dev/tty)

    if [ $? -eq 0 ] && [ -n "$chosen" ]; then
        BG_COLOR="$chosen"
        WALLPAPER_PATH=""
        save_config
        xsetroot -solid "$BG_COLOR" 2>/dev/null || true
        dialog --title "完了" --msgbox "✅ 単色背景 ($BG_COLOR) を適用しました！" 7 45
    fi
}

menu_lock_style() {
    local styles=(
        "blur"     "ぼかし加工 (Blur) - 視認性が高くおすすめ"
        "original" "元画像をそのまま表示"
        "color"    "単色背景で表示"
    )

    local chosen
    chosen=$(dialog --clear \
        --backtitle "i3wm Wallpaper & Lockscreen Manager" \
        --title "🔒 ロック画面のスタイル設定" \
        --menu "ロック画面の効果を選択してください (現在: $LOCK_STYLE):" 14 65 5 \
        "${styles[@]}" \
        2>&1 >/dev/tty)

    if [ $? -eq 0 ] && [ -n "$chosen" ]; then
        LOCK_STYLE="$chosen"
        save_config
        dialog --title "完了" --msgbox "✅ ロック画面スタイルを '$LOCK_STYLE' に変更しました！" 7 50
    fi
}

main_menu() {
    while true; do
        local cur_wall="未設定 (単色: $BG_COLOR)"
        if [ -n "$WALLPAPER_PATH" ] && [ -f "$WALLPAPER_PATH" ]; then
            cur_wall="$(basename "$WALLPAPER_PATH")"
        fi

        local choice
        choice=$(dialog --clear \
            --backtitle "i3wm Wallpaper & Lockscreen Manager" \
            --title "🖼️ デスクトップ壁紙 & ロック画面マネージャー" \
            --menu "現在の壁紙: $cur_wall\nロック効果: $LOCK_STYLE\n\n設定項目を選択してください:" 18 68 7 \
            "1" "🖼️ Linux Mint 公式壁紙から選ぶ" \
            "2" "📁 画像ファイルを選択する (ファイルブラウザ)" \
            "3" "🎨 単色カラー背景を設定する" \
            "4" "🔒 ロック画面スタイル変更 (ぼかし / 原寸 / 単色)" \
            "5" "🔄 現在の設定を再適用する" \
            "0" "🚪 終了" \
            2>&1 >/dev/tty)

        case "$choice" in
            1) menu_mint_wallpapers ;;
            2) menu_custom_file ;;
            3) menu_colors ;;
            4) menu_lock_style ;;
            5)
                save_config
                dialog --title "適用完了" --msgbox "現在の壁紙設定を再適用しました！" 7 45
                ;;
            0|"") break ;;
        esac
    done
    clear
}

# dialog コマンドが存在する場合は ncurses メニューを起動
if command -v dialog &>/dev/null; then
    main_menu
else
    # dialog がない場合の CLI フォールバック
    echo "======================================"
    echo " 🖼️ 壁紙 & ロック画面設定 (CLI)"
    echo "======================================"
    echo "1) デフォルト壁紙を適用"
    echo "2) ロック画面を再生成"
    echo "0) 終了"
    read -p "選択 (0-2): " c
    case "$c" in
        1) WALLPAPER_PATH="$DEFAULT_WALLPAPER"; save_config ;;
        2) save_config ;;
    esac
fi
