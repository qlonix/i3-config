#!/bin/bash

# ==========================================
# システム電源操作メニュー
# rofi を使用してスリープ、再起動、終了等のメニューを表示します
# ==========================================

options="🔒 画面ロック (Lock)\n🚀 自動起動アプリ設定 (Autostart)\n⏻ シャットダウン (Poweroff)\n🔄 再起動 (Reboot)\n🌙 スリープ (Suspend)\n❄️ 休止状態 (Hibernate)\n🚪 ログアウト (Logout)"

# rofi がインストールされている場合は GUI メニューを表示
if command -v rofi &>/dev/null && [ -n "$DISPLAY" ]; then
    chosen=$(echo -e "$options" | rofi -dmenu -i -p "電源・システム操作" -lines 7 -width 25 -padding 20)
else
    # ターミナル等からの直接実行時のフォールバック
    echo "1) 🔒 画面ロック"
    echo "2) 🚀 自動起動アプリ設定"
    echo "3) ⏻ シャットダウン"
    echo "4) 🔄 再起動"
    echo "5) 🌙 スリープ"
    echo "6) ❄️ 休止状態"
    echo "7) 🚪 ログアウト"
    read -p "番号を入力 (1-7): " choice
    case "$choice" in
        1) chosen="Lock" ;;
        2) chosen="Autostart" ;;
        3) chosen="Poweroff" ;;
        4) chosen="Reboot" ;;
        5) chosen="Suspend" ;;
        6) chosen="Hibernate" ;;
        7) chosen="Logout" ;;
    esac
fi

# 電源設定の読み込み
SLEEP_CMD="systemctl suspend"
if [ -f "$HOME/.config/i3/power.conf" ]; then
    . "$HOME/.config/i3/power.conf"
    if [ "$SLEEP_MODE" = "hybrid-suspend" ]; then
        SLEEP_CMD="systemctl hybrid-suspend"
    elif [ "$SLEEP_MODE" = "suspend-then-hibernate" ]; then
        SLEEP_CMD="systemctl suspend-then-hibernate"
    fi
fi

if [[ "$chosen" == *"Lock"* ]]; then
    if [ -x "$HOME/.config/i3/i3-lock.sh" ]; then
        "$HOME/.config/i3/i3-lock.sh"
    else
        loginctl lock-session
    fi
elif [[ "$chosen" == *"Autostart"* ]]; then
    if [ -x "$HOME/.config/i3/i3-autostart.sh" ]; then
        i3-sensible-terminal -e "$HOME/.config/i3/i3-autostart.sh"
    fi
elif [[ "$chosen" == *"Poweroff"* ]]; then
    systemctl poweroff
elif [[ "$chosen" == *"Reboot"* ]]; then
    systemctl reboot
elif [[ "$chosen" == *"Suspend"* ]]; then
    eval "$SLEEP_CMD"
elif [[ "$chosen" == *"Hibernate"* ]]; then
    systemctl hibernate
elif [[ "$chosen" == *"Logout"* ]]; then
    i3-msg exit
fi
