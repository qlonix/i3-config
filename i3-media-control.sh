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

# 最適なバックライトデバイスを自動検出 (VAIO Pro 等で acpi_video0 ではなく intel_backlight を優先)
get_best_backlight_device() {
    if [ -d /sys/class/backlight ]; then
        # 1. GPUネイティブドライバを最優先 (Intel, AMD, NVIDIA, Poulsbo/VAIO X)
        for dev in intel_backlight amdgpu_bl0 amdgpu_bl1 psb-bl; do
            if [ -d "/sys/class/backlight/$dev" ]; then
                echo "$dev"
                return 0
            fi
        done
        
        # 2. type が native のデバイスを検索
        for p in /sys/class/backlight/*; do
            if [ -f "$p/type" ] && [ "$(cat "$p/type" 2>/dev/null)" = "native" ]; then
                basename "$p"
                return 0
            fi
        done
        
        # 3. その他存在するバックライトデバイス (acpi_video等)
        for p in /sys/class/backlight/*; do
            if [ -d "$p" ]; then
                basename "$p"
                return 0
            fi
        done
    fi
    echo ""
}

adjust_brightness() {
    local dir="$1" # "up", "down", or "max"
    local dev
    dev=$(get_best_backlight_device)
    local dev_args=()
    [ -n "$dev" ] && dev_args=(-d "$dev")
    
    # 1. まず brightnessctl (ハードウェア輝度) を試す
    if command -v brightnessctl &>/dev/null; then
        local err
        if [ "$dir" = "up" ]; then
            err=$(brightnessctl "${dev_args[@]}" set +5% 2>&1)
        elif [ "$dir" = "down" ]; then
            err=$(brightnessctl "${dev_args[@]}" set 5%- -n 1 2>&1)
        elif [ "$dir" = "max" ]; then
            err=$(brightnessctl "${dev_args[@]}" set 100% 2>&1)
        fi
        local ret=$?
        
        if [ $ret -eq 0 ] && [[ "$err" != *"Permission denied"* ]]; then
            # 過去に xrandr ソフトウェア輝度で減光されていた場合はリセット (1.0)
            local STATE_FILE="$HOME/.config/i3/.brightness_val"
            if [ -f "$STATE_FILE" ]; then
                rm -f "$STATE_FILE"
                for d in $(xrandr 2>/dev/null | grep -w "connected" | cut -d' ' -f1); do
                    xrandr --output "$d" --brightness 1.0 2>/dev/null || true
                done
            fi
            
            BRIGHT=$(brightnessctl "${dev_args[@]}" -m 2>/dev/null | cut -d, -f4 | tr -d '%')
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
    elif [ "$dir" = "down" ]; then
        CURR=$((CURR - 5))
        [ $CURR -lt 10 ] && CURR=10
    elif [ "$dir" = "max" ]; then
        CURR=100
    fi
    
    echo "$CURR" > "$STATE_FILE"
    
    local FLOAT_VAL=$(awk "BEGIN {printf \"%.2f\", $CURR / 100}")
    local DISP=$(xrandr 2>/dev/null | grep -w "connected" | cut -d' ' -f1 | head -n 1)
    
    if [ -n "$DISP" ]; then
        xrandr --output "$DISP" --brightness "$FLOAT_VAL" 2>/dev/null || true
        notify_osd "brightness" "☀️ 明るさ" "$CURR"
    fi
}

show_brightness_status() {
    echo "=== 画面輝度ステータス診断 ==="
    echo "利用可能なバックライトデバイス (/sys/class/backlight):"
    if [ -d /sys/class/backlight ]; then
        for p in /sys/class/backlight/*; do
            if [ -d "$p" ]; then
                local bname=$(basename "$p")
                local cur=$(cat "$p/brightness" 2>/dev/null)
                local max=$(cat "$p/max_brightness" 2>/dev/null)
                local type=$(cat "$p/type" 2>/dev/null)
                local pct=0
                [ -n "$max" ] && [ "$max" -gt 0 ] 2>/dev/null && pct=$(( cur * 100 / max ))
                echo "  - $bname (type: $type): $cur / $max (${pct}%)"
            fi
        done
    else
        echo "  (見つかりません)"
    fi
    
    local best=$(get_best_backlight_device)
    echo "優先選択デバイス: ${best:-なし (xrandr fallback)}"
    
    if command -v xrandr &>/dev/null && [ -n "$DISPLAY" ]; then
        echo "接続ディスプレイ:"
        xrandr --verbose 2>/dev/null | grep -E "connected|Brightness:" | while read -r line; do
            echo "  $line"
        done
    fi
    echo "=============================="
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
    bright-max)
        adjust_brightness "max"
        ;;
    bright-status)
        show_brightness_status
        ;;
    *)
        echo "Usage: $0 {vol-up|vol-down|vol-mute|bright-up|bright-down|bright-max|bright-status}"
        exit 1
        ;;
esac
