#!/bin/bash

# ==========================================
# i3wm メディアキー & OSD 通知コントロール
# 音量・輝度の変更時に画面へ視覚的フィードバック(OSD)を表示します
# ==========================================

get_volume() {
    pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | grep -Po '[0-9]+(?=%)' | head -n 1
}

is_muted() {
    pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | grep -i "yes"
}

get_brightness() {
    if command -v brightnessctl &>/dev/null; then
        brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d '%'
    else
        echo ""
    fi
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

case "$1" in
    vol-up)
        pactl set-sink-volume @DEFAULT_SINK@ +5% 2>/dev/null || true
        pactl set-sink-mute @DEFAULT_SINK@ 0 2>/dev/null || true
        VOL=$(get_volume)
        notify_osd "volume" "🔊 音量" "$VOL"
        ;;
    vol-down)
        pactl set-sink-volume @DEFAULT_SINK@ -5% 2>/dev/null || true
        VOL=$(get_volume)
        notify_osd "volume" "🔉 音量" "$VOL"
        ;;
    vol-mute)
        pactl set-sink-mute @DEFAULT_SINK@ toggle 2>/dev/null || true
        if [ -n "$(is_muted)" ]; then
            notify_osd "volume" "🔇 ミュート (消音)" ""
        else
            VOL=$(get_volume)
            notify_osd "volume" "🔊 ミュート解除" "$VOL"
        fi
        ;;
    bright-up)
        if command -v brightnessctl &>/dev/null; then
            brightnessctl set +5% 2>/dev/null || true
            BRIGHT=$(get_brightness)
            notify_osd "brightness" "☀️ 明るさ" "$BRIGHT"
        fi
        ;;
    bright-down)
        if command -v brightnessctl &>/dev/null; then
            brightnessctl set 5%- 2>/dev/null || true
            BRIGHT=$(get_brightness)
            notify_osd "brightness" "🔆 明るさ" "$BRIGHT"
        fi
        ;;
    *)
        echo "Usage: $0 {vol-up|vol-down|vol-mute|bright-up|bright-down}"
        exit 1
        ;;
esac
