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

# 撮影前のファイル数を取得 (Flameshot等でファイル名が変わるツール用)
BEFORE_COUNT=$(find "$SAVE_DIR" -maxdepth 1 -name "*.png" 2>/dev/null | wc -l)

# 撮影実行
if take_screenshot; then
    # 撮影後のファイル数を取得
    AFTER_COUNT=$(find "$SAVE_DIR" -maxdepth 1 -name "*.png" 2>/dev/null | wc -l)
    
    # 保存されたファイルを特定
    LATEST_FILE=""
    if [ "$AFTER_COUNT" -gt "$BEFORE_COUNT" ]; then
        # 新しいファイルが生成された場合、一番新しいファイルを取得
        LATEST_FILE=$(ls -t "$SAVE_DIR"/*.png 2>/dev/null | head -n1)
    elif [ -f "$FILENAME" ]; then
        # 生成数は変わらないが指定したファイル名で上書き等された場合
        LATEST_FILE="$FILENAME"
    fi

    # クリップボードへのコピー
    CLIP_MSG=""
    if [ -n "$LATEST_FILE" ] && [ -f "$LATEST_FILE" ]; then
        if command -v xclip &>/dev/null; then
            xclip -selection clipboard -t image/png -i "$LATEST_FILE"
            CLIP_MSG=" (クリップボードにコピー済)"
        else
            CLIP_MSG="\n※xclipをインストールするとクリップボードにも自動コピーされます。"
        fi
    fi

    # 成功時の通知
    if command -v notify-send &>/dev/null; then
        # Flameshotは独自の通知がある場合があるが、クリップボード結果を含めて通知する
        notify-send -u normal -i "camera-photo" "スクリーンショット保存" "画像を保存しました:$CLIP_MSG\nPictures/Screenshots/"
    fi
fi
