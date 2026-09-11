#!/bin/bash

# ==========================================
# i3wm スクリーンショットラッパー
# 利用可能なスクリーンショットツールを自動判別して撮影します。
# 保存先: ~/Pictures/Screenshots
# ==========================================

SAVE_DIR="$HOME/Pictures/Screenshots"
mkdir -p "$SAVE_DIR"

FILENAME="$SAVE_DIR/$(date +%Y-%m-%d_%H-%M-%S)_screenshot.png"
MODE="${1:-full}"

take_screenshot() {
    # Flameshot (高機能、アノテーション可能)
    if command -v flameshot &>/dev/null; then
        if [ "$MODE" = "select" ]; then
            flameshot gui -p "$SAVE_DIR"
        else
            flameshot full -p "$SAVE_DIR"
        fi
        return $?
    fi

    # Scrot (シンプルで軽量、i3の定番)
    if command -v scrot &>/dev/null; then
        if [ "$MODE" = "select" ]; then
            scrot -s -f "$FILENAME"
        elif [ "$MODE" = "window" ]; then
            scrot -u -f "$FILENAME"
        else
            scrot "$FILENAME"
        fi
        return $?
    fi

    # maim (scrotのモダンな代替)
    if command -v maim &>/dev/null; then
        if [ "$MODE" = "select" ]; then
            maim -s "$FILENAME"
        elif [ "$MODE" = "window" ]; then
            maim -i $(xdotool getactivewindow) "$FILENAME"
        else
            maim "$FILENAME"
        fi
        return $?
    fi

    # GNOME Screenshot
    if command -v gnome-screenshot &>/dev/null; then
        if [ "$MODE" = "select" ]; then
            gnome-screenshot -a -f "$FILENAME"
        elif [ "$MODE" = "window" ]; then
            gnome-screenshot -w -f "$FILENAME"
        else
            gnome-screenshot -f "$FILENAME"
        fi
        return $?
    fi

    # ImageMagick (import)
    if command -v import &>/dev/null; then
        if [ "$MODE" = "select" ]; then
            import "$FILENAME"
        else
            import -window root "$FILENAME"
        fi
        return $?
    fi

    echo "Error: No screenshot tool found. (Please install scrot, flameshot, maim, or gnome-screenshot)"
    if command -v notify-send &>/dev/null; then
        notify-send -u critical "スクリーンショット失敗" "scrot や flameshot などの撮影ツールがインストールされていません。"
    fi
    return 1
}

# 撮影実行
if take_screenshot; then
    # 成功時の通知
    if command -v notify-send &>/dev/null; then
        # Flameshotは独自の通知があるのでスキップ
        if ! command -v flameshot &>/dev/null || [ "$MODE" != "select" ]; then
            notify-send -u normal -i "camera-photo" "スクリーンショット保存" "画像を保存しました:\nPictures/Screenshots/"
        fi
    fi
fi
