#!/bin/bash
# ==========================================
# xflock4 互換ラッパースクリプト
# xfce4-power-manager 等からの画面ロック呼び出しを i3-lock.sh に転送します
# ==========================================

LOCK_SCRIPT="$HOME/.config/i3/i3-lock.sh"

if [ -x "$LOCK_SCRIPT" ]; then
    exec "$LOCK_SCRIPT"
elif command -v i3lock &>/dev/null; then
    exec i3lock -c 1E1E2E -e
fi
