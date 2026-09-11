#!/bin/bash

# ==========================================
# システム電源操作メニュー
# rofi を使用してスリープ、再起動、終了等のメニューを表示します
# ==========================================

options="⏻ シャットダウン (Poweroff)\n🔄 再起動 (Reboot)\n🌙 スリープ (Suspend)\n❄️ 休止状態 (Hibernate)\n🚪 ログアウト (Logout)"

# rofi がインストールされている場合は GUI メニューを表示
if command -v rofi &>/dev/null && [ -n "$DISPLAY" ]; then
    chosen=$(echo -e "$options" | rofi -dmenu -i -p "電源操作" -lines 5 -width 20 -padding 20)
else
    # ターミナル等からの直接実行時のフォールバック
    echo "1) ⏻ シャットダウン"
    echo "2) 🔄 再起動"
    echo "3) 🌙 スリープ"
    echo "4) ❄️ 休止状態"
    echo "5) 🚪 ログアウト"
    read -p "番号を入力 (1-5): " choice
    case "$choice" in
        1) chosen="Poweroff" ;;
        2) chosen="Reboot" ;;
        3) chosen="Suspend" ;;
        4) chosen="Hibernate" ;;
        5) chosen="Logout" ;;
    esac
fi

if [[ "$chosen" == *"Poweroff"* ]]; then
    systemctl poweroff
elif [[ "$chosen" == *"Reboot"* ]]; then
    systemctl reboot
elif [[ "$chosen" == *"Suspend"* ]]; then
    systemctl suspend
elif [[ "$chosen" == *"Hibernate"* ]]; then
    systemctl hibernate
elif [[ "$chosen" == *"Logout"* ]]; then
    i3-msg exit
fi
