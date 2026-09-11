#!/bin/bash

# ==========================================
# システムアップデート確認スクリプト
# 定期的に apt の更新可能パッケージを確認し、通知します。
# ==========================================

# システム起動直後の高負荷を避けるため、最初は少し待機
sleep 60

while true; do
    # 更新可能なパッケージの数を取得 (エラーや "Listing..." 行を除外)
    UPDATES=$(apt list --upgradable 2>/dev/null | grep -v 'Listing...' | grep -c '\[upgradable from:')

    if [ "$UPDATES" -gt 0 ]; then
        if command -v notify-send &>/dev/null; then
            notify-send -u normal -t 10000 "📦 システムアップデート" "$UPDATES 個のパッケージが更新可能です。\nターミナルで 'sudo apt upgrade' を実行してください。"
        fi
    fi
    
    # 6時間ごと (21600秒) にチェックを実行
    sleep 21600
done
