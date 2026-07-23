#!/bin/bash

# ==========================================
# i3wm キーボードレイアウト & キー割り当て設定ツール
# Cinnamon環境のようなキーカスタマイズをGUI/CLIで簡単に提供します
# ==========================================

CONF_FILE="$HOME/.config/i3/keyboard.conf"

# 引数が "apply" の場合は保存された設定を適用する（i3起動時・再読み込み時用）
if [ "$1" = "apply" ]; then
    if [ -f "$CONF_FILE" ]; then
        source "$CONF_FILE"
        if [ -n "$XKB_CMD" ]; then
            eval "$XKB_CMD"
        fi
    fi
    exit 0
fi

# 設定適用と保存
apply_setting() {
    local cmd="$1"
    local desc="$2"
    
    eval "$cmd"
    
    mkdir -p "$HOME/.config/i3"
    cat <<EOF > "$CONF_FILE"
# i3wm Keyboard Configuration
XKB_CMD="$cmd"
EOF

    if command -v notify-send &> /dev/null && [ -n "$DISPLAY" ]; then
        notify-send "⌨️ キーボード設定" "$desc を適用しました"
    else
        echo "✅ $desc を適用しました"
    fi
}

case "$1" in
    swapcaps)
        apply_setting "setxkbmap -option ctrl:swapcaps" "Ctrl と Caps Lock の入れ替え"
        exit 0
        ;;
    nocaps)
        apply_setting "setxkbmap -option ctrl:nocaps" "Caps Lock の Ctrl 化"
        exit 0
        ;;
    jp)
        apply_setting "setxkbmap -layout jp -option ctrl:swapcaps" "日本語配列 (jp) + Ctrl/Caps入れ替え"
        exit 0
        ;;
    us)
        apply_setting "setxkbmap -layout us -option ctrl:swapcaps" "英語配列 (us) + Ctrl/Caps入れ替え"
        exit 0
        ;;
    reset)
        apply_setting "setxkbmap -option" "キーボード設定の初期化"
        exit 0
        ;;
esac

# GUI / Rofi メニュー表示
if command -v rofi &> /dev/null && [ -n "$DISPLAY" ]; then
    CHOICE=$(echo -e "🔄 Ctrl と Caps Lock を入れ替える (ctrl:swapcaps)\n🔤 Caps Lock を Ctrl キーに変更する (ctrl:nocaps)\n🇯🇵 日本語配列 (jp) + Ctrl/Caps入れ替え\n🇺🇸 英語配列 (us) + Ctrl/Caps入れ替え\n↺ デフォルト状態にリセット" | rofi -dmenu -i -p "⌨️ キーボード設定")
    
    case "$CHOICE" in
        *"Ctrl と Caps Lock を入れ替える"*)
            apply_setting "setxkbmap -option ctrl:swapcaps" "Ctrl と Caps Lock の入れ替え"
            ;;
        *"Caps Lock を Ctrl キーに変更する"*)
            apply_setting "setxkbmap -option ctrl:nocaps" "Caps Lock の Ctrl 化"
            ;;
        *"日本語配列"*)
            apply_setting "setxkbmap -layout jp -option ctrl:swapcaps" "日本語配列 (jp) + Ctrl/Caps入れ替え"
            ;;
        *"英語配列"*)
            apply_setting "setxkbmap -layout us -option ctrl:swapcaps" "英語配列 (us) + Ctrl/Caps入れ替え"
            ;;
        *"デフォルト状態にリセット"*)
            apply_setting "setxkbmap -option" "キーボード設定の初期化"
            ;;
    esac
elif [ ! -t 0 ] && [ -n "$DISPLAY" ]; then
    # rofi がなく GUI ショートカットから端末なしで起動された場合、ターミナルを開く
    if command -v i3-sensible-terminal &> /dev/null; then
        exec i3-sensible-terminal -e "$0"
    elif command -v x-terminal-emulator &> /dev/null; then
        exec x-terminal-emulator -e "$0"
    fi
else
    echo "⌨️ i3wm キーボード設定ツール"
    echo "----------------------------"
    echo "1) Ctrl と Caps Lock を入れ替える (ctrl:swapcaps)"
    echo "2) Caps Lock を Ctrl キーに変更する (ctrl:nocaps)"
    echo "3) 日本語配列 (jp) + Ctrl/Caps入れ替え"
    echo "4) 英語配列 (us) + Ctrl/Caps入れ替え"
    echo "5) デフォルトにリセット"
    read -p "選択してください [1-5]: " num
    case "$num" in
        1) apply_setting "setxkbmap -option ctrl:swapcaps" "Ctrl と Caps Lock の入れ替え" ;;
        2) apply_setting "setxkbmap -option ctrl:nocaps" "Caps Lock の Ctrl 化" ;;
        3) apply_setting "setxkbmap -layout jp -option ctrl:swapcaps" "日本語配列 (jp) + Ctrl/Caps入れ替え" ;;
        4) apply_setting "setxkbmap -layout us -option ctrl:swapcaps" "英語配列 (us) + Ctrl/Caps入れ替え" ;;
        5) apply_setting "setxkbmap -option" "キーボード設定の初期化" ;;
    esac
fi
