#!/bin/bash

# ==========================================
# i3wm メディアキー & OSD 通知コントロール
# 音量・輝度の変更時に画面へ視覚的フィードバック(OSD)を表示します
# ==========================================

get_volume() {
    LC_ALL=C pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | grep -Po '[0-9]+(?=%)' | head -n 1
}

is_muted() {
    LC_ALL=C pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | grep -i "yes"
}

make_bar() {
    local val=$1
    [ -z "$val" ] && val=0
    local num_bars=$((val / 10))
    local bar=""
    for ((i=0; i<10; i++)); do
        if [ $i -lt $num_bars ]; then
            bar="${bar}█"
        else
            bar="${bar}░"
        fi
    done
    echo "$bar"
}

notify_osd() {
    local tag="$1"
    local title="$2"
    local percent="$3"
    
    if command -v notify-send &> /dev/null && [ -n "$DISPLAY" ]; then
        if [ -n "$percent" ]; then
            local bar=$(make_bar "$percent")
            notify-send -h "string:x-dunst-stack-tag:${tag}" -h "int:value:${percent}" -t 1200 "${title}" "${bar}  ${percent}%"
        else
            notify-send -h "string:x-dunst-stack-tag:${tag}" -t 1200 "${title}"
        fi
    fi
}

adjust_brightness() {
    local dir="$1" # "up" or "down"
    
    # 1. まず brightnessctl (ハードウェア輝度) を試す
    if command -v brightnessctl &>/dev/null; then
        local err
        if [ "$dir" = "up" ]; then
            err=$(brightnessctl set +5% 2>&1)
        else
            err=$(brightnessctl set 5%- 2>&1)
        fi
        local ret=$?
        
        if [ $ret -eq 0 ] && [[ "$err" != *"Permission denied"* ]]; then
            BRIGHT=$(brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d '%')
            notify_osd "brightness" "☀️ 明るさ" "$BRIGHT"
            return 0
        fi
    fi
    
    # 2. brightnessctl が権限エラー等で失敗した場合、xrandr (ソフトウェア輝度) に自動フォールバック
    local STATE_FILE="$HOME/.config/i3/.brightness_val"
    local CURR=100
    if [ -f "$STATE_FILE" ]; then
        CURR=$(cat "$STATE_FILE")
    fi
    
    if [ "$dir" = "up" ]; then
        CURR=$((CURR + 5))
        [ $CURR -gt 100 ] && CURR=100
    else
        CURR=$((CURR - 5))
        [ $CURR -lt 10 ] && CURR=10
    fi
    
    echo "$CURR" > "$STATE_FILE"
    
    local FLOAT_VAL=$(awk "BEGIN {printf \"%.2f\", $CURR / 100}")
    local DISP=$(xrandr 2>/dev/null | grep -w "connected" | cut -d' ' -f1 | head -n 1)
    
    if [ -n "$DISP" ]; then
        xrandr --output "$DISP" --brightness "$FLOAT_VAL" 2>/dev/null || true
        notify_osd "brightness" "☀️ 明るさ" "$CURR"
    fi
}

case "$1" in
    vol-up)
        LC_ALL=C pactl set-sink-volume @DEFAULT_SINK@ +5% 2>/dev/null || true
        LC_ALL=C pactl set-sink-mute @DEFAULT_SINK@ 0 2>/dev/null || true
        VOL=$(get_volume)
        notify_osd "volume" "🔊 音量" "$VOL"
        ;;
    vol-down)
        LC_ALL=C pactl set-sink-volume @DEFAULT_SINK@ -5% 2>/dev/null || true
        VOL=$(get_volume)
        notify_osd "volume" "🔉 音量" "$VOL"
        ;;
    vol-mute)
        LC_ALL=C pactl set-sink-mute @DEFAULT_SINK@ toggle 2>/dev/null || true
        if [ -n "$(is_muted)" ]; then
            notify_osd "volume" "🔇 ミュート (消音)" ""
        else
            VOL=$(get_volume)
            notify_osd "volume" "🔊 ミュート解除" "$VOL"
        fi
        ;;
    bright-up)
        adjust_brightness "up"
        ;;
    bright-down)
        adjust_brightness "down"
        ;;
    *)
        echo "Usage: $0 {vol-up|vol-down|vol-mute|bright-up|bright-down}"
        exit 1
        ;;
esac
