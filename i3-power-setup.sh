#!/bin/bash

# ==========================================
# i3wm 電源・省電力 & 画面ロック設定ツール
# 画面消灯、自動画面ロック待機時間、スリープ移行時間、
# バッテリー時輝度調整、ハイブリッドスリープ等の設定を行います。
# ==========================================

CONF_DIR="$HOME/.config/i3"
POWER_CONF="$CONF_DIR/power.conf"

# デフォルト設定値
SLEEP_MODE="suspend-then-hibernate"
LOCK_TIMEOUT=300
DPMS_TIMEOUT=600

# 保存された設定を読み込み
if [ -f "$POWER_CONF" ]; then
    . "$POWER_CONF"
fi

# ==========================================
# apply モード: i3起動時・再読み込み時に設定を適用
# ==========================================
apply_settings() {
    # 1. アイドル時のスクリーンセーバー (画面ロック発火用) 設定
    if [ -n "$LOCK_TIMEOUT" ] && [ "$LOCK_TIMEOUT" -gt 0 ] 2>/dev/null; then
        xset s "$LOCK_TIMEOUT" "$LOCK_TIMEOUT"
    else
        xset s off
    fi

    # 2. DPMS (ディスプレイ消灯) 設定
    if [ -n "$DPMS_TIMEOUT" ] && [ "$DPMS_TIMEOUT" -gt 0 ] 2>/dev/null; then
        xset +dpms
        xset dpms 0 0 "$DPMS_TIMEOUT"
    else
        xset -dpms
    fi

    # 3. xfce4-power-manager が起動している場合、蓋閉じ処理を systemd-logind に委譲
    if command -v xfconf-query &>/dev/null && pgrep -x xfce4-power-manager >/dev/null 2>&1; then
        xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/logind-handle-lid-switch -s true --create -t bool 2>/dev/null || true
    fi

    # 4. xss-lock デーモンが動いていなければ起動
    if command -v xss-lock &>/dev/null && command -v i3lock &>/dev/null; then
        if ! pgrep -x xss-lock >/dev/null; then
            xss-lock --transfer-sleep-lock -- i3lock --nofork -c 000000 &
        fi
    fi
}

if [ "$1" = "apply" ]; then
    apply_settings
    exit 0
fi

save_power_conf() {
    mkdir -p "$CONF_DIR"
    cat <<EOF > "$POWER_CONF"
# i3wm Power & Lock Configuration
SLEEP_MODE="$SLEEP_MODE"
LOCK_TIMEOUT=$LOCK_TIMEOUT
DPMS_TIMEOUT=$DPMS_TIMEOUT
EOF
    apply_settings
}

show_menu() {
    local lock_display="無効"
    if [ "$LOCK_TIMEOUT" -gt 0 ] 2>/dev/null; then
        lock_display="$((LOCK_TIMEOUT / 60)) 分 (${LOCK_TIMEOUT}秒)"
    fi

    local dpms_display="無効"
    if [ "$DPMS_TIMEOUT" -gt 0 ] 2>/dev/null; then
        dpms_display="$((DPMS_TIMEOUT / 60)) 分 (${DPMS_TIMEOUT}秒)"
    fi

    echo "======================================"
    echo " 🔋 電源・省電力・画面ロック設定"
    echo "======================================"
    echo "1) 🖥️ 画面消灯・スリープ時間・輝度調整の設定 (GUI)"
    echo "   -> xfce4-power-manager を起動します"
    echo "2) 🔒 アイドル画面ロック待機時間の設定"
    echo "   -> 現在: $lock_display"
    echo "3) 📺 画面消灯 (DPMS) 待機時間の設定"
    echo "   -> 現在: $dpms_display"
    echo "4) 🌙 「スリープ」ボタンのアクションを変更"
    echo "   -> 現在: $SLEEP_MODE"
    echo "5) ⏳ Suspend-then-Hibernate の移行待機時間を設定"
    echo "   -> スリープから休止状態へ移行するまでの時間 (要sudo)"
    echo "0) 終了"
    echo "======================================"
    read -p "番号を選択 (0-5): " choice

    case "$choice" in
        1) setup_gui_power_manager ;;
        2) setup_lock_timeout ;;
        3) setup_dpms_timeout ;;
        4) setup_sleep_mode ;;
        5) setup_hibernate_delay ;;
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

