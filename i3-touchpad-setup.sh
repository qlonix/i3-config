#!/bin/bash

# ==========================================
# i3wm タッチパッド設定スクリプト
# タッチパッドの2本指スクロールとナチュラルスクロール(Mac方式)を有効化します。
# ==========================================

# xinput コマンドが存在するか確認
if ! command -v xinput &>/dev/null; then
    echo "xinput コマンドが見つかりません。設定をスキップします。"
    exit 0
fi

# 'Touchpad', 'Synaptics', 'ALPS', 'Elan', 'TouchPad' などの名前を持つデバイスIDを取得
TOUCHPAD_IDS=$(xinput list | grep -iE 'touchpad|synaptics|alps|elan' | grep -o 'id=[0-9]*' | cut -d= -f2)

for id in $TOUCHPAD_IDS; do
    echo "タッチパッドデバイスを設定中 (ID: $id)..."

    # ==========================
    # 1. libinput ドライバーの場合 (モダンな Linux: Linux Mint 等)
    # ==========================
    if xinput list-props "$id" | grep -q "libinput Natural Scrolling Enabled"; then
        # ナチュラルスクロールを有効化
        xinput set-prop "$id" "libinput Natural Scrolling Enabled" 1 2>/dev/null
        
        # タップでクリックを有効化 (おまけ: 便利なので大抵のユーザーが好む)
        if xinput list-props "$id" | grep -q "libinput Tapping Enabled"; then
            xinput set-prop "$id" "libinput Tapping Enabled" 1 2>/dev/null
        fi

        # 2本指スクロールを有効化 (libinput Scroll Method Enabled: 1=2本指, 0=エッジ, 0=ボタン)
        if xinput list-props "$id" | grep -q "libinput Scroll Method Enabled"; then
            xinput set-prop "$id" "libinput Scroll Method Enabled" 1, 0, 0 2>/dev/null
        fi
        
        echo " -> libinput の設定を適用しました。"
        continue
    fi

    # ==========================
    # 2. synaptics ドライバーの場合 (少し古い Linux: Q4OS 等の可能性)
    # ==========================
    if command -v synclient &>/dev/null; then
        # ナチュラルスクロール (負の値を設定) と 2本指スクロールを有効化
        synclient VertScrollDelta=-111 HorizScrollDelta=-111 VertTwoFingerScroll=1 HorizTwoFingerScroll=1 2>/dev/null
        
        # タップでクリックを有効化
        synclient TapButton1=1 TapButton2=3 TapButton3=2 2>/dev/null
        
        echo " -> synclient の設定を適用しました。"
        continue
    fi

    # synclient が無いがプロパティとして設定可能な場合 (稀)
    if xinput list-props "$id" | grep -q "Synaptics Scrolling Distance"; then
        # 距離をマイナスに設定してナチュラルスクロール化
        xinput set-prop "$id" "Synaptics Scrolling Distance" -111 -111 2>/dev/null
        xinput set-prop "$id" "Synaptics Two-Finger Scrolling" 1 1 2>/dev/null
        echo " -> Synaptics xinput プロパティの設定を適用しました。"
    fi
done
