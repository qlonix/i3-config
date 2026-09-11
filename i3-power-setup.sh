#!/bin/bash

# ==========================================
# i3wm 電源・省電力設定ツール
# 画面消灯、スリープ移行時間、バッテリー時輝度調整、
# ハイブリッドスリープ等の設定を行います。
# ==========================================

CONF_DIR="$HOME/.config/i3"
POWER_CONF="$CONF_DIR/power.conf"

# 現在のモードを読み込み
SLEEP_MODE="suspend"
if [ -f "$POWER_CONF" ]; then
    . "$POWER_CONF"
fi

show_menu() {
    echo "======================================"
    echo " 🔋 電源・省電力設定 (Power Management)"
    echo "======================================"
    echo "1) 🖥️ 画面消灯・スリープ時間・輝度調整の設定 (GUI)"
    echo "   -> xfce4-power-manager を起動します(未インストールの場合はインストール)"
    echo "2) 🌙 「スリープ」ボタンのアクションを変更"
    echo "   -> 現在: $SLEEP_MODE"
    echo "3) ⏳ Suspend-then-Hibernate の移行待機時間を設定"
    echo "   -> スリープから休止状態へ移行するまでの時間 (要sudo)"
    echo "0) 終了"
    echo "======================================"
    read -p "番号を選択 (0-3): " choice

    case "$choice" in
        1) setup_gui_power_manager ;;
        2) setup_sleep_mode ;;
        3) setup_hibernate_delay ;;
        0) exit 0 ;;
        *) echo "無効な入力です。"; sleep 1; show_menu ;;
    esac
}

setup_gui_power_manager() {
    echo ""
    echo "i3wmで最も安定して動作する 'xfce4-power-manager' を使用します。"
    if ! command -v xfce4-power-manager-settings &>/dev/null; then
        echo "xfce4-power-manager が見つかりません。インストールしますか？ (y/n)"
        read -p "> " inst
        if [[ "$inst" == "y" || "$inst" == "Y" ]]; then
            sudo apt update && sudo apt install -y xfce4-power-manager
        else
            echo "キャンセルしました。"
            sleep 1; show_menu; return
        fi
    fi
    
    # バックグラウンドでデーモンが動いていなければ起動
    if ! pgrep -x xfce4-power-manager > /dev/null; then
        xfce4-power-manager &
    fi

    echo "設定画面を開きます..."
    xfce4-power-manager-settings
    show_menu
}

setup_sleep_mode() {
    echo ""
    echo "======================================"
    echo " 🌙 スリープの動作モードを選択してください"
    echo "======================================"
    echo "1) 通常のスリープ (suspend) - メモリに保存。復帰が最速だがバッテリーを消費。"
    echo "2) ハイブリッドスリープ (hybrid-suspend) - メモリとディスク両方に保存。バッテリー切れでも安全。"
    echo "3) Suspend-then-Hibernate - 一定時間はスリープ、その後自動で休止状態に移行してバッテリーを節約。"
    echo "0) 戻る"
    read -p "番号を選択 (0-3): " smode

    case "$smode" in
        1) SLEEP_MODE="suspend" ;;
        2) SLEEP_MODE="hybrid-suspend" ;;
        3) SLEEP_MODE="suspend-then-hibernate" ;;
        0) show_menu; return ;;
        *) echo "無効な入力です。"; sleep 1; setup_sleep_mode; return ;;
    esac

    echo "SLEEP_MODE=\"$SLEEP_MODE\"" > "$POWER_CONF"
    echo "スリープモードを '$SLEEP_MODE' に設定しました。"
    echo "次回からメニューの「スリープ」を選択した際、このアクションが実行されます。"
    sleep 2
    show_menu
}

setup_hibernate_delay() {
    echo ""
    echo "======================================"
    echo " ⏳ Suspend-then-Hibernate 待機時間設定"
    echo "======================================"
    echo "スリープ状態になってから、完全に電源が切れる「休止状態」へ"
    echo "移行するまでの待機時間を設定します。 (システム全体の設定です)"
    echo "※デフォルトはシステムによって異なります(例: 120min)"
    echo ""
    read -p "待機時間を入力してください (例: 60min, 2h, 1800s / 空白でキャンセル): " delay

    if [ -n "$delay" ]; then
        echo "システム設定ファイル (/etc/systemd/sleep.conf) を編集します。"
        # systemd >= 252 uses HibernateDelaySec, older might use HibernateDelaySec too.
        # Uncomment or add HibernateDelaySec=...
        sudo sed -i '/^#HibernateDelaySec=/d' /etc/systemd/sleep.conf
        sudo sed -i '/^HibernateDelaySec=/d' /etc/systemd/sleep.conf
        
        # Ensure [Sleep] section exists
        if ! grep -q "^\[Sleep\]" /etc/systemd/sleep.conf; then
            echo "[Sleep]" | sudo tee -a /etc/systemd/sleep.conf > /dev/null
        fi
        
        sudo sed -i "/^\[Sleep\]/a HibernateDelaySec=$delay" /etc/systemd/sleep.conf
        
        sudo systemctl daemon-reload
        echo "待機時間を $delay に設定しました！"
    fi
    sleep 2
    show_menu
}

# ターミナルで実行されることを想定
if [ -t 1 ]; then
    show_menu
else
    # ターミナル外から呼ばれた場合はターミナルエミュレータを起動して実行
    if command -v i3-sensible-terminal &>/dev/null; then
        i3-sensible-terminal -e "$0"
    elif command -v x-terminal-emulator &>/dev/null; then
        x-terminal-emulator -e "$0"
    fi
fi