setup_lock_timeout() {
    echo ""
    echo "======================================"
    echo " 🔒 アイドル画面ロック待機時間の設定"
    echo " 操作がない状態が続いた場合に自動で画面をロックします"
    echo "======================================"
    echo "1) 3分 (180秒)"
    echo "2) 5分 (300秒) [推奨]"
    echo "3) 10分 (600秒)"
    echo "4) 15分 (900秒)"
    echo "5) 30分 (1800秒)"
    echo "6) 秒数を直接入力"
    echo "7) 自動ロックを無効化 (0)"
    echo "0) 戻る"
    read -p "番号を選択 (0-7): " lchoice

    case "$lchoice" in
        1) LOCK_TIMEOUT=180 ;;
        2) LOCK_TIMEOUT=300 ;;
        3) LOCK_TIMEOUT=600 ;;
        4) LOCK_TIMEOUT=900 ;;
        5) LOCK_TIMEOUT=1800 ;;
        6)
            read -p "待機秒数を入力してください (例: 300): " custom_sec
            if [[ "$custom_sec" =~ ^[0-9]+$ ]]; then
                LOCK_TIMEOUT=$custom_sec
            else
                echo "無効な秒数です。"
                sleep 1; setup_lock_timeout; return
            fi
            ;;
        7) LOCK_TIMEOUT=0 ;;
        0) show_menu; return ;;
        *) echo "無効な入力です。"; sleep 1; setup_lock_timeout; return ;;
    esac

    save_power_conf
    echo "画面ロック待機時間を $LOCK_TIMEOUT 秒に設定しました。"
    if command -v notify-send &>/dev/null && [ -n "$DISPLAY" ]; then
        notify-send "🔒 画面ロック設定" "アイドル待機時間を ${LOCK_TIMEOUT}秒 に更新しました"
    fi
    sleep 1
    show_menu
}

setup_dpms_timeout() {
    echo ""
    echo "======================================"
    echo " 📺 画面消灯 (DPMS) 待機時間の設定"
    echo " 操作がない状態が続いた場合にディスプレイの電源を切ります"
    echo " (※画面ロック時間より長めに設定することを推奨します)"
    echo "======================================"
    echo "1) 5分 (300秒)"
    echo "2) 10分 (600秒) [推奨]"
    echo "3) 15分 (900秒)"
    echo "4) 30分 (1800秒)"
    echo "5) 秒数を直接入力"
    echo "6) 画面消灯を無効化 (0)"
    echo "0) 戻る"
    read -p "番号を選択 (0-6): " dchoice

    case "$dchoice" in
        1) DPMS_TIMEOUT=300 ;;
        2) DPMS_TIMEOUT=600 ;;
        3) DPMS_TIMEOUT=900 ;;
        4) DPMS_TIMEOUT=1800 ;;
        5)
            read -p "待機秒数を入力してください (例: 600): " custom_dpms
            if [[ "$custom_dpms" =~ ^[0-9]+$ ]]; then
                DPMS_TIMEOUT=$custom_dpms
            else
                echo "無効な秒数です。"
                sleep 1; setup_dpms_timeout; return
            fi
            ;;
        6) DPMS_TIMEOUT=0 ;;
        0) show_menu; return ;;
        *) echo "無効な入力です。"; sleep 1; setup_dpms_timeout; return ;;
    esac

    save_power_conf
    echo "画面消灯待機時間を $DPMS_TIMEOUT 秒に設定しました。"
    if command -v notify-send &>/dev/null && [ -n "$DISPLAY" ]; then
        notify-send "📺 画面消灯設定" "消灯待機時間を ${DPMS_TIMEOUT}秒 に更新しました"
    fi
    sleep 1
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

    save_power_conf
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
