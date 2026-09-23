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

BOOST_FILE="$HOME/.config/i3/.brightness_boost"

get_boost() {
    if [ -f "$BOOST_FILE" ]; then
        local val
        val=$(cat "$BOOST_FILE" 2>/dev/null)
        if [[ "$val" =~ ^[0-9]+$ ]] && [ "$val" -ge 100 ] && [ "$val" -le 130 ]; then
            echo "$val"
            return 0
        fi
    fi
    echo 100
}

set_xrandr_brightness() {
    local val_pct=$1
    local float_val
    float_val=$(awk "BEGIN {printf \"%.2f\", $val_pct / 100}")
    
    if command -v xrandr &>/dev/null && [ -n "$DISPLAY" ]; then
        for d in $(xrandr --current 2>/dev/null | grep -w "connected" | cut -d' ' -f1); do
            # フルカラーレンジ (0-255) を強制適用 (Intel GPUのLimited RGBによる白くすみ・減光を防止)
            xrandr --output "$d" --set "Broadcast RGB" "Full" 2>/dev/null || true
            xrandr --output "$d" --brightness "$float_val" 2>/dev/null || true
        done
    fi
}

adjust_brightness() {
    local dir="$1" # "up", "down", "max", or "boost"
    local dev
    dev=$(get_best_backlight_device)
    local dev_args=()
    [ -n "$dev" ] && dev_args=(-d "$dev")
    
    local hw_success=0
    local new_pct=""
    
    # 1. まず brightnessctl (ハードウェア輝度) を試す
    if command -v brightnessctl &>/dev/null; then
        local current_pct
        current_pct=$(brightnessctl "${dev_args[@]}" -m 2>/dev/null | head -n 1 | cut -d, -f4 | tr -d '%')
        
        if [[ "$current_pct" =~ ^[0-9]+$ ]]; then
            local current_boost
            current_boost=$(get_boost)
            
            if [ "$dir" = "up" ]; then
                if [ "$current_pct" -ge 100 ]; then
                    # ハードウェアがすでに100%の場合、ソフトウェアブースト (最大130%)
                    local new_boost=$((current_boost + 5))
                    [ $new_boost -gt 130 ] && new_boost=130
                    echo "$new_boost" > "$BOOST_FILE"
                    set_xrandr_brightness "$new_boost"
                    notify_osd "brightness" "🚀 明るさ (ブースト)" "$new_boost"
                    return 0
                else
                    local err
                    err=$(brightnessctl "${dev_args[@]}" set +5% 2>&1)
                    local ret=$?
                    if [ $ret -eq 0 ] && [[ "$err" != *"Permission denied"* ]] && [[ "$err" != *"failed"* ]]; then
                        hw_success=1
                        if [ "$current_boost" -ne 100 ]; then
                            rm -f "$BOOST_FILE"
                            set_xrandr_brightness 100
                        fi
                        new_pct=$(brightnessctl "${dev_args[@]}" -m 2>/dev/null | head -n 1 | cut -d, -f4 | tr -d '%')
                    fi
                fi
            elif [ "$dir" = "down" ]; then
                if [ "$current_boost" -gt 100 ]; then
                    local new_boost=$((current_boost - 5))
                    if [ $new_boost -le 100 ]; then
                        rm -f "$BOOST_FILE"
                        set_xrandr_brightness 100
                        notify_osd "brightness" "☀️ 明るさ" "100"
                    else
                        echo "$new_boost" > "$BOOST_FILE"
                        set_xrandr_brightness "$new_boost"
                        notify_osd "brightness" "🚀 明るさ (ブースト)" "$new_boost"
                    fi
                    return 0
                else
                    local err
                    if [ "$current_pct" -le 5 ]; then
                        err=$(brightnessctl "${dev_args[@]}" set 2% 2>&1)
                    else
                        err=$(brightnessctl "${dev_args[@]}" set 5%- 2>&1)
                    fi
                    local ret=$?
                    if [ $ret -eq 0 ] && [[ "$err" != *"Permission denied"* ]] && [[ "$err" != *"failed"* ]]; then
                        hw_success=1
                        new_pct=$(brightnessctl "${dev_args[@]}" -m 2>/dev/null | head -n 1 | cut -d, -f4 | tr -d '%')
                    fi
                fi
            elif [ "$dir" = "max" ]; then
                local err
                err=$(brightnessctl "${dev_args[@]}" set 100% 2>&1)
                local ret=$?
                if [ $ret -eq 0 ] && [[ "$err" != *"Permission denied"* ]] && [[ "$err" != *"failed"* ]]; then
                    hw_success=1
                    rm -f "$BOOST_FILE"
                    set_xrandr_brightness 100
                    notify_osd "brightness" "☀️ 明るさ (最大)" "100"
                    return 0
                fi
            elif [ "$dir" = "boost" ]; then
                local err
                err=$(brightnessctl "${dev_args[@]}" set 100% 2>&1)
                local ret=$?
                if [ $ret -eq 0 ] && [[ "$err" != *"Permission denied"* ]] && [[ "$err" != *"failed"* ]]; then
                    echo "120" > "$BOOST_FILE"
                    set_xrandr_brightness 120
                    notify_osd "brightness" "🚀 明るさ (120% ブースト)" "120"
                    return 0
                fi
            fi
            
            # ハードウェア輝度操作が正常終了した場合
            if [ $hw_success -eq 1 ]; then
                [ -z "$new_pct" ] && new_pct="$current_pct"
                notify_osd "brightness" "☀️ 明るさ" "$new_pct"
                return 0
            fi
        fi
    fi
    
    # 2. brightnessctl が存在しない、または権限エラー等で失敗した場合、xrandr (ソフトウェア輝度) に自動フォールバック
    local STATE_FILE="$HOME/.config/i3/.brightness_val"
    local CURR=100
    if [ -f "$STATE_FILE" ]; then
        CURR=$(cat "$STATE_FILE" 2>/dev/null)
    elif [[ "$current_pct" =~ ^[0-9]+$ ]]; then
        CURR="$current_pct"
    fi
    if ! [[ "$CURR" =~ ^[0-9]+$ ]]; then
        CURR=100
    fi
    
    if [ "$dir" = "up" ]; then
        CURR=$((CURR + 5))
        [ $CURR -gt 130 ] && CURR=130
    elif [ "$dir" = "down" ]; then
        CURR=$((CURR - 5))
        [ $CURR -lt 10 ] && CURR=10
    elif [ "$dir" = "max" ]; then
        CURR=100
    elif [ "$dir" = "boost" ]; then
        CURR=120
    fi
    
    echo "$CURR" > "$STATE_FILE"
    set_xrandr_brightness "$CURR"
    if [ "$CURR" -gt 100 ]; then
        notify_osd "brightness" "🚀 明るさ (ブースト)" "$CURR"
    else
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
    
    local dev=$(get_best_backlight_device)
    echo "優先選択デバイス: ${dev:-なし (xrandr fallback)}"
    
    if command -v brightnessctl &>/dev/null; then
        local dev_args=()
        [ -n "$dev" ] && dev_args=(-d "$dev")
        local test_err
        test_err=$(brightnessctl "${dev_args[@]}" set +0% 2>&1)
        local test_ret=$?
        if [ $test_ret -eq 0 ] && [[ "$test_err" != *"Permission denied"* ]] && [[ "$test_err" != *"failed"* ]]; then
            echo "brightnessctl 権限: ✅ 正常 (ハードウェア直接制御可能)"
        else
            echo "brightnessctl 権限: ⚠️ 権限不足 (Permission denied 等)"
            echo "  -> xrandr ソフトウェア制御に自動フォールバックして動作します"
            echo "  -> 一般ユーザーでハードウェア制御を許可する場合:"
            echo "     sudo usermod -aG video \$USER (再ログイン後に有効)"
        fi
    else
        echo "brightnessctl: ⚠️ 未インストール (xrandr ソフトウェア制御で動作)"
    fi
    
    local boost=$(get_boost)
    echo "ソフトウェアブースト状態: ${boost}%"
    
    if command -v xrandr &>/dev/null && [ -n "$DISPLAY" ]; then
        echo ""
        echo "接続ディスプレイとカラーレンジ設定 (xrandr):"
        xrandr --verbose 2>/dev/null | grep -E "connected|Brightness:|Broadcast RGB:" | while read -r line; do
            echo "  $line"
        done
    fi
    
    echo ""
    echo "💡 ヒント:"
    echo "  - 画面を最大輝度 (100%) に設定: $0 bright-max"
    echo "  - 物理限界を超えて明るくする:   $0 bright-boost (120% ブースト)"
    echo "  - 100% 時にさらに Brightness Up を押すと最大130%までブーストされます"
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
    bright-boost)
        adjust_brightness "boost"
        ;;
    bright-status)
        show_brightness_status
        ;;
    *)
        echo "Usage: $0 {vol-up|vol-down|vol-mute|bright-up|bright-down|bright-max|bright-boost|bright-status}"
        exit 1
        ;;
esac
