#!/bin/bash
# ==========================================
# cinnamon-screensaver-command 互換ラッパースクリプト
# Linux Mint / Cinnamon 関連ツールからのロック要求を i3-lock.sh に転送します
# ==========================================

LOCK_SCRIPT="$HOME/.config/i3/i3-lock.sh"

for arg in "$@"; do
    if [ "$arg" = "-l" ] || [ "$arg" = "--lock" ]; then
        if [ -x "$LOCK_SCRIPT" ]; then
            exec "$LOCK_SCRIPT"
        elif command -v i3lock &>/dev/null; then
            exec i3lock -c 1E1E2E -e
        fi
        exit 0
    fi
done

# ロック以外の引数の場合、オリジナルのバイナリがあれば委譲
if [ -x "/usr/bin/cinnamon-screensaver-command" ] && [ "$BASH_SOURCE" != "/usr/bin/cinnamon-screensaver-command" ]; then
    exec /usr/bin/cinnamon-screensaver-command "$@"
fi
