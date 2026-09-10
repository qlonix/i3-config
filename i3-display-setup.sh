#!/bin/bash

# ==========================================
# i3wm Display & Bar Optimization Setup
# 画面解像度に合わせて i3status の表示形式とウィンドウの隙間を最適化
# ==========================================

CONF_DIR="$HOME/.config/i3"
DISPLAY_CONF="$CONF_DIR/display.conf"

show_menu() {
    local screen_w
    screen_w=$(get_screen_width)
    
    local auto_target="標準 (Standard)"
    if [ "$screen_w" -lt 1400 ]; then
        auto_target="コンパクト (Compact)"
    fi

    local options="auto (自動: 現在は $auto_target)\nstandard (標準: 大画面向け)\ncompact (コンパクト: 省スペース画面向け)"
    
    local chosen
    if command -v rofi &>/dev/null && [ -n "$DISPLAY" ]; then
        chosen=$(echo -e "$options" | rofi -dmenu -i -p "表示モード選択" -lines 3)
    else
        echo "表示モードを選択してください:"
        echo "1) auto (自動: 現在は $auto_target)"
        echo "2) standard (標準: 大画面向け)"
        echo "3) compact (コンパクト: 省スペース画面向け)"
        read -p "番号を入力 (1-3): " choice
        case "$choice" in
            1) chosen="auto" ;;
            2) chosen="standard" ;;
            3) chosen="compact" ;;
        esac
    fi

    if [ -n "$chosen" ]; then
        local mode=$(echo "$chosen" | awk '{print $1}')
        apply_mode "$mode"
    fi
}

get_screen_width() {
    local w=1920
    if command -v xrandr &>/dev/null && [ -n "$DISPLAY" ]; then
        local res
        res=$(xrandr --current 2>/dev/null | grep -w connected | grep -o '[0-9]\+x[0-9]\+' | head -1 | cut -dx -f1)
        if [ -n "$res" ]; then
            w="$res"
        fi
    fi
    echo "$w"
}

apply_mode() {
    local mode="$1"
    local silent="$2"
    mkdir -p "$CONF_DIR"

    cat <<EOF > "$DISPLAY_CONF"
# i3wm Display Configuration
# Modes: auto, compact, standard
DISPLAY_MODE="$mode"
EOF

    local effective_mode="$mode"
    local screen_w
    screen_w=$(get_screen_width)

    if [ "$mode" = "auto" ]; then
        if [ "$screen_w" -lt 1400 ]; then
            effective_mode="compact"
        else
            effective_mode="standard"
        fi
    fi

    # モードに応じた i3status 設定ファイルの切替
    if [ "$effective_mode" = "compact" ] && [ -f "$CONF_DIR/i3status-compact.conf" ]; then
        ln -sf "$CONF_DIR/i3status-compact.conf" "$CONF_DIR/i3status-active.conf"
    else
        ln -sf "$CONF_DIR/i3status.conf" "$CONF_DIR/i3status-active.conf"
    fi

    # モードに応じたウィンドウ隙間 (Gaps) の動的最適化
    if command -v i3-msg &>/dev/null && [ -n "$DISPLAY" ]; then
        if [ "$effective_mode" = "compact" ]; then
            i3-msg -q "gaps inner all set 4; gaps outer all set 0" 2>/dev/null || true
        else
            i3-msg -q "gaps inner all set 8; gaps outer all set 2" 2>/dev/null || true
        fi
        
        # barの更新
        pkill -x i3status 2>/dev/null || true
    fi

    if [ "$silent" != "silent" ]; then
        local msg
        case "$mode" in
            auto) msg="画面解像度に合わせて自動最適化 (現在: ${screen_w}px幅 -> ${effective_mode})" ;;
            compact) msg="コンパクト表示 (VAIO X / 1366x768 等の小型画面向け)" ;;
            standard) msg="通常表示 (Full HD / 大画面向け)" ;;
        esac

        if command -v notify-send &>/dev/null && [ -n "$DISPLAY" ]; then
            notify-send -h "string:x-dunst-stack-tag:display" -t 2000 "🖥️ 画面表示の最適化" "$msg"
        else
            echo "画面表示モードを適用しました: $msg"
        fi
    fi
}

case "$1" in
    apply)
        MODE="auto"
        if [ -f "$DISPLAY_CONF" ]; then
            . "$DISPLAY_CONF" 2>/dev/null
            [ -n "$DISPLAY_MODE" ] && MODE="$DISPLAY_MODE"
        fi
        apply_mode "$MODE" "silent"
        ;;
    *)
        show_menu
        ;;
esac
